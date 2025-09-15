import "@stdlib/tvm-dicts"
import "@stdlib/gas-payments"
import "../../imports/constants"
import "../../imports/messages"
import "../../imports/utils"
import "../../imports/types"
import "../../imports/admin_message"
import "../constants"
import "../messages"
import "storage"
import "messages"
import "utils"


fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    // Load storage once - more gas efficient for this contract (tested)
    var storage: Storage = lazy Storage.load();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state != STATE_ACTIVE,
        allowChangeData: storage.state != STATE_ACTIVE,
        allowSendAnyMessage: storage.state != STATE_ACTIVE,
        allowWithdrawJetton: true,
        allowSendNft: true,
    });
    
    var msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    var contractBalance: coins = contract.getOriginalBalance();
    
    match (msg) {
        FillUpBalanceMessage => {
            // If message is from marketplace, this is a deploy transaction, otherwise it's a simple fill-up transaction
            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                // Return funds if the offer has already been activated
                if (storage.state != STATE_UNINIT) {
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "Offer has already been created" }
                    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                    return;
                }
                
                // Reserve TON for offer execution
                val balanceToReserve: coins = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                if (contractBalance > balanceToReserve + ton("0.01")) {
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "offer deployed" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }

                // Initialize the offer
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }

            return;
        }
        
        // Seller transfers NFT to this contract to sell it or counterpropose a different price
        NftOwnershipAssignedMessage<SerializableSlice> => {
            try {
                assert(storage.validUntil > blockchain.now() && storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage.domainAddress) throw EXC_INCORRECT_DOMAIN;
                
                // Set seller address if it wasn't set during offer creation
                if (storage.sellerAddress == null) {
                    storage.sellerAddress = msg.fromAddress.toCell();
                }

                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;

                if ((msg.forwardPayload as slice).isEmpty()) {
                    // If there is no forward payload, accept the offer
                    acceptOffer(mutate storage, msg.fromAddress, in.valueCoins, msg.queryId);
                } else {
                    // Otherwise, propose seller's price
                    var forwardPayload: CounterProposePayload = CounterProposePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                    assert(forwardPayload.sellerPrice - storage.sellerPrice >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;  // Check that price is higher than current one
                    storage.sellerPrice = forwardPayload.sellerPrice;
                    
                    if (forwardPayload.notifyBuyer) {
                        // Notify buyer about the counterproposal
                        createMessage({
                            bounce: false,
                            value: TONS_OFFER_NOTIFICATION,
                            dest: storage.buyerAddress,
                            body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                        contractBalance -= TONS_OFFER_NOTIFICATION;
                    }
                    
                    // Send excess
                    val balanceToReserve: coins = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                    assert(contractBalance > balanceToReserve + TONS_MIN_EXCESS) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: msg.fromAddress,
                        body: CommentMessage { comment: "Counterproposal sent" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }

                // Save data
                storage.save();
                return;
            } catch (e, _) {
                // Try to return NFT on error
                returnNftToSender(in.senderAddress, msg, e);
            }
        }
        
        // Process counterproposals after the first one
        CounterProposeMessage => {
            assert(storage.sellerAddress != null && storage.sellerAddress.load() == in.senderAddress) throw EXC_DEAL_NOT_ACTIVE;  // Check that message is from seller
            assert(storage.validUntil > blockchain.now() && storage.sellerPrice > 0) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active and there was counterproposal

            if (msg.sellerPrice <= storage.price) {
                // If seller set price less than or equal to buyer's price, execute offer
                acceptOffer(mutate storage, in.senderAddress, in.valueCoins, msg.queryId);
            } else {
                assert(msg.sellerPrice - storage.price >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;  // Check minimum price delta
                storage.sellerPrice = msg.sellerPrice;  // Update storage
                
                if (msg.notifyBuyer) {
                    // Notify buyer about the counterproposal
                    val notificationPrice: coins = createMessage({
                        bounce: false,
                        value: TONS_OFFER_NOTIFICATION,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                    }).sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
                    contractBalance -= (notificationPrice + TONS_OFFER_NOTIFICATION);
                }
                
                // Send marketplace commission
                createMessage({
                    bounce: false,
                    value: TONS_COUNTERPROPOSE_PRICE,
                    dest: MARKETPLACE_ADDRESS,
                    body: CommentMessage { comment: "Marketplace commission" }
                }).send(SEND_MODE_REGULAR);
                
                // Send excess
                val balanceToReserve: coins = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                assert(contractBalance > balanceToReserve + TONS_COUNTERPROPOSE_PRICE + TONS_COUNTERPROPOSE_GAS) throw EXC_OUT_OF_GAS;
                reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: CommentMessage { comment: "Counterproposal sent" }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }

            // Save storage
            storage.save();
            return;
        }
        
        // Change price
        ChangePriceMessage => {
            assert(in.senderAddress == storage.buyerAddress) throw EXC_INCORRECT_SENDER;  // Check that message is from buyer
            assert(msg.newPrice - storage.price >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;  // Check minimum price delta
            
            val newCommission: coins = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            
            // Calculate maximum value for new price considering fees and check submitted price
            val msgValue: coins = in.valueCoins - (TONS_CHANGE_PRICE_GAS + (msg.notifySeller ? TONS_OFFER_NOTIFICATION : (0 as coins)) + (storage.sellerPrice != 0 ? TONS_COUNTERPROPOSE_PRICE : (0 as coins)));
            val maxNewPrice: coins = storage.price + msgValue + storage.commission - newCommission;
            assert(msg.newPrice <= maxNewPrice) throw EXC_OUT_OF_GAS;
            
            // Update price in storage before offer execution
            storage.price = msg.newPrice;
            storage.commission = newCommission;
            
            if (storage.sellerPrice != 0 && storage.price >= storage.sellerPrice) {
                // If new price is greater than or equal to seller's price, execute offer
                acceptOffer(mutate storage, storage.sellerAddress!.load(), 0, msg.queryId);
            } else {
                // Check that new validUntil is greater than current one and less than 30 days from now
                assert(
                    msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil) &&
                    msg.newValidUntil <= blockchain.now() + ONE_DAY * 30
                ) throw EXC_INCORRECT_VALID_UNTIL;
                storage.validUntil = msg.newValidUntil;
                storage.createdAt = blockchain.now();

                if (msg.notifySeller && storage.sellerAddress != null) {
                    // Send blockchain notification to seller
                    val sellerAddress: address = storage.sellerAddress!.load();
                    createMessage({
                        bounce: false,
                        value: TONS_OFFER_NOTIFICATION,
                        dest: sellerAddress,
                        body: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("New offer on webdom.market! ")
                                .storeStrFloat(msg.newPrice, ton("1"))
                                .storeSlice(" TON for ")
                                .storeRef(storage.domainName)
                            .endCell()
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                }

                if (storage.sellerPrice != 0) {
                    // Send marketplace commission (bargaining after seller counterproposal is paid)
                    createMessage({
                        bounce: false,
                        value: TONS_COUNTERPROPOSE_PRICE,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);
                }
                
                // Reserve TON for offer execution and notify buyer about successful price change
                reserveToncoinsOnBalance(storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: storage.buyerAddress,
                    body: beginCell()
                            .storeUint(0, 32)
                            .storeSlice("Price changed to ")
                            .storeStrFloat(storage.price, ton("1"))
                        .endCell()
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }

            // Save data
            storage.save();
            return;
        }
        
        // Change valid until
        ChangeValidUntilMessage => {
            assert(in.senderAddress == storage.buyerAddress) throw EXC_INCORRECT_SENDER;  // Check that message is from buyer
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active
            
            // Check that new validUntil is greater than current one and less than 30 days from now
            assert(
                msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil) &&
                msg.newValidUntil <= blockchain.now() + ONE_DAY * 30
            ) throw EXC_INCORRECT_VALID_UNTIL;

            // Update storage
            storage.validUntil = msg.newValidUntil;
            storage.save();
            
            // Reserve balance for offer execution (don't use mode 64 to save TON for storage fees)
            reserveToncoinsOnBalance(storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.buyerAddress,
                body: CommentMessage { comment: "Valid until time updated" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            return;
        }

        // Cancel offer
        CancelDealMessage => {
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active
            
            var sellerMsgValue: coins = 0;
            
            if (in.senderAddress == storage.buyerAddress) {
                // Buyer can cancel if 1 minute has passed since creation, offer has expired, or there's counterproposal
                assert(storage.createdAt + 60 < blockchain.now() || storage.validUntil < blockchain.now() || storage.sellerPrice != 0) throw EXC_CANT_CANCEL_DEAL;
            } else if (storage.sellerAddress != null && in.senderAddress == storage.sellerAddress!.load()) {
                // Seller can cancel offer at any time
                storage.cancelledBySeller = true;
                sellerMsgValue = in.valueCoins;
            } else {
                throw EXC_INCORRECT_SENDER;
            }

            if (msg.cancellationComment.isEmpty()) {
                // Set default comment if it wasn't provided
                msg.cancellationComment = "Your offer on webdom.market was cancelled";
            }
            
            cancelOffer(mutate storage, sellerMsgValue, msg.cancellationComment, msg.queryId);
            return;
        }

        CommentMessage => {
            if (msg.comment.bitsEqual("cancel")) {
                assert(storage.buyerAddress == in.senderAddress || in.senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;  // Only buyer can cancel offer via comment message
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active

                cancelOffer(mutate storage, 0, "Your offer on webdom.market was cancelled", 0);
                return;
            }
        }
        
        else => {
            throw EXC_UNSUPPORTED_OP;
        }
    }
}


fun onExternalMessage(in: InMessage): void {
    var storage: Storage = lazy Storage.load();
    assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
    val opCode: uint32 = in.body.loadUint(32);
    val queryId: uint64 = in.body.loadUint(64);
    assert(opCode == OP_CANCEL_DEAL) throw EXC_UNSUPPORTED_OP;
        
    if (blockchain.now() >= storage.validUntil) {
        // If offer has expired, anyone can send external message to cancel it
        acceptExternalMessage();
        cancelOffer(mutate storage, 0, "Offer expired", queryId);
        return;
    } else {
        // If offer is active, only marketplace can send signed message to cancel it (used when domain is no longer owned by seller)
        assert(storage.publicKeyCell != null) throw EXC_INVALID_SIGNATURE;
        val publicKey: uint256 = storage.publicKeyCell!.load();
        val signature: slice = in.body.loadBits(512);
        assert(isSignatureValid(in.body.hash(), signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;
        assert(in.body.loadAddress() == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
        
        var comment: slice = in.body.loadRef().beginParse();
        comment.skipBits(32);
        
        acceptExternalMessage();
        cancelOffer(mutate storage, 0, comment, queryId);

        return;
    }
}


get fun get_storage_data() {
    var storage: Storage = lazy Storage.load();
    
    // Create dictionary with single domain
    var domainsDict: dict = createEmptyDict();
    domainsDict.sDictSet(267, storage.domainAddress as slice, BIT_TRUE_SLICE());
    
    var sellerAddress: address = storage.sellerAddress == null ? createAddressNone() : storage.sellerAddress!.load();
    return (
        sellerAddress,
        domainsDict,
        1, // total domains count
        storage.state == STATE_COMPLETED ? 1 : 0, // domains received
        storage.state, 
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        0, // last renewal time (unused)
        storage.validUntil,
        storage.buyerAddress,
        storage.domainName,
        storage.cancelledBySeller,
        storage.sellerPrice,
        BURN_ADDRESS, // jetton minter address
        contract.getCode().hash()
    );
}


// Legacy methods from https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-offer-v1r3.fc
get fun get_offer_data() {
    var storage: Storage = lazy Storage.load();

    var marketplaceFactor = mulDivFloor(storage.commission, ton("1"), storage.price);
    var marketplaceBase = ton("1");

    return (
        0x4f46464552, // offer ("OFFER")
        storage.state != STATE_ACTIVE,
        storage.createdAt, storage.validUntil,
        MARKETPLACE_ADDRESS, 
        storage.domainAddress, 
        storage.buyerAddress,   
        storage.price + storage.commission, 
        MARKETPLACE_ADDRESS, 
        marketplaceFactor, marketplaceBase, 
        BURN_ADDRESS, 
        0, 1, 
        storage.price 
    );
}

get fun get_offer_data_v2() {
    var storage: Storage = lazy Storage.load();

    var marketplaceFactor: coins = mulDivFloor(storage.commission, ton("1"), storage.price);
    var marketplaceBase: coins = ton("1");

    return (
        0x4f46464552, // offer ("OFFER")
        storage.state != STATE_ACTIVE,
        storage.createdAt, storage.validUntil, storage.state == STATE_COMPLETED ? storage.validUntil : (0 as uint32),
        MARKETPLACE_ADDRESS,
        storage.domainAddress,
        storage.buyerAddress,
        storage.price + storage.commission,
        MARKETPLACE_ADDRESS,
        marketplaceFactor, marketplaceBase,
        BURN_ADDRESS,
        0, 1,
        storage.price
    );
}

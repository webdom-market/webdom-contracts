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
    
    var storage: Storage = lazy Storage.load();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state != STATE_ACTIVE,
        allowChangeData: storage.state != STATE_ACTIVE,
        allowSendAnyMessage: storage.state != STATE_ACTIVE,
        allowWithdrawTon: true,
        allowSendNft: true,
    });
    
    var msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    var contractBalance: coins = contract.getOriginalBalance();
    
    match (msg) {
        // Deploy and set wallet message from marketplace
        DeployAndSetWalletMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            // If message is from marketplace, this is a deploy transaction, otherwise it's a simple fill-up transaction
            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                // Return funds if the offer has already been activated
                if (storage.state != STATE_UNINIT) {
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage2.buyerAddress,
                        body: CommentMessage { comment: "Offer has already been created" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                    return;
                }
                
                // Reserve TON for offer execution
                if (contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_MIN_EXCESS) {
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage2.buyerAddress,
                        body: CommentMessage { comment: "offer deployed" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                
                // Initialize the offer
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }

            return;
        }

        // Seller transfers NFT to this contract to sell it or counterpropose a different price
        NftOwnershipAssignedMessage<SerializableSlice> => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            try {
                assert(storage.validUntil > blockchain.now() && storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage2.domainAddress) throw EXC_INCORRECT_DOMAIN;
                
                // Set seller address if it wasn't set during offer creation
                storage.sellerAddress = msg.fromAddress;
               
                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;

                if ((msg.forwardPayload as slice).isEmpty()) {
                    // If there is no forward payload, accept the offer
                    acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, in.valueCoins, msg.queryId);
                } else {
                    // Otherwise, propose seller's price
                    var forwardPayload: CounterProposePayload = CounterProposePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                    assert(forwardPayload.sellerPrice > storage.sellerPrice) throw EXC_INCORRECT_PRICE;
                    storage.sellerPrice = forwardPayload.sellerPrice;
                    
                    if (forwardPayload.notifyBuyer) {
                        // Notify buyer about the counterproposal
                        createMessage({
                            bounce: false,
                            value: TONS_OFFER_NOTIFICATION,
                            dest: storage2.buyerAddress,
                            body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                        contractBalance -= TONS_OFFER_NOTIFICATION;
                    }
                    
                    // Send excess
                    assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_MIN_EXCESS) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
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
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(storage.sellerAddress == in.senderAddress) throw EXC_INCORRECT_SENDER;  // Check that message is from seller
            assert(storage.validUntil > blockchain.now() && storage.sellerPrice > 0) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active and there was counterproposal
            
            if (msg.sellerPrice <= storage.price) {
                // If seller set price less than or equal to buyer's price, execute offer
                acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, in.valueCoins, msg.queryId);
            } else {
                storage.sellerPrice = msg.sellerPrice;  // Update storage
                
                if (msg.notifyBuyer) {
                    // Notify buyer about the counterproposal
                    val notificationPrice: coins = createMessage({
                        bounce: false,
                        value: TONS_OFFER_NOTIFICATION,
                        dest: storage2.buyerAddress,
                        body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                    }).sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
                    contractBalance -= (notificationPrice + TONS_OFFER_NOTIFICATION);
                }
                
                // Send marketplace commission (2nd and further counterproposals are paid)
                createMessage({
                    bounce: false,
                    value: TONS_COUNTERPROPOSE_PRICE,
                    dest: MARKETPLACE_ADDRESS,
                    body: CommentMessage { comment: "Marketplace commission" }
                }).send(SEND_MODE_REGULAR);
                
                // Reserve TON for offer execution and send excess
                assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_COUNTERPROPOSE_PRICE + TONS_COUNTERPROPOSE_GAS) throw EXC_OUT_OF_GAS;
                reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: CommentMessage { comment: "Counterproposal sent" }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }

            // Save data
            storage.save();
            return;
        }
        
        // Process jetton transfer notification (for changing price)
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            try {
                assert(in.senderAddress == storage.jettonWalletAddress && msg.fromAddress == storage2.buyerAddress) throw EXC_INCORRECT_SENDER;  // Check that message is from buyer
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active
                
                // Parse forward payload
                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;
                var payload: ChangePricePayload = ChangePricePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                
                // Calculate new price (considering fees)
                val priceDelta: coins = mulDivFloor(msg.transferredJettons, storage.price, storage.commission + storage.price);
                storage.price = storage.price + priceDelta;
                storage.commission = storage.commission + msg.transferredJettons - priceDelta;
                
                if (storage.sellerPrice != 0 && storage.price >= storage.sellerPrice) {
                    // If new price is greater than or equal to seller's price, execute offer
                    acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, msg.queryId);
                } else {
                    assert(payload.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
                    
                    storage.validUntil = payload.newValidUntil;
                    storage.createdAt = blockchain.now();
                    
                    // Determine jetton display info
                    var oneJetton: coins = 1000;
                    var jettonName: slice = " WEB3";
                    if (storage2.jettonMinterAddress == USDT_ADDRESS) {
                        oneJetton = 1000000;
                        jettonName = " USDT";
                    }
                    
                    if (payload.notifySeller && storage.sellerAddress != createAddressNone()) {
                        // Send blockchain notification to seller
                        createMessage({
                            bounce: false,
                            value: TONS_OFFER_NOTIFICATION,
                            dest: storage.sellerAddress,
                            body: beginCell()
                                    .storeUint(0, 32)
                                    .storeSlice("New offer on webdom.market! ")
                                    .storeStrFloat(storage.price, oneJetton)
                                    .storeSlice(jettonName)
                                    .storeSlice(" for ")
                                    .storeRef(storage2.domainName)
                                .endCell()
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                        contractBalance -= TONS_OFFER_NOTIFICATION;
                    }

                    if (storage.sellerPrice != 0) {
                        // Send marketplace commission (bargaining after seller counterproposal is paid)
                        createMessage({
                            bounce: false,
                            value: TONS_COUNTERPROPOSE_PRICE,
                            dest: MARKETPLACE_ADDRESS,
                            body: CommentMessage { comment: "Marketplace commission" }
                        }).send(SEND_MODE_REGULAR);
                        contractBalance -= TONS_COUNTERPROPOSE_PRICE;
                    }
                    
                    // Check remaining balance and reserve required TON
                    assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_CHANGE_PRICE_GAS) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                    
                    // Notify buyer about successful price change
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage2.buyerAddress,
                        body: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("Price changed to ")
                                .storeStrFloat(storage.price, oneJetton)
                                .storeSlice(jettonName)
                            .endCell()
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }

                // Save data
                storage.save();
                return;
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
        }
                
        // Change valid until
        ChangeValidUntilMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage2.buyerAddress) throw EXC_INCORRECT_SENDER;  // Check that message is from buyer
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
            reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
            createMessage({
                bounce: false,
                value: 0,
                dest: storage2.buyerAddress,
                body: CommentMessage { comment: "Valid until time updated" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            return;
        }
        
        // Cancel offer
        CancelDealMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active
            
            var sellerMsgValue: coins = 0;

            if (in.senderAddress == storage2.buyerAddress) {
                // Buyer can cancel if 1 minute has passed since creation, offer has expired, or there's counterproposal
                assert(storage.createdAt + 60 < blockchain.now() || storage.validUntil < blockchain.now() || storage.sellerPrice != 0) throw EXC_CANT_CANCEL_DEAL;
            } else if (in.senderAddress == storage.sellerAddress) {
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
            
            cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, sellerMsgValue, msg.cancellationComment, msg.queryId);
            return;
        }
        
        CommentMessage => {
            if (msg.comment.bitsEqual("cancel")) {
                var storage2: StorageDs2 = lazy storage.ds2.load();
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that offer is active
                assert(storage2.buyerAddress == in.senderAddress) throw EXC_INCORRECT_SENDER;  // Only buyer can cancel offer via comment message

                cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, "Your offer on webdom.market was cancelled", 0);
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
        
    var storage2: StorageDs2 = lazy storage.ds2.load();
    
    if (blockchain.now() >= storage.validUntil) {
        // If offer has expired, anyone can send external message to cancel it
        acceptExternalMessage();
        cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, "Offer expired", queryId);
        return;
    } else {
        // If offer is active, only marketplace can send signed message to cancel it (used when domain is no longer owned by seller)
        assert(storage2.publicKeyCell != null) throw EXC_INVALID_SIGNATURE;
        val publicKey: uint256 = storage2.publicKeyCell!.load();
        val signature: slice = in.body.loadBits(512);
        assert(isSignatureValid(in.body.hash(), signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;
        assert(in.body.loadAddress() == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
        
        acceptExternalMessage();
        var comment: slice = in.body.loadRef().beginParse();
        comment.skipBits(32);
        cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, comment, queryId);

        return;
    }
}


get fun get_storage_data() {
    var storage = Storage.load();
    var storage2 = storage.ds2.load();
    
    var domainsDict = createEmptyDict();
    domainsDict.sDictSet(267, storage2.domainAddress as slice, BIT_TRUE_SLICE());
    
    return (
        storage.sellerAddress,
        domainsDict,
        1,  // total domains count
        storage.state == STATE_COMPLETED ? 1 : 0,  // domains received
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        0,  // last renewal time (unused)
        storage.validUntil,
        storage2.buyerAddress,
        storage2.domainName,
        storage.cancelledBySeller,
        storage.jettonWalletAddress,
        storage.sellerPrice,
        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
}


// Legacy methods from https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-offer-v1r3.fc
get fun get_offer_data() {
    val storage = lazy Storage.load();
    val storage2 = lazy storage.ds2.load();

    val marketplaceFactor = mulDivFloor(storage.commission, ton("1"), storage.price);
    val marketplaceBase = ton("1");

    return (
        0x4f46464552, // offer ("OFFER")
        storage.state != STATE_ACTIVE,
        storage.createdAt, storage.validUntil,
        MARKETPLACE_ADDRESS,
        storage2.domainAddress,
        storage2.buyerAddress,
        storage.price + storage.commission,
        MARKETPLACE_ADDRESS,
        marketplaceFactor, marketplaceBase,
        BURN_ADDRESS,
        0, 1,
        storage.price
    );
}

get fun get_offer_data_v2() {
    val storage = lazy Storage.load();
    val storage2 = lazy storage.ds2.load();

    val marketplaceFactor = mulDivFloor(storage.commission, ton("1"), storage.price);
    val marketplaceBase = ton("1");

    return (
        0x4f46464552, // offer ("OFFER")
        storage.state != STATE_ACTIVE,
        storage.createdAt, storage.validUntil, storage.state == STATE_COMPLETED ? storage.validUntil : (0 as uint32),
        MARKETPLACE_ADDRESS,
        storage2.domainAddress,
        storage2.buyerAddress,
        storage.price + storage.commission,
        MARKETPLACE_ADDRESS,
        marketplaceFactor, marketplaceBase,
        BURN_ADDRESS,
        0, 1,
        storage.price
    );
}

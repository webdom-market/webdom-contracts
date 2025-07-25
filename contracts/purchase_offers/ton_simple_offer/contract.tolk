import "@stdlib/tvm-dicts";
import "../../imports/constants";
import "../../imports/messages";
import "../../imports/utils";
import "storage";
import "messages";
import "../constants";
import "@stdlib/gas-payments";
import "../../imports/types";
import "../messages";

fun acceptOffer(mutate storage: Storage, sellerAddress: address, sellerMsgValue: coins, queryId: uint64) {    
    createMessage({
        bounce: false,
        value: storage.commission,
        dest: MARKETPLACE_ADDRESS,
        body: CommentMessage { comment: "Marketplace commission" }
    }).send(SEND_MODE_REGULAR);
    
    createMessage({
        bounce: false,
        value: storage.price + sellerMsgValue,
        dest: sellerAddress,
        body: CommentMessage { comment: "Offer accepted" }
    }).send(SEND_MODE_REGULAR);
    
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.buyerAddress,
            responseAddress: storage.buyerAddress,
            customPayload: null,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
    
    storage.state = STATE_ACCEPTED;
    storage.validUntil = blockchain.now();
}

fun cancelOffer(mutate storage: Storage, sellerMsgValue: coins, cancellationComment: slice, queryId: uint64) {    
    if (storage.sellerPrice > 0) {
        createMessage({
            bounce: false,
            value: TONS_NFT_TRANSFER + sellerMsgValue,
            dest: storage.domainAddress,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.sellerAddress!.load(),
                responseAddress: storage.buyerAddress,
                forwardTonAmount: 1,
                forwardPayload: COUNTERPROPOSAL_REJECTED_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    } else if (sellerMsgValue > 0) {
        createMessage({
            bounce: false,
            value: sellerMsgValue + TONS_DECLINE_REWARD,
            dest: storage.sellerAddress!.load(),
            body: ExcessesMessage { queryId: queryId }
        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
    }
    
    storage.state = STATE_CANCELLED;
    storage.validUntil = min(storage.validUntil, blockchain.now());
    storage.save();
    
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.buyerAddress,
        body: CommentMessage { comment: cancellationComment }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
}

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    var storage = Storage.load();
    var msg = lazy AllowedMessage.fromSlice(in.body);
    var contractBalance: coins = contract.getOriginalBalance();
    
    match (msg) {
        // Fill up balance message from marketplace
        FillUpBalanceMessage => {
            var storage = Storage.load();

            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                if (storage.state != STATE_UNINIT) {
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "Offer has already been created" }
                    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                    return;
                }
                
                val balanceToReserve = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                if (contractBalance > balanceToReserve + TONS_TON_SIMPLE_OFFER_RESERVE) {
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "offer deployed" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }
            return;
        }
        

        NftOwnershipAssignedMessage<SerializableSlice> => {
            var storage = Storage.load();
            try {
                assert(storage.validUntil > blockchain.now() && storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage.domainAddress) throw EXC_INCORRECT_DOMAIN;
                
                if (storage.sellerAddress == null) {
                    storage.sellerAddress = msg.fromAddress.toCell();
                }


                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;

                if ((msg.forwardPayload as slice).isEmpty()) {
                    acceptOffer(mutate storage, msg.fromAddress, in.valueCoins, msg.queryId);
                }
                else {  
                    var forwardPayload = CounterProposePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                    assert(forwardPayload.sellerPrice - storage.sellerPrice >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;
                    
                    if (forwardPayload.notifyBuyer) {
                        createMessage({
                            bounce: false,
                            value: TONS_OFFER_NOTIFICATION,
                            dest: storage.buyerAddress,
                            body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                        contractBalance -= TONS_OFFER_NOTIFICATION;
                    }
                    
                    val balanceToReserve: int = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                    assert(contractBalance > balanceToReserve + TONS_MIN_EXCESS) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: msg.fromAddress,
                        body: CommentMessage { comment: "Counterproposal sent" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);

                    storage.sellerPrice = forwardPayload.sellerPrice;
                }
                storage.save();
                return;
            } catch (e, _) {
                if (storage.state == STATE_ACTIVE) {
                    reserveToncoinsOnBalance(storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                }
                
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: NftTransferMessage<cell> {
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        responseAddress: msg.fromAddress,
                        forwardTonAmount: 0,
                        forwardPayload: beginCell()
                                        .storeUint(0, 32)
                                        .storeSlice("Error, code ")
                                        .storeNumber10(e)
                                    .endCell()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
                
                commitContractDataAndActions();
                throw e;
            }
        }
        
        // Process counterproposals #2+
        CounterProposeMessage => {
            var storage = Storage.load();
            assert (storage.sellerAddress != null && storage.sellerAddress.load() == in.senderAddress) throw EXC_DEAL_NOT_ACTIVE;
            assert(storage.validUntil > blockchain.now() && storage.sellerPrice > 0) throw EXC_DEAL_NOT_ACTIVE;
            
            storage.sellerPrice = msg.sellerPrice;
    
            if (storage.sellerPrice <= storage.price) {
                acceptOffer(mutate storage, in.senderAddress, in.valueCoins, msg.queryId);
            } 
            else {
                assert(storage.sellerPrice - storage.price >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;
                
                if (msg.notifyBuyer) {
                    val notificationPrice = createMessage({
                        bounce: false,
                        value: TONS_OFFER_NOTIFICATION,
                        dest: storage.buyerAddress,
                        body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                    }).sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
                    contractBalance -= (notificationPrice + TONS_OFFER_NOTIFICATION);
                }
                
                createMessage({
                    bounce: false,
                    value: TONS_COUNTERPROPOSE_PRICE,
                    dest: MARKETPLACE_ADDRESS,
                    body: CommentMessage { comment: "Marketplace commission" }
                }).send(SEND_MODE_REGULAR);
                
                val balanceToReserve = storage.price + storage.commission + TONS_TON_SIMPLE_OFFER_RESERVE;
                assert(contractBalance > balanceToReserve + TONS_COUNTERPROPOSE_PRICE + TONS_COUNTERPROPOSE_GAS) throw EXC_OUT_OF_GAS;
                reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: CommentMessage { comment: "Counterproposal sent" }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }

            storage.save();
            return;
        }
        
        // Change price
        ChangePriceMessage => {
            var storage = Storage.load();
            assert(in.senderAddress == storage.buyerAddress) throw EXC_INCORRECT_SENDER;
            assert(msg.newPrice - storage.price >= TONS_MIN_PRICE_CHANGE) throw EXC_INCORRECT_PRICE;
            
            val newCommission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            
            val msgValue = in.valueCoins - (TONS_CHANGE_PRICE_GAS + (msg.notifySeller ? TONS_OFFER_NOTIFICATION : (0 as coins)) + (storage.sellerPrice != 0 ? TONS_COUNTERPROPOSE_PRICE : (0 as coins)));
            val maxNewPrice = storage.price + msgValue + storage.commission - newCommission;
            
            assert(msg.newPrice <= maxNewPrice) throw EXC_OUT_OF_GAS;
            assert(msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.price = msg.newPrice;
            storage.validUntil = msg.newValidUntil;
            storage.commission = newCommission;
            storage.createdAt = blockchain.now();
            
            if (msg.newPrice == storage.sellerPrice) {
                // Accept counterproposal
                acceptOffer(mutate storage, storage.sellerAddress!.load(), 0, msg.queryId);
            } else {
                // Change price
                if (msg.notifySeller && storage.sellerAddress != null) {
                    val sellerAddress = storage.sellerAddress!.load();
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
                    createMessage({
                        bounce: false,
                        value: TONS_COUNTERPROPOSE_PRICE,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);
                }
                
                // Notify buyer about successful price change
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
            storage.save();
            return;
        }
        
        // Change valid until
        ChangeValidUntilMessage => {
            var storage = Storage.load();
            assert(in.senderAddress == storage.buyerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            assert(msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.validUntil = msg.newValidUntil;
            storage.save();
            
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.buyerAddress,
                body: CommentMessage { comment: "Valid until time updated" }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
            return;
        }

        // Cancel offer
        CancelDealMessage => {
            var storage = Storage.load();
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            var sellerMsgValue: coins = 0;
            
            if (in.senderAddress == storage.buyerAddress) {
                // Buyer can cancel if 10 minutes have passed since creation, or offer has expired, or there's a counterproposal
                assert(storage.createdAt + 600 < blockchain.now() || storage.validUntil < blockchain.now() || storage.sellerPrice != 0) throw EXC_CANT_CANCEL_DEAL;
            } else if (storage.sellerAddress != null && in.senderAddress == storage.sellerAddress!.load()) {
                storage.cancelledBySeller = true;
                sellerMsgValue = in.valueCoins;
            } else {
                throw EXC_INCORRECT_SENDER;
            }

            if (msg.cancellationComment.isEmpty()) {
                msg.cancellationComment = "Your offer on webdom.market was cancelled";
            }
            
            cancelOffer(mutate storage, sellerMsgValue, msg.cancellationComment, msg.queryId);
            return;
        }

        CommentMessage => {
            if (msg.comment.bitsEqual("cancel")) {
                var storage = lazy Storage.load();
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(storage.buyerAddress == in.senderAddress) throw EXC_INCORRECT_SENDER;

                cancelOffer(mutate storage, 0, "Your offer on webdom.market was cancelled", 0);
                return;
            }
        }
        
        else => {
            throw EXC_UNSUPPORTED_OP;
        }
    }
}

fun onExternalMessage(in: InMessage) {
    var storage = lazy Storage.load();
    assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
    val opCode = in.body.loadUint(32);
    val queryId = in.body.loadUint(64);
    assert(opCode == OP_CANCEL_DEAL) throw EXC_UNSUPPORTED_OP;
        
    if (blockchain.now() >= storage.validUntil) {
        acceptExternalMessage();
        cancelOffer(mutate storage, 0, "Offer expired", queryId);
        return;
    } else {
        assert(storage.publicKeyCell != null) throw EXC_INVALID_SIGNATURE;
        val publicKey = storage.publicKeyCell!.load();
        val signature = in.body.loadBits(512);
        assert(isSignatureValid(in.body.hash(), signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;
        assert(in.body.loadAddress() == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
        
        acceptExternalMessage();
        var comment = in.body.loadRef().beginParse();
        comment.skipBits(32);
        cancelOffer(mutate storage, 0, comment, queryId);

        return;
    }
}

get fun get_storage_data() {
    var storage = Storage.load();
    
    var domainsDict = createEmptyDict();
    domainsDict.sDictSet(267, storage.domainAddress as slice, BIT_TRUE_SLICE());
    
    var sellerAddress = storage.sellerAddress == null ? createAddressNone() : storage.sellerAddress!.load();
    return (
        sellerAddress,
        domainsDict,
        1,
        storage.state == STATE_ACCEPTED ? 1 : 0,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        0,
        storage.validUntil,
        storage.buyerAddress,
        storage.domainName,
        storage.cancelledBySeller ? -1 : 0,
        storage.sellerPrice,
        BURN_ADDRESS,
        contract.getCode().hash()
    );
}
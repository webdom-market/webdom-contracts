import "@stdlib/tvm-dicts";
import "../../imports/constants";
import "../../imports/messages";
import "../../imports/utils";
import "../../imports/types";
import "storage";
import "messages";
import "../constants";
import "@stdlib/gas-payments";
import "../messages";
import "../../imports/admin_message"


fun acceptOffer(mutate storage: Storage, domainAddress: address, buyerAddress: address, sellerMsgValue: coins, queryId: uint64) {
    if (storage.commission > 0) {
        createMessage({
            bounce: false,
            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
            dest: storage.jettonWalletAddress,
            body: SendJettonsMessage<cell> {
                queryId: queryId,
                jettonAmount: storage.commission,
                toAddress: MARKETPLACE_ADDRESS,
                responseAddress: buyerAddress,
                forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    }
    
    createMessage({
        bounce: false,
        value: TONS_JETTON_TRANSFER + sellerMsgValue,
        dest: storage.jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.price,
            toAddress: storage.sellerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: sellerMsgValue,
            forwardPayload: OFFER_ACCEPTED_NOTIFICATION()
        }
    }).send(SEND_MODE_REGULAR);
    
    createMessage({
        bounce: false,
        value: 0,
        dest: domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: buyerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
    
    storage.state = STATE_ACCEPTED;
    storage.validUntil = blockchain.now();
}

fun cancelOffer(mutate storage: Storage, domainAddress: address, buyerAddress: address, sellerMsgValue: coins, cancellationComment: slice, queryId: uint64) {
    if (storage.sellerPrice > 0) {
        createMessage({
            bounce: false,
            value: TONS_NFT_TRANSFER + sellerMsgValue,
            dest: domainAddress,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.sellerAddress,
                responseAddress: buyerAddress,
                forwardTonAmount: sellerMsgValue,
                forwardPayload: COUNTERPROPOSAL_REJECTED_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    } else if (sellerMsgValue > 0) {
        createMessage({
            bounce: false,
            value: sellerMsgValue + TONS_DECLINE_REWARD,
            dest: storage.sellerAddress,
            body: ExcessesMessage { queryId: queryId }
        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
    }
    
    storage.state = STATE_CANCELLED;
    storage.validUntil = min(storage.validUntil, blockchain.now());
    storage.save();
    
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.price + storage.commission,
            toAddress: buyerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: 1,
            forwardPayload: (CommentMessage { comment: cancellationComment }).toCell()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
}

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: false,
        allowChangeData: false,
        allowSendAnyMessage: false,
        allowWithdrawTon: true,
        allowWithdrawJetton: false,
        allowSendNft: true,
    });
    
    var msg = lazy AllowedMessage.fromSlice(in.body);
    var contractBalance = contract.getOriginalBalance();
    
    match (msg) {
        // Fill up balance message from marketplace
        DeployMessage => {
            var storage: Storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                if (storage.state != STATE_UNINIT) {
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage2.buyerAddress,
                        body: CommentMessage { comment: "Offer has already been created" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                    return;
                }
                
                if (contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_MIN_EXCESS) {
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage2.buyerAddress,
                        body: CommentMessage { comment: "offer deployed" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }
            return;
        }

        // Exchange domain for jetton
        NftOwnershipAssignedMessage<SerializableSlice> => {
            var storage: Storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            try {
                assert(storage.validUntil > blockchain.now() && storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage2.domainAddress) throw EXC_INCORRECT_DOMAIN;
                
                storage.sellerAddress = msg.fromAddress;
                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;

                if ((msg.forwardPayload as slice).isEmpty()) {
                    acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, in.valueCoins, msg.queryId);
                }
                else {
                    var forwardPayload = CounterProposePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                    assert(forwardPayload.sellerPrice > storage.sellerPrice) throw EXC_INCORRECT_PRICE;
                    storage.sellerPrice = forwardPayload.sellerPrice;
                    
                    if (forwardPayload.notifyBuyer) {
                        createMessage({
                            bounce: false,
                            value: TONS_OFFER_NOTIFICATION,
                            dest: storage2.buyerAddress,
                            body: CommentMessage { comment: "You have received a counterproposal for your offer on webdom.market" }
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                        contractBalance -= TONS_OFFER_NOTIFICATION;
                    }
                    
                    assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_MIN_EXCESS) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: msg.fromAddress,
                        body: CommentMessage { comment: "Counterproposal sent" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.save();
                return;
            } catch (e, _) {
                if (storage.state == STATE_ACTIVE) {
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                }
                
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: NftTransferMessage<cell> {
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        responseAddress: msg.fromAddress,
                        customPayload: null,
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
        
        // Process counterproposal after NFT ownership transfer
        CounterProposeMessage => {
            var storage = Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert (storage.sellerAddress == in.senderAddress) throw EXC_DEAL_NOT_ACTIVE;
            assert(storage.validUntil > blockchain.now() && storage.sellerPrice > 0) throw EXC_DEAL_NOT_ACTIVE;
            
            storage.sellerPrice = msg.sellerPrice;
    
            if (storage.sellerPrice <= storage.price) {
                acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, in.valueCoins, msg.queryId);
            } 
            else {                
                if (msg.notifyBuyer) {
                    val notificationPrice = createMessage({
                        bounce: false,
                        value: TONS_OFFER_NOTIFICATION,
                        dest: storage2.buyerAddress,
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
                
                assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_COUNTERPROPOSE_PRICE + TONS_COUNTERPROPOSE_GAS) throw EXC_OUT_OF_GAS;
                reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
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
        
        // Process jetton transfer notification (for changing price)
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var storage: Storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            try {
                assert(in.senderAddress == storage.jettonWalletAddress && msg.fromAddress == storage2.buyerAddress) throw EXC_INCORRECT_SENDER;
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                
                msg.forwardPayload = (msg.forwardPayload is Cell<SerializableSlice>) ? msg.forwardPayload.load() : msg.forwardPayload;
                var payload = ChangePricePayload.fromSlice(msg.forwardPayload, { throwIfOpcodeDoesNotMatch: EXC_UNSUPPORTED_OP });
                
                    
                val priceDelta = mulDivFloor(msg.transferredJettons, storage.price, storage.commission + storage.price);
                storage.price = storage.price + priceDelta;
                storage.commission = storage.commission + msg.transferredJettons - priceDelta;
                
                if (storage.price == storage.sellerPrice) {
                    acceptOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, msg.queryId);
                } else {
                    if (storage.sellerPrice != 0) {  // платные все изменения цены после counterproposal
                        createMessage({
                            bounce: false,
                            value: TONS_COUNTERPROPOSE_PRICE,
                            dest: MARKETPLACE_ADDRESS,
                            body: CommentMessage { comment: "Marketplace commission" }
                        }).send(SEND_MODE_REGULAR);
                        contractBalance -= TONS_COUNTERPROPOSE_PRICE;
                    }
                    
                    assert(payload.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
                    
                    storage.validUntil = payload.newValidUntil;
                    storage.createdAt = blockchain.now();
                    
                    // Determine jetton display info
                    var oneJetton: coins = 1000;
                    var jettonName = " WEB3";
                    if (storage2.jettonMinterAddress == USDT_ADDRESS) {
                        oneJetton = 1000000;
                        jettonName = " USDT";
                    }
                    
                    if (payload.notifySeller && storage.sellerAddress != createAddressNone()) {
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
                    
                    assert(contractBalance > TONS_JETTON_SIMPLE_OFFER_RESERVE + TONS_CHANGE_PRICE_GAS) throw EXC_OUT_OF_GAS;
                    // Notify buyer about successful price change
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
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
                storage.save();
                return;
            } catch (e, _) {
                if (storage.state == STATE_ACTIVE) {
                    reserveToncoinsOnBalance(TONS_JETTON_SIMPLE_OFFER_RESERVE, RESERVE_MODE_EXACT_AMOUNT);
                }
                
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: SendJettonsMessage<cell> {
                        queryId: msg.queryId,
                        jettonAmount: msg.transferredJettons,
                        toAddress: msg.fromAddress,
                        responseAddress: msg.fromAddress,
                        customPayload: null,
                        forwardTonAmount: 1,
                        forwardPayload: beginCell()
                                        .storeUint(0, 32)
                                        .storeSlice("Error. Code ")
                                        .storeNumber10(e)
                                    .endCell()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
                
                commitContractDataAndActions();
                throw e;
            }
        }
                
        // Change valid until
        ChangeValidUntilMessage => {
            var storage: Storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage2.buyerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            assert(msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.validUntil = msg.newValidUntil;
            storage.save();
            
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
            var storage: Storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            var sellerMsgValue: coins = 0;

            if (in.senderAddress == storage2.buyerAddress) {
                // Buyer can cancel if 10 minutes have passed since creation, or offer has expired, or there's a counterproposal
                assert(storage.createdAt + 600 < blockchain.now() || storage.validUntil < blockchain.now() || storage.sellerPrice != 0) throw EXC_CANT_CANCEL_DEAL;
            } else if (in.senderAddress == storage.sellerAddress) {
                storage.cancelledBySeller = true;
                sellerMsgValue = in.valueCoins;
            } else {
                throw EXC_INCORRECT_SENDER;
            }   

            if (msg.cancellationComment.isEmpty()) {
                msg.cancellationComment = "Your offer on webdom.market was cancelled";
            }
            
            cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, sellerMsgValue, msg.cancellationComment, msg.queryId);
            return;
        }
        
        CommentMessage => {
            if (msg.comment.bitsEqual("cancel")) {
                var storage = lazy Storage.load();
                var storage2 = lazy storage.ds2.load();
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                assert(storage2.buyerAddress == in.senderAddress) throw EXC_INCORRECT_SENDER;

                cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, "Your offer on webdom.market was cancelled", 0);
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
        
    var storage2 = lazy storage.ds2.load();
    
    if (blockchain.now() >= storage.validUntil) {
        acceptExternalMessage();
        cancelOffer(mutate storage, storage2.domainAddress, storage2.buyerAddress, 0, "Offer expired", queryId);
        return;
    } else {
        assert(storage2.publicKeyCell != null) throw EXC_INVALID_SIGNATURE;
        val publicKey = storage2.publicKeyCell!.load();
        val signature = in.body.loadBits(512);
        assert(isSignatureValid(in.body.hash(), signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;
        assert(in.body.loadAddress() == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
        
        acceptExternalMessage();
        var comment = in.body.loadRef().beginParse();
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
        1,
        storage.state == STATE_ACCEPTED ? 1 : 0,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        0,
        storage.validUntil,
        storage2.buyerAddress,
        storage2.domainName,
        storage.cancelledBySeller ? -1 : 0,
        storage.jettonWalletAddress,
        storage.sellerPrice,
        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
}
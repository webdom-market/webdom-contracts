import "@stdlib/tvm-dicts";
import "../../imports/constants";
import "../../imports/messages";
import "../../imports/utils";
import "../../imports/types";
import "storage";
import "messages";
import "@stdlib/gas-payments";
import "../../imports/handle_promotion";
import "../../imports/admin_message";
import "../constants";
import "../messages";

@inline
fun cancelDeal(mutate storage: Storage, domainAddress: address, queryId: uint64) {
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.sellerAddress,
            responseAddress: storage.sellerAddress,
            forwardTonAmount: 1,
            forwardPayload: SALE_CANCEL_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.state = STATE_CANCELLED;
    storage.validUntil  = min(storage.validUntil, blockchain.now());
    storage.save();

    return;
}

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);

    handleAdminMessage(
        in.senderAddress,
        in.body,
        Permissions {
            allowWithdrawTon:  true,
            allowWithdrawJetton: true
        }
    );

    var msg = lazy AllowedMessage.fromSlice(in.body);

    match(msg) {
        DeployMessage => {
            var storage = lazy Storage.load();
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                val msgValue: coins = contract.getOriginalBalance() - TONS_MIN_RESERVE_FOR_AUTOCANCEL;
                if (msgValue > TONS_MIN_EXCESS) {
                    createMessage<CommentMessage>({
                        bounce: false,
                        value: msgValue,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Domain sale deployed successfully" }
                    }).send(SEND_MODE_REGULAR);
                }

                storage.save();
                return;
            }
            return;
        }

        JettonsTransferNotificationMessage<SerializableSlice> => {
            var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            try {
                assert(in.senderAddress == storage.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.valueCoins >= TONS_JETTON_SIMPLE_PURCHASE) throw EXC_OUT_OF_GAS;
                assert(msg.transferredJettons >= storage.price) throw EXC_NOT_ENOUGH_JETTONS;

                if (msg.forwardPayload is Cell<SerializableSlice>) {
                    msg.forwardPayload = msg.forwardPayload.load(); 
                }
                if ((msg.forwardPayload as slice).remainingBitsCount() == 267) {
                    msg.fromAddress = address.fromSlice(msg.forwardPayload);
                }

                var excesses = msg.transferredJettons - storage.price;
                if (excesses > 0) {
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER,
                        dest: in.senderAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: excesses,
                            toAddress: msg.fromAddress,
                            responseAddress: msg.fromAddress,
                            forwardTonAmount: 1,
                            forwardPayload: (CommentMessage { comment: "Excesses" }).toCell()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                if (storage.commission > 0) {
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
                        dest: in.senderAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.commission,
                            toAddress: MARKETPLACE_ADDRESS,
                            responseAddress: msg.fromAddress,
                            forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                            forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                createMessage({
                    bounce: false,
                    value: TONS_JETTON_TRANSFER + contract.getOriginalBalance() - in.valueCoins,
                    dest: in.senderAddress,
                    body: SendJettonsMessage<cell> {
                        queryId: msg.queryId,
                        jettonAmount: storage.price - storage.commission,
                        toAddress: storage.sellerAddress,
                        responseAddress: msg.fromAddress,
                        forwardTonAmount: 1,
                        forwardPayload: getPayoutNotificationBody(storage.domainNameCell)
                    }
                }).send(SEND_MODE_REGULAR);

                createMessage({
                    bounce: false,
                    value: 0,
                    dest: storage2.domainAddress,
                    body: NftTransferMessage<cell> {
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        responseAddress: msg.fromAddress,
                        forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                        forwardPayload: BUYER_NOTIFICATION()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);

                storage.state            = STATE_COMPLETED;
                storage.validUntil       = blockchain.now();
                storage2.buyerAddress    = msg.fromAddress;
                storage.ds2 = storage2.toCell();
                storage.save();

                return;
            } catch (e, _) {
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
                }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                
                commitContractDataAndActions();
                throw e;
            }
        }

        ChangePriceMessage => {
            var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;

            var (oneJetton, symbol) = storage2.jettonMinterAddress == WEB3_ADDRESS ? (1000, "WEB3") : (1000000, "USDT");    
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                        .storeUint(0, 32)
                        .storeSlice("Price changed to ")
                        .storeStrJettons(msg.newPrice, oneJetton, symbol)
                      .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);

            storage.commission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            storage.price = msg.newPrice;
            storage.validUntil = msg.newValidUntil;
            storage.save();

            return;
        }

        RenewDomainMessage => {
            var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN) throw EXC_OUT_OF_GAS;
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // check that domain expires later than in one day

            reserveToncoinsOnBalance(TONS_MIN_RESERVE_FOR_AUTOCANCEL, RESERVE_MODE_EXACT_AMOUNT);

            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: storage2.domainAddress,
            }).send(SEND_MODE_PAY_FEES_SEPARATELY);
            
            createMessage<RenewalFeeMessage>({
                bounce: false,
                value: 0,
                dest: MARKETPLACE_ADDRESS,
                body: RenewalFeeMessage { queryId: msg.queryId }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            var newValidUntil: uint32;
            if (msg.newValidUntil != null) {
                newValidUntil = min(blockchain.now() + ONE_YEAR - ONE_DAY, msg.newValidUntil);
            } else {
                newValidUntil = blockchain.now() + ONE_YEAR - ONE_DAY;
            }
            
            assert(newValidUntil >= max(blockchain.now() + ONE_HOUR, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.validUntil = newValidUntil;
            storage.lastRenewalTime = blockchain.now();
            storage.save();

            return;
        }

        DnsBalanceReleaseMessage => {
            var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage2.domainAddress) throw EXC_INCORRECT_DOMAIN;

            createMessage({
                bounce: false,
                value: 0,
                dest: storage.sellerAddress,
                body: CommentMessage { comment: "Your domain has expired" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);

            storage.state = STATE_CANCELLED;
            storage.validUntil = min(storage.validUntil, blockchain.now());
            storage.save();
            return;
        }

        MakeHotMessage => {
            var storage = lazy Storage.load();
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        MakeColoredMessage => {
            var storage = lazy Storage.load();
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        ExcessesMessage => { 
            return; 
        }

        else => {
            if (in.body.remainingBitsCount() >= 32) {
                var op = in.body.loadUint(32);
                if ((op == 0 && in.body.bitsEqual("cancel")) || op == OP_CANCEL_DEAL) {
                    var storage = lazy Storage.load();
                    var storage2 = lazy storage.ds2.load();
                    cancelDeal(mutate storage, storage2.domainAddress, 0);
                    return;
                }
            }
            throw EXC_UNSUPPORTED_OP;
        }
    }
}


fun onExternalMessage(in: InMessage): void {
    var storage = Storage.load();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }
    
    if (blockchain.now() >= storage.validUntil) {
        var opCode = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        
        acceptExternalMessage();
        var storage2 = lazy storage.ds2.load();
        cancelDeal(mutate storage, storage2.domainAddress, in.body.loadUint(64));
        
        return;
    }
    
    throw 0xfffe;
}


get fun get_storage_data() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();
    var dict = createEmptyDict();
    dict.sDictSet(267, storage2.domainAddress as slice, BIT_TRUE_SLICE());
 
    return (
        storage.sellerAddress,
        dict,
        1,
        1,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        storage.lastRenewalTime,
        storage.validUntil,
        storage2.buyerAddress,
        storage.domainNameCell,
        storage.jettonWalletAddress,

        storage.hotUntil,
        storage.coloredUntil,

        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
} 
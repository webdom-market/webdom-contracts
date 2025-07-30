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
fun cancelDeal(mutate storage: Storage, queryId: uint64) {
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: storage.domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.sellerAddress,
            responseAddress: storage.sellerAddress,
            forwardTonAmount: 1,
            forwardPayload: SALE_CANCEL_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.state = STATE_CANCELLED;
    if (storage.validUntil > blockchain.now()) {
        storage.validUntil = blockchain.now();
    }
    storage.save();
    return;
}


fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    // var storage = lazy Storage.load();

    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state != STATE_ACTIVE,
        allowChangeData: storage.state != STATE_ACTIVE,
        allowSendAnyMessage: storage.state != STATE_ACTIVE,
        allowWithdrawTon:  true,
        allowWithdrawJetton: true,
    });
    
    val msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        FillUpBalanceMessage => {
            // var storage = lazy Storage.load();
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }
            return;
        }
        
        DnsBalanceReleaseMessage => {
            // var storage = lazy Storage.load();
            assert(in.senderAddress == storage.domainAddress) throw EXC_INCORRECT_DOMAIN;
            
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.sellerAddress,
                body: CommentMessage { comment: "Your domain has expired" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            storage.state = STATE_CANCELLED;
            if (storage.validUntil > blockchain.now()) {
                storage.validUntil = blockchain.now();
            }
            storage.save();
            return;
        }
        
        ChangePriceMessage => {
            // var storage = lazy Storage.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;            
            assert((msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) && 
                   (msg.newValidUntil <= storage.lastRenewalTime + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.price = msg.newPrice;
            storage.commission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            storage.validUntil = msg.newValidUntil;
            storage.save();
                        
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                        .storeUint(0, 32)
                        .storeSlice("Price changed to ")
                        .storeStrFloat(msg.newPrice, ton("1"))
                        .storeSlice(" TON")
                    .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
            return;
        }
        
        RenewDomainMessage => {
            // var storage = lazy Storage.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN) throw EXC_OUT_OF_GAS;
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // check that domain expires later than in one day
                        
            reserveToncoinsOnBalance(TONS_MIN_RESERVE_FOR_AUTOCANCEL, RESERVE_MODE_EXACT_AMOUNT);

            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: storage.domainAddress,
            }).send(SEND_MODE_PAY_FEES_SEPARATELY);
            
            createMessage<RenewalFeeMessage>({
                bounce: false,
                value: 0,
                dest: MARKETPLACE_ADDRESS,
                body: RenewalFeeMessage { queryId: msg.queryId }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
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

        MakeHotMessage => {
            // var storage = lazy Storage.load();
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        MakeColoredMessage => {
            // var storage = lazy Storage.load();
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        
        ExcessesMessage => {
            return;
        }

        else => {
            var op: uint32 = 0;
            var senderAddress = in.senderAddress;
            if (in.body.remainingBitsCount() >= 32) {
                op = in.body.loadUint(32);
                if (op == 0 && in.body.bitsEqual("cancel")) {
                    op = OP_CANCEL_DEAL;
                }
                else if (op == OP_DEDUST_PAYOUT) {
                    senderAddress = in.body as address;
                    op = 0;
                }
            }
            
            // var storage = lazy Storage.load();
            try {
                if (op == 0) {
                    assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;
                    assert(contract.getOriginalBalance() >= storage.price + TONS_TON_SIMPLE_PURCHASE) throw EXC_OUT_OF_GAS;

                    createMessage<CommentMessage>({
                        bounce: false,
                        value: storage.commission,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);
                    
                    createMessage<cell>({
                        bounce: false,
                        value: storage.price - storage.commission,
                        dest: storage.sellerAddress,
                        body: getPayoutNotificationBody(storage.domainNameCell)
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);

                    createMessage<NftTransferMessage<cell>>({
                        bounce: false,
                        value: 0,
                        dest: storage.domainAddress,
                        body: NftTransferMessage<cell> {
                            queryId: 0,
                            toAddress: senderAddress,
                            responseAddress: senderAddress,
                            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                            forwardPayload: BUYER_NOTIFICATION()
                        }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);

                    storage.state = STATE_COMPLETED;
                    storage.validUntil = blockchain.now();
                    storage.buyerAddressCell = senderAddress.toCell();
                    storage.save();

                    return;
                }
                else if (op == OP_CANCEL_DEAL) {
                    assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                    assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                    cancelDeal(mutate storage, in.body.remainingBitsCount() >= 64 ? in.body.loadUint(64) : 0);

                    return;
                }
            } catch (e, _) {
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: senderAddress,
                    body: beginCell().storeUint(0, 32).storeSlice("Error, code 44").endCell()
                }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                
                commitContractDataAndActions();

                throw e;
            }

            throw EXC_UNSUPPORTED_OP;
        }
    }
}

fun onExternalMessage(in: InMessage) {
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
        cancelDeal(mutate storage, in.body.loadUint(64));
        
        return;
    }
    
    throw 0xfffe;
}

get fun get_storage_data() {
    var storage = Storage.load();
    
    var domainsDict = createEmptyDict();
    domainsDict.sDictSet(267, storage.domainAddress as slice, BIT_TRUE_SLICE());
    
    var buyerAddress = storage.buyerAddressCell == null ? createAddressNone() : storage.buyerAddressCell!.load();
    
    return (
        storage.sellerAddress,
        domainsDict,
        1,
        1,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        storage.lastRenewalTime,
        storage.validUntil,
        buyerAddress,
        storage.domainNameCell,
        storage.hotUntil,
        storage.coloredUntil,
        BURN_ADDRESS,
        contract.getCode().hash()
    );
} 
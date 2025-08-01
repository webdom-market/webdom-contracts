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
import "../messages";
import "../constants";
import "storage";

const TONS_MIN_TON_FOR_STORAGE: uint32 = ton("0.035") as uint32;

@inline
fun cancelSale(mutate storage: Storage, queryId: uint64, cancelReason: slice) {
    setGasLimitToMaximum();

    var (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetFirst(267);
    while (found) {
        if (domainReceived!.bitsEqual(BIT_TRUE_SLICE())) {
            createMessage({
                bounce: false,
                value: TONS_NFT_TRANSFER,
                dest: domainAddress! as address,
                body: NftTransferMessage<cell> {
                    queryId: queryId,
                    toAddress: storage.sellerAddress,
                    responseAddress: storage.sellerAddress,
                    forwardTonAmount: 1,
                    forwardPayload: null
                }
            }).send(SEND_MODE_REGULAR);
        }
        (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
    }
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.sellerAddress,
        body: CommentMessage { comment: cancelReason }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.state = STATE_CANCELLED;
    storage.validUntil = blockchain.now();
    storage.save();
}

fun onBouncedMessage(in: InMessageBounced) {
    if (in.valueCoins > TONS_MIN_EXCESS) {
        val storage = lazy Storage.load();
        createMessage({
            bounce: true,
            value: 0,
            dest: storage.sellerAddress,
            body: ExcessesMessage { queryId: 0 }
        }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
    }
}

@inline
fun getTonsToReserve(domainsTotal: uint8, nothrow: bool): int {
    var tonsToReserve = (TONS_NFT_TRANSFER + ton("0.0075")) * domainsTotal + TONS_MIN_TON_FOR_STORAGE;
    var actualBalance = contract.getOriginalBalance() - ton("0.01") - storageFees();
    assert(actualBalance >= TONS_MIN_TON_FOR_STORAGE || nothrow) throw EXC_OUT_OF_GAS;
    if (actualBalance < tonsToReserve) {
        return TONS_MIN_TON_FOR_STORAGE;
    }
    return tonsToReserve as int;
}

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    var storage = lazy Storage.load();
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.validUntil + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
        allowWithdrawJetton: true,
    });
    
    val msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        FillUpBalanceMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                storage.state = STATE_ACTIVE;
                storage.save();
            }
            return;
        }
        
        NftOwnershipAssignedMessage<SerializableSlice> => {
            try {
                var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
                assert(found) throw EXC_INCORRECT_DOMAIN;
                
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                storage.domainsReceived += 1;

                if (storage.domainsReceived == storage.domainsTotal) {
                    reserveToncoinsOnBalance(getTonsToReserve(storage.domainsTotal, false), RESERVE_MODE_EXACT_AMOUNT);
                    
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Multiple sale on webdom.market is active" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.save();
                return;
            } catch (e, _) {
                returnNftToSender(in.senderAddress, msg, e);
            }
        }
        
        DnsBalanceReleaseMessage => {
            var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
            assert(found) throw EXC_INCORRECT_DOMAIN;
            
            if (storage.state != STATE_CANCELLED) {
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_FALSE_SLICE());
                cancelSale(mutate storage, 0, "Your domain has expired");
            }
            
            return;
        }
        
        ChangePriceMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            var newCommission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            assert((msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) && 
                   (msg.newValidUntil <= storage.lastRenewalTime + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;

            storage.validUntil = msg.newValidUntil;
            storage.price = msg.newPrice;
            storage.commission = newCommission;
            storage.save();
            
            createMessage({
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
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN * storage.domainsTotal) throw EXC_OUT_OF_GAS;
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;

            reserveToncoinsOnBalance(max(getTonsToReserve(storage.domainsTotal, false), contract.getOriginalBalance() - in.valueCoins - ton("0.007")), RESERVE_MODE_EXACT_AMOUNT);
            
            var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
            while (found) {
                createMessage({
                    bounce: false,
                    value: TONS_RENEW_DOMAIN,
                    dest: domainAddress! as address
                }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
            }
            
            createMessage({
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
            storage.save();
            return;
        }

        MakeHotMessage => {
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        MakeColoredMessage => {
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        
        ExcessesMessage => {
            return;
        }

        else => {
            var op: uint32 = 0;
            var queryId: uint64 = 0;
            var senderAddress = in.senderAddress;
            
            if (in.body.remainingBitsCount() >= 32) {
                op = in.body.loadUint(32);
                if (in.body.remainingBitsCount() >= 64) {
                    queryId = in.body.loadUint(64);
                }
            }
            
            if (op == OP_DEDUST_PAYOUT) {
                op = 0;
                senderAddress = in.body as address;
            }
            
            try {
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                
                if (op == 0) {
                    assert((storage.domainsReceived == storage.domainsTotal) && (storage.state == STATE_ACTIVE) && (storage.validUntil > blockchain.now())) throw EXC_DEAL_NOT_ACTIVE;
                    assert(in.valueCoins >= storage.price + TONS_TON_SIMPLE_PURCHASE * storage.domainsTotal) throw EXC_OUT_OF_GAS;

                    createMessage({
                        bounce: false,
                        value: storage.commission,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);

                    var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
                    while (found) {
                        createMessage({
                            bounce: false,
                            value: TONS_PURCHASE_NOTIFICATION + TONS_NFT_TRANSFER,
                            dest: domainAddress! as address,
                            body: NftTransferMessage<cell> {
                                queryId: queryId,
                                toAddress: senderAddress,
                                responseAddress: senderAddress,
                                forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                                forwardPayload: BUYER_NOTIFICATION()
                            }
                        }).send(SEND_MODE_REGULAR);
                        (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
                    }

                    createMessage({
                        bounce: false,
                        value: (contract.getOriginalBalance() - in.valueCoins) + storage.price - storage.commission,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Payout for multiple domains sale on webdom.market" }
                    }).send(SEND_MODE_REGULAR);

                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: senderAddress,
                        body: ExcessesMessage { queryId: queryId }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);

                    storage.state = STATE_COMPLETED;
                    storage.validUntil = blockchain.now();
                    storage.buyerAddress = senderAddress;
                    storage.save();
                    return;
                }
                else if (op == OP_CANCEL_DEAL) {
                    assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                    cancelSale(mutate storage, queryId, "Sale cancelled");
                    return;
                }
                else {
                    throw EXC_UNSUPPORTED_OP;
                }
            } catch (e, _) {                
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: senderAddress,
                    body: CommentMessage { comment: "Unsupported op" }
                }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                
                commitContractDataAndActions();
                throw e;
            }
        }
    }
}

fun onExternalMessage(in: InMessage) {
    var storage = lazy Storage.load();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }
    
    if (blockchain.now() >= storage.validUntil) {
        var opCode = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        
        acceptExternalMessage();
        var queryId = in.body.loadUint(64);
        
        cancelSale(mutate storage, queryId, "Your sale offer has expired");
        
        storage.state = STATE_CANCELLED;
        storage.save();
        return;
    }
    
    throw 0xfffe;
}

get fun get_storage_data() {
    var storage = Storage.load();
    
    return (
        storage.sellerAddress,
        storage.domainsDict,
        storage.domainsTotal,
        storage.domainsReceived,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        storage.lastRenewalTime,
        storage.validUntil,
        storage.buyerAddress,
        getTonsToReserve(storage.domainsTotal, true),
        storage.hotUntil,
        storage.coloredUntil,
        BURN_ADDRESS,
        contract.getCode().hash()
    );
} 
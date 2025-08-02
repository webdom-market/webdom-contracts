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

const TONS_MIN_TON_FOR_STORAGE: coins = ton("0.035");

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
        var storage = lazy Storage.load();
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
        DeployAndSetWalletMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                storage.save();
            }
            return;
        }
        
        NftOwnershipAssignedMessage => {
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
        
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var fromAddress = msg.fromAddress;
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                fromAddress = address.fromSlice(msg.forwardPayload.load());
            }
            else if (msg.forwardPayload.remainingBitsCount() == 267) {
                fromAddress = address.fromSlice(msg.forwardPayload);
            }

            try {
                assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now() && storage.domainsReceived == storage.domainsTotal) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                assert(in.valueCoins >= TONS_TON_SIMPLE_PURCHASE * storage.domainsTotal + TONS_JETTON_MULTIPLE_PURCHASE) throw EXC_OUT_OF_GAS;
                assert(msg.transferredJettons >= storage.price) throw EXC_NOT_ENOUGH_JETTONS;

                var excesses = msg.transferredJettons - storage.price;
                if (excesses > 0) {
                    // send excesses to buyer
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER,
                        dest: storage.jettonWalletAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: excesses,
                            toAddress: fromAddress,
                            responseAddress: fromAddress,
                            forwardTonAmount: 1,
                            forwardPayload: EXCESSES_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                if (storage.commission > 0) {
                    // send marketplace commission
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
                        dest: storage.jettonWalletAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.commission,
                            toAddress: MARKETPLACE_ADDRESS,
                            responseAddress: fromAddress,
                            forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                            forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                // send domains
                var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
                while (found) {
                    createMessage({
                        bounce: false,
                        value: TONS_PURCHASE_NOTIFICATION + TONS_NFT_TRANSFER,
                        dest: domainAddress! as address,
                        body: NftTransferMessage<cell> {
                            queryId: msg.queryId,
                            toAddress: fromAddress,
                            responseAddress: fromAddress,
                            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                            forwardPayload: BUYER_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                    (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
                }

                // send seller payout
                createMessage({
                    bounce: false,
                    value: TONS_JETTON_TRANSFER,
                    dest: storage.jettonWalletAddress,
                    body: SendJettonsMessage<cell> {
                        queryId: msg.queryId,
                        jettonAmount: storage.price - storage.commission,
                        toAddress: storage.sellerAddress,
                        responseAddress: storage.sellerAddress,
                        forwardTonAmount: 1,
                        forwardPayload: MULTIPLE_SALE_NOTIFICATION()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);

                storage.state = STATE_COMPLETED;
                storage.validUntil = blockchain.now();
                storage.buyerAddressCell = fromAddress.toCell();
                storage.save();
                return;
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
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
            
            val isWeb3 = storage.jettonMinterAddressCell.load() == WEB3_ADDRESS;
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                    .storeUint(0, 32)
                    .storeSlice("Price changed to ")
                    .storeStrFloat(msg.newPrice, isWeb3 ? 1000 : 1000000)
                    .storeSlice(isWeb3 ? " WEB3" : " USDT")
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
                body: RenewalFeeMessage { queryId: msg.queryId, ownerAddress: storage.sellerAddress }
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
            if (in.body.remainingBitsCount() >= 32) {
                var op = in.body.loadUint(32);
                if ((op == 0 && in.body.bitsEqual("cancel")) || op == OP_CANCEL_DEAL) {
                    // var storage = lazy Storage.load();
                    cancelSale(mutate storage,  0, "Sale cancelled");
                    return;
                }
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
        var queryId = in.body.loadUint(64);
        
        cancelSale(mutate storage, queryId, "Your sale offer has expired");
            
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
        storage.buyerAddressCell.load(),
        getTonsToReserve(storage.domainsTotal, true),
        storage.jettonWalletAddress,
        storage.hotUntil,
        storage.coloredUntil,
        storage.jettonMinterAddressCell.load(),
        contract.getCode().hash()
    );
}

get fun get_fix_price_data_v4() {
    var storage = lazy Storage.load();

    var (domainAddress, _, _) = storage.domainsDict.sDictGetFirst(267);
    var jettonPriceDict = createEmptyDict();
    jettonPriceDict.uDictSetBuilder(256, storage.jettonWalletAddress.getWorkchainAndHash().1, beginCell().storeCoins(storage.price));

    return (
        storage.state > STATE_ACTIVE,
        storage.createdAt,
        MARKETPLACE_ADDRESS,
        domainAddress,
        storage.sellerAddress,
        0,
        MARKETPLACE_ADDRESS,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER * 10, storage.price),
        BURN_ADDRESS,
        0,
        ((storage.validUntil > blockchain.now()) | (storage.state != STATE_COMPLETED)) ? (0 as uint32) : storage.validUntil,
        0,
        jettonPriceDict
    );
}

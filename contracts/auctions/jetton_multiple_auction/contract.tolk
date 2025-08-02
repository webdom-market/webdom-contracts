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
import "../../fix_price_sales/constants"

const TONS_MIN_TON_FOR_STORAGE: coins = ton("0.04");

@inline
fun cancelAuction(mutate storage: Storage, queryId: uint64, cancelReason: slice) {
    setGasLimitToMaximum();
    var (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetFirst(267);
    while(found) {
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
    storage.endTime = blockchain.now();
    storage.save();
}

@inline
fun endAuctionSuccess(mutate storage: Storage, jettonWalletAddress: address, maxCommission: uint64, queryId: uint64, additionalTons: coins) {
    setGasLimitToMaximum();
    var commission: coins = 0;
    if (storage.commissionFactor != 0) {
        commission = min(mulDivFloor(storage.lastBidValue, storage.commissionFactor, COMMISSION_DIVIDER), maxCommission);
        
        // send marketplace commission
        createMessage({
            bounce: false,
            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
            dest: jettonWalletAddress,
            body: SendJettonsMessage<cell> {
                queryId: queryId,
                jettonAmount: commission,
                toAddress: MARKETPLACE_ADDRESS,
                responseAddress: storage.lastBidderAddress,
                forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    }

    // send seller payout
    createMessage({
        bounce: false,
        value: TONS_JETTON_TRANSFER + additionalTons,
        dest: jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.lastBidValue - commission,
            toAddress: storage.sellerAddress,
            responseAddress: storage.lastBidderAddress,
            forwardTonAmount: additionalTons + 1,
            forwardPayload: MULTIPLE_AUCTION_NOTIFICATION()
        }
    }).send(SEND_MODE_REGULAR);

    // transfer domains
    var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
    repeat(storage.domainsTotal - 1) {
        createMessage({
            bounce: false,
            value: TONS_PURCHASE_NOTIFICATION + TONS_NFT_TRANSFER,
            dest: domainAddress! as address,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.lastBidderAddress,
                responseAddress: storage.lastBidderAddress,
                forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                forwardPayload: BUYER_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
        (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
    }
    
    // last domain transfer with remaining balance
    createMessage({
        bounce: false,
        value: 0,
        dest: domainAddress! as address,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.lastBidderAddress,
            responseAddress: storage.lastBidderAddress,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.state = STATE_COMPLETED;
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

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    var storage = lazy Storage.load();
    
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.endTime + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
    });
    
    val msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        DeployAndSetWalletMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                var storage2 = lazy storage.ds2.load();
                storage2.jettonWalletAddress = msg.jettonWalletAddress;
                storage.ds2 = storage2.toCell();
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
                    var balanceToReserve = (TONS_NFT_TRANSFER + ton("0.0075")) * storage.domainsTotal + TONS_MIN_TON_FOR_STORAGE;
                    if (contract.getOriginalBalance() - ton("0.01") < balanceToReserve) {
                        balanceToReserve = TONS_MIN_TON_FOR_STORAGE;  // disable cancellation by external message if balance is not enough
                    }
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Multiple auction on webdom.market is active" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.save();
                return;
            } catch (e, _) {
                returnNftToSender(in.senderAddress, msg, e);
            }
        }
        
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var fromAddress = msg.fromAddress;
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                fromAddress = address.fromSlice(msg.forwardPayload.load());
            }
            else if (msg.forwardPayload.remainingBitsCount() == 267) {
                fromAddress = address.fromSlice(msg.forwardPayload);
            }
            var storage2 = lazy storage.ds2.load();
            try {
                assert(in.senderAddress == storage2.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                
                if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
                    storage.endTime = blockchain.now() + storage.endTime - storage.startTime;
                    storage.startTime = blockchain.now();
                    storage.isDeferred = false;
                }
                
                assert((blockchain.now() >= storage.startTime) && (blockchain.now() < storage.endTime) && (storage.domainsReceived == storage.domainsTotal)) throw EXC_DEAL_NOT_ACTIVE;
                
                val tonsToReserve = TONS_JETTON_TRANSFER * 2 + TONS_NOTIFY_MARKETPLACE + TONS_TON_SIMPLE_PURCHASE * storage.domainsTotal + TONS_MIN_TON_FOR_STORAGE;
                var requiredGas = tonsToReserve;
                if (msg.transferredJettons > storage2.maxBidValue) {
                    requiredGas += TONS_JETTON_TRANSFER;
                }

                assert(in.valueCoins >= requiredGas) throw EXC_OUT_OF_GAS;

                var nextMinBidValue = max(
                    max(storage.lastBidValue + 1000, storage.minBidValue),
                    mulDivFloor(storage.lastBidValue, storage.minBidIncrement, BID_INCREMENT_DIVIDER)
                );
                assert(msg.transferredJettons >= nextMinBidValue) throw EXC_BID_TOO_LOW;
                
                if (storage.endTime <= blockchain.now() + storage.timeIncrement) {
                    // предотвращаем истечение срока действия домена
                    storage.endTime = min(blockchain.now() + storage.timeIncrement, storage.lastDomainRenewalTime + ONE_YEAR - ONE_DAY);
                }

                val prevTonBalance = contract.getOriginalBalance() - in.valueCoins - storageFees();
                if (storage.lastBidValue != 0) {
                    // return the previous bid
                    createMessage({
                        bounce: false,
                        value: prevTonBalance,  // всегда больше TONS_JETTON_TRANSFER
                        dest: storage2.jettonWalletAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.lastBidValue,
                            toAddress: storage.lastBidderAddress,
                            responseAddress: storage.lastBidderAddress,
                            forwardTonAmount: 1,
                            forwardPayload: OUTBID_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                }
                else if (prevTonBalance > TONS_MIN_EXCESS) {
                    // после первой ставки за обеспечение аукциона отвечает последний участник аукциона, 
                    // поэтому возвращаем продавцу изначально отправленные на контракт тоны
                    createMessage({
                        bounce: true,
                        value: prevTonBalance,
                        dest: storage.sellerAddress,
                        body: ExcessesMessage { queryId: msg.queryId }
                    }).send(SEND_MODE_REGULAR);
                }

                storage.lastBidTime = blockchain.now();
                storage.lastBidderAddress = fromAddress;
                
                if (msg.transferredJettons >= storage2.maxBidValue) {
                    if (msg.transferredJettons > storage2.maxBidValue) {
                        // return excess jettons
                        createMessage({
                            bounce: false,
                            value: TONS_JETTON_TRANSFER,
                            dest: storage2.jettonWalletAddress,
                            body: SendJettonsMessage<cell> {
                                queryId: msg.queryId,
                                jettonAmount: msg.transferredJettons - storage2.maxBidValue,
                                toAddress: fromAddress,
                                responseAddress: fromAddress,
                                forwardTonAmount: 1,
                                forwardPayload: EXCESSES_NOTIFICATION()
                            }
                        }).send(SEND_MODE_REGULAR);
                    }
                    
                    storage.lastBidValue = storage2.maxBidValue;
                    storage.endTime = blockchain.now();
                    
                    endAuctionSuccess(mutate storage, storage2.jettonWalletAddress, storage2.maxCommission, msg.queryId, 0);
                    return;
                } else {
                    reserveToncoinsOnBalance(tonsToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: fromAddress,
                        body: CommentMessage { comment: "Bid placed successfully" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                
                storage.lastBidValue = msg.transferredJettons;
                storage.save();
                return;
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
        }
        
        RenewDomainMessage => {
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN * storage.domainsTotal) throw EXC_OUT_OF_GAS;
            assert(storage.lastDomainRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;
            reserveToncoinsOnBalance(storageFees(), 4);
            
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

            storage.lastDomainRenewalTime = blockchain.now();
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
                if ((op == 0 && (in.body.bitsEqual("cancel") || in.body.bitsEqual("stop"))) || op == OP_STOP_AUCTION || op == OP_CANCEL_DEAL) {
                    if (storage.lastBidValue == 0) {  // Cancel auction if it hasn't started yet
                        assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
                        cancelAuction(mutate storage, 0, "Multiple auction on webdom.market was cancelled");
                        return;
                    } else if (storage.endTime <= blockchain.now()) {  // End auction if it is over
                        var additionalTons: coins;
                        if (in.senderAddress == storage.sellerAddress) {
                            additionalTons = in.valueCoins;
                        } else {
                            assert(in.senderAddress == storage.lastBidderAddress) throw EXC_INCORRECT_SENDER;
                            additionalTons = 0;
                        }
                        var storage2 = lazy storage.ds2.load();
                        endAuctionSuccess(mutate storage, storage2.jettonWalletAddress, storage2.maxCommission, 0, additionalTons);
                        return;
                    } else {
                        throw EXC_AUCTION_NOT_ENDED;
                    }
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
    
    if (blockchain.now() >= storage.endTime) {
        var opCode = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        
        acceptExternalMessage();
        var queryId = in.body.loadUint(64);
        
        if (storage.lastBidValue == 0) {  // No one participated in the auction
            assert(contract.getOriginalBalance() >= (TONS_NFT_TRANSFER + ton("0.0075")) * storage.domainsTotal) throw EXC_OUT_OF_GAS;
            cancelAuction(mutate storage, queryId, "Multiple auction on webdom.market has ended without bids");
        } else {  // Auction finished successfully
            var storage2 = lazy storage.ds2.load();
            endAuctionSuccess(mutate storage, storage2.jettonWalletAddress, storage2.maxCommission, queryId, 0);
        }
        
        return;
    }
    
    throw 0xfffe;
}

get fun get_storage_data() {
    var storage = Storage.load();
    var storage2 = storage.ds2.load();
    return (
        storage.sellerAddress,
        storage.domainsDict,
        storage.domainsTotal,
        storage.domainsReceived,
        storage.state,
        storage2.maxBidValue,
        storage.commissionFactor,
        storage.startTime,
        storage.lastDomainRenewalTime,
        storage.endTime,
        storage.lastBidderAddress,
        storage.minBidValue,
        storage.minBidIncrement,
        storage.timeIncrement,
        storage.lastBidValue,
        storage.lastBidTime,
        storage2.maxCommission,
        storage2.jettonWalletAddress,
        storage.isDeferred && (blockchain.now() < storage.startTime),
        storage.hotUntil,
        storage.coloredUntil,
        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
}

// Legacy methods from https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-auction-v4r1.func
get fun get_auction_data_v4() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();

    val (domainAddress, _, _) = storage.domainsDict.sDictGetFirst(267);
    if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
        storage.endTime = blockchain.now() + storage.endTime - storage.startTime;
        storage.startTime = blockchain.now();
    }

    return (
        storage.state != STATE_UNINIT,                 // Int1
        storage.state > STATE_ACTIVE,                  // Int1
        storage.endTime,                               // Uint32
        MARKETPLACE_ADDRESS,                           // MsgAddressStd
        domainAddress,                                 // MsgAddressStd
        storage.sellerAddress,                         // MsgAddressStd
        storage.lastBidValue,                          // Coins
        storage.lastBidderAddress,                     // MsgAddressStd
        (storage.minBidIncrement - 1000) / 10,         // Uint7
        MARKETPLACE_ADDRESS,                           // MsgAddressStd
        storage.commissionFactor, COMMISSION_DIVIDER,  // Uint16, Uint16
        BURN_ADDRESS,                                  // MsgAddressStd
        0, 1,                                          // Uint32, Uint32
        storage2.maxBidValue,                          // Coins
        storage.minBidValue,                           // Coins
        storage.startTime,                             // Uint32
        storage.lastBidTime,                           // Uint32
        storage.state == STATE_CANCELLED,              // Int1
        storage.timeIncrement,                         // Uint17
        0,                                             // Uint64
        storage2.jettonWalletAddress,                  // MsgAddressStd
        storage2.jettonMinterAddress,                  // MsgAddressStd
        0,                                             // Uint1
        0                                              // Uint256
    )
}
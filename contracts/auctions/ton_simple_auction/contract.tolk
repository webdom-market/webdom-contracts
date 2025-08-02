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
fun endAuctionSuccess(mutate storage: Storage, storage2: StorageDs2, queryId: uint64, additionalSellerTons: coins) {
    var commission = min(mulDivFloor(storage.lastBidValue, storage.commissionFactor, COMMISSION_DIVIDER), storage2.maxCommission);
    
    createMessage<CommentMessage>({
        bounce: false,
        value: commission,
        dest: MARKETPLACE_ADDRESS,
        body: CommentMessage { comment: "Marketplace commission" }
    }).send(SEND_MODE_REGULAR);
    
    createMessage<cell>({
        bounce: false,
        value: storage.lastBidValue - commission + additionalSellerTons,
        dest: storage.sellerAddress,
        body: getPayoutNotificationBody(storage.domainNameCell)
    }).send(SEND_MODE_REGULAR);
    
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: storage2.domainAddress,
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

@inline
fun endAuctionFailed(mutate storage: Storage, storage2: StorageDs2, queryId: uint64) {
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: storage2.domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.sellerAddress,
            responseAddress: storage.sellerAddress,
            forwardTonAmount: 1,
            forwardPayload: AUCTION_CANCEL_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.state = STATE_CANCELLED;
    storage.endTime = blockchain.now();
    storage.save();
} 


fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);

    var storage = lazy Storage.load();

    val allowAdminCommands = (storage.state != STATE_ACTIVE || storage.endTime + 600 < blockchain.now());
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
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
            }
            return;
        }

        RenewDomainMessage => {
            // var storage = lazy Storage.load();
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: storage.ds2.load().domainAddress,
            }).send(SEND_MODE_PAY_FEES_SEPARATELY);

            createMessage<ExcessesMessage>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: ExcessesMessage { queryId: msg.queryId }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);

            storage.lastDomainRenewalTime = blockchain.now();
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
            var queryId: uint64 = 0;
            var senderAddress = in.senderAddress;
            
            if (in.body.remainingBitsCount() >= 32) {
                op = in.body.loadUint(32);
                if (in.body.remainingBitsCount() >= 64) {
                    queryId = in.body.loadUint(64);
                }
            }
            
            if (op == OP_CANCEL_DEAL || (op == 0 && (in.body.bitsEqual("cancel") || in.body.bitsEqual("stop")))) {
                op = OP_STOP_AUCTION;
            }
            
            if (op == OP_DEDUST_PAYOUT) {
                op = 0;
                senderAddress = in.body as address;
            }
            
            // var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            
            try {
                if (op == 0) {
                    assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                    if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
                        storage.isDeferred = false;
                        storage.endTime = storage.endTime - storage.startTime + blockchain.now();
                        storage.startTime = blockchain.now();
                    } else {
                        assert(blockchain.now() >= storage.startTime && blockchain.now() < storage.endTime) throw EXC_DEAL_NOT_ACTIVE;
                    }
                    
                    var nextMinBidValue = max(
                        max(storage.lastBidValue + TONS_MIN_BID_INCREMENT, storage.minBidValue),
                        mulDivFloor(storage.lastBidValue, storage.minBidIncrement, BID_INCREMENT_DIVIDER)
                    );
                    
                    var userBid = in.valueCoins - TONS_END_TON_AUCTION - TONS_NOTIFY_BIDDER - TONS_MIN_TON_FOR_STORAGE;
                    assert(userBid >= nextMinBidValue) throw EXC_BID_TOO_LOW;
                    
                    if (storage.endTime <= blockchain.now() + storage.timeIncrement) {
                        storage.endTime = blockchain.now() + storage.timeIncrement;
                    }
                    
                    if (blockchain.now() - storage.lastDomainRenewalTime >= ONE_YEAR - max(storage.timeIncrement * 2, ONE_DAY * 7)) {
                        // renew domain if it had not been renewed for a year
                        storage.lastDomainRenewalTime = blockchain.now();
                        createMessage({
                            bounce: false,
                            value: TONS_RENEW_DOMAIN,
                            dest: storage2.domainAddress
                        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                    }
                    
                    val prevTonBalance = contract.getOriginalBalance() - in.valueCoins - storageFees();
                    if (storage.lastBidValue != 0) {
                        createMessage({
                            bounce: false,
                            value: prevTonBalance,
                            dest: storage.lastBidderAddress,
                            body: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("Your bid on webdom.market was outbid by another user. Domain: ")
                                .storeRef(storage.domainNameCell)
                            .endCell()
                        }).send(SEND_MODE_REGULAR);
                    }
                    else if (prevTonBalance > TONS_MIN_EXCESS) {
                        // после первой ставки за обеспечение аукциона отвечает последний участник аукциона, 
                        // поэтому возвращаем продавцу изначально отправленные на контракт тоны
                        createMessage({
                            bounce: true,
                            value: prevTonBalance,
                            dest: storage.sellerAddress,
                            body: ExcessesMessage { queryId: 0 }
                        }).send(SEND_MODE_REGULAR);
                    }
                    
                    storage.lastBidTime = blockchain.now();
                    storage.lastBidderAddress = senderAddress;
                    storage.lastBidValue = userBid;

                    if (userBid >= storage2.maxBidValue) {
                        storage.lastBidValue = storage2.maxBidValue;
                        storage.endTime = blockchain.now();
                        
                        endAuctionSuccess(mutate storage, storage2, queryId, 0);
                        return;
                    } else {
                        createMessage({
                            bounce: false,
                            value: TONS_NOTIFY_BIDDER,
                            dest: senderAddress,
                            body: beginCell()
                                .storeUint(0, 32)
                                .storeStrFloat(userBid, ton("1"))
                                .storeSlice(" TON bid placed successfully")
                            .endCell()
                        }).send(SEND_MODE_REGULAR);
                    }
                    
                    storage.save();
                    return;
                }
                else if (op == OP_STOP_AUCTION) {
                    if (storage.lastBidValue == 0) {  // Cancel auction if it hasn't started yet
                        assert(senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
                        endAuctionFailed(mutate storage, storage2, queryId);
                    } else if (storage.endTime <= blockchain.now()) {  // End auction if it is over
                        var additionalSellerTons: coins;
                        if (senderAddress == storage.sellerAddress) {
                            additionalSellerTons = in.valueCoins;
                        } else {
                            assert(senderAddress == storage.lastBidderAddress) throw EXC_INCORRECT_SENDER;
                            additionalSellerTons = 0;
                        }
                        endAuctionSuccess(mutate storage, storage2, queryId, additionalSellerTons);
                    } else {
                        throw EXC_AUCTION_NOT_ENDED;
                    }
                    return;
                }
                else {
                    throw EXC_UNSUPPORTED_OP;
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
        }
    }
}

fun onExternalMessage(in: InMessage) {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();
    
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
            endAuctionFailed(mutate storage, storage2, queryId);
        } else {  // Auction finished successfully
            endAuctionSuccess(mutate storage, storage2, queryId, 0);
        }
        
        storage.save();
        return;
    }
    
    throw 0xfffe;
}

get fun get_storage_data() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();

    var domainsDict = createEmptyDict();
    domainsDict.sDictSet(267, storage2.domainAddress as slice, BIT_TRUE_SLICE());
    
    return (
        storage.sellerAddress,
        domainsDict,
        1,
        1,
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
        
        storage.domainNameCell,
        storage2.maxCommission,
        
        storage.isDeferred && (blockchain.now() < storage.startTime),
        
        storage.hotUntil,
        storage.coloredUntil,
        
        BURN_ADDRESS,
        contract.getCode().hash()
    );
}

// Legacy methods from https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-auction-v3r3/nft-auction-v3r3.func
get fun get_auction_data() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();
    
    var maxBidValue = storage2.maxBidValue;
    if (maxBidValue == MAX_COINS_VALUE) {
        maxBidValue = 0;
    }
    
    if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
        storage.endTime = blockchain.now() + storage.endTime - storage.startTime;
        storage.startTime = blockchain.now();
    }

    return (
        storage.state != STATE_UNINIT,                 // Int1
        storage.state > STATE_ACTIVE,                  // Int1
        storage.endTime,                               // Uint32
        MARKETPLACE_ADDRESS,                           // MsgAddressStd
        storage2.domainAddress,                        // MsgAddressStd
        storage.sellerAddress,                         // MsgAddressStd
        storage.lastBidValue,                          // Coins
        storage.lastBidderAddress,                     // MsgAddressStd
        (storage.minBidIncrement - 1000) / 10,         // Uint7
        MARKETPLACE_ADDRESS,                           // MsgAddressStd
        storage.commissionFactor, COMMISSION_DIVIDER,  // Uint32, Uint32
        BURN_ADDRESS,                                  // MsgAddressStd
        0, 1,                                          // Uint32, Uint32
        maxBidValue,                                   // Coins
        storage.minBidValue,                           // Coins
        storage.startTime,                             // Uint32
        storage.lastBidTime,                           // Uint32
        storage.state == STATE_CANCELLED,              // Int1
        storage.timeIncrement,                         // Uint17
        0                                              // Uint64
    );
}

get fun get_sale_data() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();
    
    var endTime = storage.endTime;
    if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
        endTime = blockchain.now() + storage.endTime - storage.startTime;
    }

    return (
        0x415543, // nft auction ("AUC")
        storage.state > STATE_ACTIVE,
        endTime,
        MARKETPLACE_ADDRESS,
        storage2.domainAddress,
        storage.sellerAddress,
        storage.lastBidValue,
        storage.lastBidderAddress,
        (storage.minBidIncrement - 1000) / 10,
        MARKETPLACE_ADDRESS,
        storage.commissionFactor, COMMISSION_DIVIDER,
        BURN_ADDRESS,
        0, 1,
        storage2.maxBidValue,
        storage.minBidValue,
        storage.startTime,
        storage.lastBidTime,
        storage.state == STATE_CANCELLED
    );
}

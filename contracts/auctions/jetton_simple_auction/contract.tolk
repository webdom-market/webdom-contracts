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
    var commission: coins = 0;
    if (storage.commissionFactor != 0) {
        commission = min(mulDivFloor(storage.lastBidValue, storage.commissionFactor, COMMISSION_DIVIDER), storage2.maxCommission);
        
        // send marketplace commission
        createMessage<SendJettonsMessage<cell>>({
            bounce: false,
            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
            dest: storage2.jettonWalletAddress,
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
    createMessage<SendJettonsMessage<cell>>({
        bounce: false,
        value: TONS_JETTON_TRANSFER + additionalSellerTons,
        dest: storage2.jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.lastBidValue - commission,
            toAddress: storage.sellerAddress,
            responseAddress: storage.lastBidderAddress,
            forwardTonAmount: additionalSellerTons + 1,
            forwardPayload: getPayoutNotificationBody(storage.domainNameCell)
        }
    }).send(SEND_MODE_REGULAR);
    
    // transfer domain to buyer
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

    val allowAdminCommands = storage.state != STATE_ACTIVE || storage.endTime + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
    });
    
    val msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        DeployAndSetWalletMessage => {
            // var storage = lazy Storage.load();
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                var storage2 = lazy storage.ds2.load();
                storage2.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                storage.ds2 = storage2.toCell();
                storage.save();
            }
            return;
        }
        
        JettonsTransferNotificationMessage<SerializableSlice> => {
            // var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
                        
            var fromAddress = msg.fromAddress;
            // if jettons were received by dedust swap
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                fromAddress = address.fromSlice(msg.forwardPayload.load());
            }
            else if (msg.forwardPayload.remainingBitsCount() == 267) {
                fromAddress = address.fromSlice(msg.forwardPayload);
            }
            
            try {
                assert(in.senderAddress == storage2.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                
                if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
                    storage.isDeferred = false;
                    storage.endTime = storage.endTime - storage.startTime + blockchain.now();
                    storage.startTime = blockchain.now();
                } else {
                    assert(blockchain.now() >= storage.startTime && blockchain.now() < storage.endTime && storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                }
                
                var nextMinBidValue = max(
                    max(storage.lastBidValue, storage.minBidValue),
                    mulDivFloor(storage.lastBidValue, storage.minBidIncrement, BID_INCREMENT_DIVIDER)
                );
                assert(msg.transferredJettons >= nextMinBidValue) throw EXC_BID_TOO_LOW;
                
                if (storage.endTime < blockchain.now() + storage.timeIncrement) {
                    storage.endTime = blockchain.now() + storage.timeIncrement;
                }
                
                var requiredGas = TONS_END_JETTON_AUCTION + TONS_MIN_TON_FOR_STORAGE;

                if (blockchain.now() - storage.lastDomainRenewalTime >= ONE_YEAR - max(storage.timeIncrement * 2, ONE_DAY * 7)) {
                    // renew domain if it had not been renewed for a year
                    storage.lastDomainRenewalTime = blockchain.now();
                    createMessage({
                        bounce: false,
                        value: TONS_RENEW_DOMAIN,
                        dest: storage2.domainAddress
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                    requiredGas += TONS_RENEW_DOMAIN;
                }
                
                val prevTonBalance = contract.getOriginalBalance() - in.valueCoins - storageFees();
                if (storage.lastBidValue != 0) {
                    // return the previous bid
                    createMessage<SendJettonsMessage<cell>>({
                        bounce: false,
                        value: prevTonBalance,
                        dest: storage2.jettonWalletAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.lastBidValue,
                            toAddress: storage.lastBidderAddress,
                            responseAddress: storage.lastBidderAddress,
                            forwardTonAmount: 1,
                            forwardPayload: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("Your bid on webdom.market was outbid by another user. Domain: ")
                                .storeRef(storage.domainNameCell)
                            .endCell()
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
                        createMessage<SendJettonsMessage<cell>>({
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
                        requiredGas += TONS_JETTON_TRANSFER;
                    }
                    
                    storage.lastBidValue = storage2.maxBidValue;
                    storage.endTime = blockchain.now();
                    
                    endAuctionSuccess(mutate storage, storage2, msg.queryId, 0);
                } else {
                    storage.lastBidValue = msg.transferredJettons;
                    reserveToncoinsOnBalance(TONS_END_JETTON_AUCTION + TONS_MIN_TON_FOR_STORAGE, RESERVE_MODE_EXACT_AMOUNT);

                    createMessage<CommentMessage>({
                        bounce: false,
                        value: 0,
                        dest: fromAddress,
                        body: CommentMessage { comment: "Bid placed successfully" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                
                assert(in.valueCoins >= requiredGas) throw EXC_OUT_OF_GAS;
                storage.save();
                var tmp = Storage.load();
                return;
                
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
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
            var (op, queryId) = loadOpAndQueryId(mutate in.body);
            var senderAddress = in.senderAddress;
            // var storage = lazy Storage.load();
            var storage2 = lazy storage.ds2.load();
            
            try {
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                
                if (op == OP_STOP_AUCTION || op == OP_CANCEL_DEAL) {
                    if (storage.lastBidValue == 0) {  // Cancel auction if it hasn't started yet
                        assert(senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
                        endAuctionFailed(mutate storage, storage2, queryId);
                    } else if (storage.endTime <= blockchain.now()) {  // End auction if it is over
                        var additionalSellerTons: coins;
                        if (senderAddress == storage.lastBidderAddress) {
                            additionalSellerTons = 0;
                        } else {
                            assert(senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
                            additionalSellerTons = in.valueCoins;
                        }
                        endAuctionSuccess(mutate storage, storage2, queryId, additionalSellerTons);
                    } else {
                        throw EXC_AUCTION_NOT_ENDED;
                    }
                    return;
                } else {
                    throw EXC_UNSUPPORTED_OP;
                }
            } catch (e, _) {
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: senderAddress,
                    body: beginCell().storeUint(0, 32).storeSlice("Error, code ").storeNumber10(e).endCell()
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
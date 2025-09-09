import "@stdlib/tvm-dicts";
import "../../imports/constants";
import "../../imports/messages";
import "../../imports/utils";
import "storage";
import "messages";
import "@stdlib/gas-payments";
import "../../imports/handle_promotion";
import "../../imports/admin_message";
import "../messages";
import "../constants";
import "../../fix_price_sales/constants"


const TONS_MIN_TON_FOR_STORAGE: coins = ton("0.035");  // TON reserve to pay storage fees for ~1 year


// Finish auction: send marketplace commission, seller payout and transfer all domains to the winner. Last bidder pays all blockchain fees for this operation. 
@inline
fun endAuctionSuccess(mutate storage: Storage, maxCommission: int, queryId: uint64, additionalSellerTons: coins) {
    var commission = min(mulDivFloor(storage.lastBidValue, storage.commissionFactor, COMMISSION_DIVIDER), maxCommission);
    
    // Send marketplace commission
    createMessage<CommentMessage>({
        bounce: false,
        value: commission,
        dest: MARKETPLACE_ADDRESS,
        body: CommentMessage { comment: "Marketplace commission" }
    }).send(SEND_MODE_REGULAR);
    
    // Send seller payout
    createMessage<CommentMessage>({
        bounce: false,
        value: storage.lastBidValue - commission + additionalSellerTons,
        dest: storage.sellerAddress,
        body: CommentMessage { comment: "Payout for multiple domains auction on webdom.market" }
    }).send(SEND_MODE_REGULAR);

    // Transfer domains
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
    
    // Last domain transfer with remaining balance
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

    // Update auction state
    storage.state = STATE_COMPLETED;
    storage.save();
}


// Cancel auction and return all received domains back to the seller if there were no bids
@inline
fun endAuctionFailed(mutate storage: Storage, queryId: uint64, cancelReason: slice) {
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

    // Notify seller and send remaining balance
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.sellerAddress,
        body: CommentMessage { comment: cancelReason }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    // Update auction state
    storage.state = STATE_CANCELLED;
    storage.endTime = blockchain.now();
    storage.save();
}


// Forward all bounced messages to the seller
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


fun getBalanceToReserve(auctionStarted: bool, domainsNumber: uint8): coins {
    if (auctionStarted) {
        return TONS_TON_SIMPLE_PURCHASE * domainsNumber + TONS_MIN_TON_FOR_STORAGE;  // TONs to finalize auction and pay storage fees
    } 
    val balanceToReserve: coins = (TONS_NFT_TRANSFER + ton("0.0075")) * domainsNumber + TONS_MIN_TON_FOR_STORAGE;  // TONs to allow canceling auction by external message
    if (contract.getOriginalBalance() - ton("0.01") < balanceToReserve) {
        return TONS_MIN_TON_FOR_STORAGE;
    }
    return balanceToReserve;
}


fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    var storage = lazy Storage.load();
    
    // Handle admin messages for contract management
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.endTime < blockchain.now() + 600;
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawJetton: true,
    });
    
    val msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Activate the auction when deployed by marketplace
        FillUpBalanceMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                storage.state = STATE_ACTIVE;
                storage.save();
            }
            return;
        }
        
        // Seller sends domain to the auction contract
        NftOwnershipAssignedMessage => {
            try {
                var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
                assert(found) throw EXC_INCORRECT_DOMAIN;
                
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                storage.domainsReceived += 1;

                // If all domains were received, activate the auction and notify seller
                if (storage.domainsReceived == storage.domainsTotal) { 
                    val balanceToReserve: coins = getBalanceToReserve(false, storage.domainsTotal);
                    reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
                    
                    // Notify seller that auction is ready
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
        
        // Renew all domains and extend auction validity if needed
        RenewDomainMessage => {
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN * storage.domainsTotal) throw EXC_OUT_OF_GAS;
            assert(storage.lastDomainRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;

            // Reserve required TONs depending on the auction state
            val balanceToReserve: coins = storage.lastBidValue + getBalanceToReserve(storage.lastBidValue > 0, storage.domainsTotal);
            reserveToncoinsOnBalance(balanceToReserve, RESERVE_MODE_EXACT_AMOUNT);
            
            // Renew all domains
            var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
            while (found) {
                createMessage({
                    bounce: false,
                    value: TONS_RENEW_DOMAIN,
                    dest: domainAddress! as address
                }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
            }
            
            // Send renewal fee to the marketplace
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

        // Handle hot promotion
        MakeHotMessage => {
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        // Handle colored promotion
        MakeColoredMessage => {
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        
        // Ignore excess
        ExcessesMessage => {
            return;
        }

        else => {
            var senderAddress: address = in.senderAddress;
            var (op: uint32, queryId: uint64) = loadOpAndQueryId(mutate in.body);
            
            // Handle DeDust payout (extract real sender from payload)
            if (op == OP_DEDUST_PAYOUT) {
                op = 0;
                senderAddress = in.body.loadMaybeRef()!.beginParse() as address;
            }

            // Place a bid (TON payment)
            if (op == 0) {
                try {
                    // Start auction if it was deferred, otherwise ensure it is active
                    if (storage.isDeferred && (blockchain.now() < storage.startTime)) {
                        storage.endTime = blockchain.now() + storage.endTime - storage.startTime;
                        storage.startTime = blockchain.now();
                        storage.isDeferred = false;
                    }
                    else {
                        assert((blockchain.now() >= storage.startTime) && (blockchain.now() < storage.endTime) && (storage.domainsReceived == storage.domainsTotal)) throw EXC_DEAL_NOT_ACTIVE;
                    }
                    
                    // Calculate bidder's net value after reserving TON for notifications and storage
                    val tonsToReserve: coins = getBalanceToReserve(true, storage.domainsTotal);
                    var bidValue: coins = in.valueCoins - tonsToReserve - TONS_NOTIFY_BIDDER;

                    // Calculate minimal bid considering absolute and relative increments
                    var nextMinBidValue = max(
                        max(storage.lastBidValue + ton("0.1"), storage.minBidValue),
                        mulDivFloor(storage.lastBidValue, storage.minBidIncrement, BID_INCREMENT_DIVIDER)
                    );
                    assert(bidValue >= nextMinBidValue) throw EXC_BID_TOO_LOW;
                    
                    // Extend auction end time if close to finish (bounded by domain expiration)
                    if (storage.endTime <= blockchain.now() + storage.timeIncrement) {
                        storage.endTime = min(blockchain.now() + storage.timeIncrement, storage.lastDomainRenewalTime + ONE_YEAR);
                    }

                    // Refund previous bidder or return seller's initial reserve before first bid
                    val prevTonBalance = contract.getOriginalBalance() - in.valueCoins - storageFees();
                    if (storage.lastBidValue != 0) {
                        // Return the previous bid
                        createMessage({
                            bounce: false,
                            value: prevTonBalance,
                            dest: storage.lastBidderAddress,
                            body: OUTBID_NOTIFICATION()
                        }).send(SEND_MODE_REGULAR);
                    }
                    else if (prevTonBalance > TONS_MIN_EXCESS) {
                        // After the first bid, the last bidder maintains the auction's TON reserve, so we return seller's initial reserve
                        createMessage({
                            bounce: true,
                            value: prevTonBalance,
                            dest: storage.sellerAddress,
                            body: ExcessesMessage { queryId: 0 }
                        }).send(SEND_MODE_REGULAR);
                    }

                    storage.lastBidTime = blockchain.now();
                    storage.lastBidderAddress = senderAddress;
                    
                    val storage2: StorageDs2 = lazy storage.ds2.load();
                    if (bidValue >= storage2.maxBidValue) {  
                        // Finish auction if reaching maxBidValue
                        storage.lastBidValue = storage2.maxBidValue;
                        storage.endTime = blockchain.now();

                        endAuctionSuccess(mutate storage, storage2.maxCommission, queryId, 0);
                        return;
                    } else {
                        // Notify bidder about accepted bid
                        createMessage({
                            bounce: false,
                            value: TONS_NOTIFY_BIDDER,
                            dest: senderAddress,
                            body: CommentMessage { comment: "Bid placed successfully" }
                        }).send(SEND_MODE_REGULAR);
                    }
                    
                    storage.lastBidValue = bidValue;
                    storage.save();
                    return;
                    
                } catch (e, _) {
                    // Send error notification (can't just bounce in case of DeDust swaps)
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: senderAddress,
                        body: CommentMessage { 
                            comment: beginCell()
                                .storeSlice("Error. Code ")
                                .storeNumber10(e)
                            .endCell().beginParse()
                        }
                    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                    
                    commitContractDataAndActions();
                    throw e;
                }
            }

            if (op == OP_STOP_AUCTION || op == OP_CANCEL_DEAL) {
                if (storage.lastBidValue == 0) {  // Cancel auction if it hasn't started yet
                    assert(senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
                    endAuctionFailed(mutate storage, queryId, "Multiple auction on webdom.market was cancelled");
                    return;
                } else if (storage.endTime <= blockchain.now()) {  // End auction if it is over
                    var additionalSellerTons: coins;
                    if (senderAddress == storage.sellerAddress) {
                        additionalSellerTons = in.valueCoins;  // Seller doesn't pay gas fees for finalizing the auction
                    } else {
                        assert(senderAddress == storage.lastBidderAddress) throw EXC_INCORRECT_SENDER;
                        additionalSellerTons = 0;
                    }
                    val storage2 = lazy storage.ds2.load();
                    endAuctionSuccess(mutate storage, storage2.maxCommission, queryId, additionalSellerTons);
                    return;
                } else {
                    throw EXC_AUCTION_NOT_ENDED;
                }
            }
            
            throw EXC_UNSUPPORTED_OP;
        }
    }
}


// Allow anyone to finalize ended auctions via external message
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
        var queryId = in.body.loadUint(64);
          
        if (storage.lastBidValue == 0) {  // No one participated in the auction
            assert(contract.getOriginalBalance() >= (TONS_NFT_TRANSFER + ton("0.0075")) * storage.domainsReceived) throw EXC_OUT_OF_GAS;
            acceptExternalMessage();
            endAuctionFailed(mutate storage, queryId, "Multiple auction on webdom.market was cancelled");
        } else {  // Auction finished successfully
            acceptExternalMessage();
            val storage2 = lazy storage.ds2.load();
            endAuctionSuccess(mutate storage, storage2.maxCommission, queryId, 0);
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
        storage.isDeferred && (blockchain.now() < storage.startTime),

        storage.hotUntil,
        storage.coloredUntil,
        BURN_ADDRESS,  // jettonMinterAddress (not used in TON auction)
        contract.getCode().hash()
    );
}


get fun get_auction_data_v4() {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();

    var (domainAddress, _, _) = storage.domainsDict.sDictGetFirst(267);
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
        null,                                          // MsgAddressStd
        null,                                          // MsgAddressStd
        0,                                             // Uint1
        0                                              // Uint256
    )
}
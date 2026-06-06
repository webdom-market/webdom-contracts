import "../../imports/gas";
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


// Auction's own storage reserve is computed in ../constants — see simpleAuctionStorageReserve()


// Finish auction if there was at least one bid
@inline
fun endAuctionSuccess(mutate storage: Storage, storage2: StorageDs2, queryId: uint64, additionalSellerTons: coins) {
    val lastBidderAddr: address = storage.lastBidderAddress!;
    val jettonWalletAddr: address = storage2.jettonWalletAddress!;
    var commission: coins = 0;
    if (storage.commissionFactor != 0) {
        commission = min(mulDivFloor(storage.lastBidValue, storage.commissionFactor, COMMISSION_DIVIDER), storage2.maxCommission);
        
        // Send marketplace commission
        createMessage<SendJettonsMessage<cell>>({
            bounce: false,
            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
            dest: jettonWalletAddr,
            body: SendJettonsMessage<cell> {
                queryId: queryId,
                jettonAmount: commission,
                toAddress: MARKETPLACE_ADDRESS,
                responseAddress: lastBidderAddr,
                forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    }
    
    // Send seller payout
    createMessage<SendJettonsMessage<cell>>({
        bounce: false,
        value: TONS_JETTON_TRANSFER + additionalSellerTons,
        dest: jettonWalletAddr,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.lastBidValue - commission,
            toAddress: storage.sellerAddress,
            responseAddress: lastBidderAddr,
            forwardTonAmount: additionalSellerTons + 1,
            forwardPayload: getPayoutNotificationBody(storage.domainNameCell)
        }
    }).send(SEND_MODE_REGULAR);
    
    // Transfer domain to buyer & send excess
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: storage2.domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: lastBidderAddr,
            responseAddress: lastBidderAddr,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
    
    // Update auction state
    storage.state = STATE_COMPLETED;
    storage.save();
}

// Cancel auction if there was no bids
@inline
fun endAuctionFailed(mutate storage: Storage, storage2: StorageDs2, queryId: uint64) {
    // Return NFT to the seller
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

    // Update auction state
    storage.state = STATE_CANCELLED;
    storage.endTime = blockchain.now();
    storage.save();
}


fun onBouncedMessage(in: InMessageBounced): void {
    // Forward all bounced messages to the seller
    if (in.valueCoins > TONS_MIN_EXCESS) {
        var storage: Storage = lazy Storage.load();
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

    // Handle admin messages for contract management
    val allowAdminCommands = storage.state != STATE_ACTIVE || storage.endTime + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
    });
    
    var msg = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Activate the auction when deployed by marketplace
        DeployAndSetWalletMessage => {
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
        
        // Handle jetton bid (including DeDust swap payouts)
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var storage2 = lazy storage.ds2.load();
                        
            var fromAddress = msg.fromAddress;
            // If jettons were received by DeDust swap, extract real sender from payload
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                msg.forwardPayload = msg.forwardPayload.load();
            }
            if (msg.forwardPayload.remainingBitsCount() == 267) {
                fromAddress = address.fromSlice(msg.forwardPayload);
            }
            
            try {
                assert(storage2.jettonWalletAddress != null && in.senderAddress == storage2.jettonWalletAddress!) throw EXC_INCORRECT_SENDER;  // check that jettons were received from the correct wallet
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                val jettonWalletAddr: address = storage2.jettonWalletAddress!;

                if (storage.isDeferred && (blockchain.now() < storage.startTime)) {  // start auction if it was deferred
                    storage.isDeferred = false;
                    storage.endTime = storage.endTime - storage.startTime + blockchain.now();
                    storage.startTime = blockchain.now();
                } else {  // otherwise, check if auction is active
                    assert(blockchain.now() >= storage.startTime && blockchain.now() < storage.endTime) throw EXC_DEAL_NOT_ACTIVE;
                }
                
                // Calculate minimal bid considering absolute and relative increments
                var nextMinBidValue = max(
                    max(storage.lastBidValue, storage.minBidValue),
                    mulDivFloor(storage.lastBidValue, storage.minBidIncrement, BID_INCREMENT_DIVIDER)
                );
                assert(msg.transferredJettons >= nextMinBidValue) throw EXC_BID_TOO_LOW;
                
                // Extend auction end time if close to finish
                if (storage.endTime < blockchain.now() + storage.timeIncrement) {
                    storage.endTime = blockchain.now() + storage.timeIncrement;
                }
                
                var requiredGas = TONS_END_JETTON_AUCTION() + simpleAuctionStorageReserve() + gasFee(GAS_AUCTION_BID_PROCESSING);  // TONs needed to end auction and pay storage

                if (blockchain.now() - storage.lastDomainRenewalTime >= ONE_YEAR - max(storage.timeIncrement * 2, ONE_DAY * 7)) {
                    // Renew domain if it had not been renewed for a year
                    storage.lastDomainRenewalTime = blockchain.now();
                    val renewFee = renewDomainFee();
                    createMessage({
                        bounce: false,
                        value: renewFee,
                        dest: storage2.domainAddress
                    }).send(SEND_MODE_REGULAR);
                    requiredGas += renewFee;
                }
                
                val prevTonBalance = contract.getOriginalBalance() - in.valueCoins;
                if (storage.lastBidValue != 0) {
                    // Return jettons to the previous bidder
                    createMessage<SendJettonsMessage<cell>>({
                        bounce: false,
                        value: prevTonBalance,
                        dest: jettonWalletAddr,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.lastBidValue,
                            toAddress: storage.lastBidderAddress!,
                            responseAddress: storage.lastBidderAddress!,
                            forwardTonAmount: 1,
                            forwardPayload: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("Your bid on webdom.market was outbid by another user. Domain: ".literalSlice())
                                .storeRef(storage.domainNameCell)
                            .endCell()
                        }
                    }).send(SEND_MODE_REGULAR);
                }
                else if (prevTonBalance > TONS_MIN_EXCESS) {
                    // After the first bid, the last bidder maintains the auction's TON reserve, so we return seller's initial reserve
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
                    // Finish auction if reaching maxBidValue; return jetton excess if any
                    if (msg.transferredJettons > storage2.maxBidValue) {                        
                        createMessage<SendJettonsMessage<cell>>({
                            bounce: false,
                            value: TONS_JETTON_TRANSFER,
                            dest: jettonWalletAddr,
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
                    // Reserve TONs to safely finalize the auction and pay storage fees
                    reserveToncoinsOnBalance(TONS_END_JETTON_AUCTION() + simpleAuctionStorageReserve(), RESERVE_MODE_EXACT_AMOUNT);

                    createMessage<CommentMessage>({
                        bounce: false,
                        value: 0,
                        dest: fromAddress,
                        body: CommentMessage { comment: "Bid placed successfully".literalSlice() }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                
                assert(in.valueCoins >= requiredGas) throw EXC_OUT_OF_GAS;
                storage.save();
                return;
                
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
        }
        
        // Handle domain renewal request
        RenewDomainMessage => {
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            assert(storage.lastDomainRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;
            val renewFee = renewDomainFee();
            assert(in.valueCoins >= renewFee) throw EXC_OUT_OF_GAS;

            // Reserve the contract's own balance, fund the renewal from the incoming value
            // (pre-bid the contract holds only its deploy reserve, which is < renewDomainFee()).
            reserveToncoinsOnBalance(contract.getOriginalBalance() - in.valueCoins, RESERVE_MODE_EXACT_AMOUNT);

            // Send renewal transaction to domain contract
            createMessage({
                bounce: false,
                value: renewFee,
                dest: storage.ds2.load().domainAddress,
            }).send(SEND_MODE_REGULAR);

            // Domain renewal makes no sense for auction, so we do not send marketplace fee
            if (in.valueCoins > renewFee + TONS_MIN_EXCESS) { 
                createMessage<ExcessesMessage>({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: ExcessesMessage { queryId: msg.queryId }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }
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
            var (op, queryId) = loadOpAndQueryId(mutate in.body);
            var senderAddress = in.senderAddress;
            var storage2 = lazy storage.ds2.load();
            
            try {
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // check that auction is active
                
                if (op == OP_STOP_AUCTION || op == OP_CANCEL_DEAL) {
                    if (storage.lastBidValue == 0) {  // Cancel auction if it hasn't started yet
                        assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                        endAuctionFailed(mutate storage, storage2, queryId);
                    } else if (storage.endTime <= blockchain.now()) {  // End auction if it is over
                        var additionalSellerTons: coins;
                        if (storage.lastBidderAddress != null && senderAddress == storage.lastBidderAddress!) {
                            additionalSellerTons = 0;
                        } else {
                            assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
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
                // Send error notification (can't just bounce in case of DeDust swaps)
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: senderAddress,
                    body: beginCell().storeUint(0, 32).storeSlice("Error, code ".literalSlice()).storeNumber10(e).endCell()
                }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                
                commitContractDataAndActions();

                throw e;
            }
        }
    }
}


// Allow anyone to finalize ended auctions via external message
fun onExternalMessage(inMsg: slice) {
    var storage = lazy Storage.load();
    var storage2 = lazy storage.ds2.load();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }
    
    if (blockchain.now() >= storage.endTime) {
        var opCode = inMsg.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        var queryId = inMsg.loadUint(64);
        
        acceptExternalMessage();
        
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
        storage.lastBidderAddress == null ? (createAddressNone() as address) : storage.lastBidderAddress!,
        
        storage.minBidValue,
        storage.minBidIncrement,
        storage.timeIncrement,
        
        storage.lastBidValue,
        storage.lastBidTime,
        
        storage.domainNameCell,
        null,  // legacy

        storage2.maxCommission,

        storage2.jettonWalletAddress == null ? (createAddressNone() as address) : storage2.jettonWalletAddress!,
        
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
        storage.lastBidderAddress == null ? (createAddressNone() as address) : storage.lastBidderAddress!,  // MsgAddressStd
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
        storage2.jettonWalletAddress == null ? (createAddressNone() as address) : storage2.jettonWalletAddress!,  // MsgAddressStd
        storage2.jettonMinterAddress,                  // MsgAddressStd
        0,                                             // Uint1
        0                                              // Uint256
    )
}
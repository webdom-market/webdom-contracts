import "@stdlib/tvm-dicts"
import "@stdlib/gas-payments"
import "../../imports/constants"
import "../../imports/messages"
import "../../imports/utils"
import "../../imports/types"
import "../../imports/handle_promotion"
import "../../imports/admin_message"
import "../constants"
import "../messages"
import "storage"
import "messages"
import "constants"


// Cancel the multiple sale and return all received domains back to the seller
@inline
fun cancelSale(mutate storage: Storage, queryId: uint64, cancelReason: slice) {
    setGasLimitToMaximum();

    storage.state = STATE_CANCELLED;
    storage.validUntil = blockchain.now();
    storage.save();
    commitContractDataAndActions();

    var (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetFirst(267);
    while (found) {
        if (domainReceived!.bitsEqual(BIT_TRUE_SLICE())) {
            // Return NFT back to seller
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
            }).send(SEND_MODE_REGULAR | SEND_MODE_IGNORE_ERRORS);
        }
        (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
    }
    // Notify seller and send remaining balance
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.sellerAddress,
        body: CommentMessage { comment: cancelReason }
    }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);
}

// Forward bounced funds back to the seller as excesses
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
fun getTonsToReserve(domainsTotal: uint8, autoRenewIterations: uint8, nothrow: bool): int {
    val tonsForAutoCancel = ((TONS_NFT_TRANSFER + ton("0.0075")) * domainsTotal + TONS_STORAGE_PER_YEAR) as coins;  // Balance required to cancel the sale via external message
    val tonsForAutoRenew = (getAutoRenewLockPerIter(domainsTotal) * autoRenewIterations) as coins;
    val tonsToReserve = tonsForAutoCancel + tonsForAutoRenew;
    var actualBalance = contract.getOriginalBalance() - ton("0.01") - storageFees();
    assert(actualBalance >= tonsToReserve || nothrow) throw EXC_OUT_OF_GAS;
    return tonsToReserve as int;
}

fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    var storage: Storage = lazy Storage.load();
    var autoRenewData: AutoRenewData = lazy storage.autoRenewData.load();

    // Allow admin operations when sale is not active or expired
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.validUntil + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
        allowWithdrawJetton: true,
    });
    
    val msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Activate the sale when deployed by the marketplace
        FillUpBalanceMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                if (autoRenewData.autoRenewIterations > 0) {
                    createMessage<AutoRenewPrepayMessage>({
                        bounce: false,
                        value: autoRenewData.autoRenewIterations * TONS_AUTORENEW_MARKETPLACE_FEE,
                        dest: MARKETPLACE_ADDRESS,
                        body: AutoRenewPrepayMessage {
                            queryId: msg.queryId,
                            ownerAddress: storage.sellerAddress,
                            iterations: autoRenewData.autoRenewIterations
                        }
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                }
                storage.state = STATE_ACTIVE;
                storage.save();
            }
            return;
        }
        
        // Seller transfers domain to this contract
        NftOwnershipAssignedMessage<SerializableSlice> => {
            try {
                // Check that domain present in the storage
                var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
                assert(found) throw EXC_INCORRECT_DOMAIN;

                // Mark domain as received
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                storage.domainsReceived += 1;

                // If all domains were received, reserve required TONs and send excess to seller
                if (storage.domainsReceived == storage.domainsTotal) {
                    reserveToncoinsOnBalance(getTonsToReserve(storage.domainsTotal, autoRenewData.autoRenewIterations, false), RESERVE_MODE_EXACT_AMOUNT);

                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Multiple sale on webdom.market is active" }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.save();
                return;
            } catch (e, _) {  // If error occurs, return NFT back to seller
                returnNftToSender(in.senderAddress, msg, e);
            }
        }
        // Change price and validity period
        ChangePriceMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;  // Check that message sender is the seller
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            
            // Check that new validUntil time is greater than current time and less than domain expiration time
            assert((msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) && 
                   (msg.newValidUntil <= storage.lastRenewalTime + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;

            var newCommission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            storage.validUntil = msg.newValidUntil;
            storage.price = msg.newPrice;
            storage.commission = newCommission;
            storage.save();
            
            // Notify seller about successful price change
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
        
        // Renew all domains and extend sale validity
        RenewDomainMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;  // Check that message sender is the seller
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN * storage.domainsTotal) throw EXC_OUT_OF_GAS;  // Check that enough TONs are sent
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // Check that domain is not expired

            // Reserve TONs required for storage
            reserveToncoinsOnBalance(max(getTonsToReserve(storage.domainsTotal, autoRenewData.autoRenewIterations, false), contract.getOriginalBalance() - in.valueCoins - ton("0.007")), RESERVE_MODE_EXACT_AMOUNT);
            
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
            
            // Send renewal fee to marketplace
            createMessage({
                bounce: false,
                value: 0,
                dest: MARKETPLACE_ADDRESS,
                body: RenewalFeeMessage { queryId: msg.queryId, ownerAddress: storage.sellerAddress }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);

            // Calculate new validity period
            var newValidUntil: uint32;
            if (msg.newValidUntil != null) {
                newValidUntil = max(msg.newValidUntil, storage.validUntil);
            } else {
                newValidUntil = max(blockchain.now() + ONE_YEAR - ONE_DAY, storage.validUntil);
            }
            
            storage.validUntil = newValidUntil;
            storage.lastRenewalTime = blockchain.now();
            storage.save();
            return;
        }

        // Update auto-renew settings and paid iterations
        SetAutoRenewParamsMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert((msg.autoRenewCooldown >= ONE_DAY) && (msg.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            assert(msg.autoRenewIterations >= autoRenewData.autoRenewIterations) throw EXC_INCORRECT_VALID_UNTIL;

            val addIterations: uint8 = msg.autoRenewIterations - autoRenewData.autoRenewIterations;
            if (addIterations > 0) {
                val topUpReserve: coins = (getAutoRenewLockPerIter(storage.domainsTotal) + TONS_AUTORENEW_MARKETPLACE_FEE) * addIterations;
                assert(in.valueCoins >= topUpReserve + TONS_AUTORENEW_TOPUP_GAS_BUFFER) throw EXC_OUT_OF_GAS;
            }

            if (msg.newValidUntil != null) {
                assert(msg.newValidUntil! >= max(blockchain.now() + 600, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
                storage.validUntil = msg.newValidUntil!;
            }
            else {
                storage.validUntil = max(storage.validUntil, storage.lastRenewalTime + msg.autoRenewCooldown * msg.autoRenewIterations + ONE_YEAR - ONE_DAY);
            }

            autoRenewData.autoRenewCooldown = msg.autoRenewCooldown;
            autoRenewData.autoRenewIterations = msg.autoRenewIterations;
            storage.autoRenewData = autoRenewData.toCell();
            storage.save();

            reserveToncoinsOnBalance(getTonsToReserve(storage.domainsTotal, autoRenewData.autoRenewIterations, false), RESERVE_MODE_EXACT_AMOUNT);

            if (addIterations > 0) {
                createMessage<AutoRenewPrepayMessage>({
                    bounce: false,
                    value: 0,
                    dest: MARKETPLACE_ADDRESS,
                    body: AutoRenewPrepayMessage {
                        queryId: msg.queryId,
                        ownerAddress: storage.sellerAddress,
                        iterations: addIterations
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }
            else {
                createMessage<ExcessesMessage>({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: ExcessesMessage { queryId: msg.queryId }
                }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);
            }

            return;
        }
        
        // Handle domain expiration notification
        DnsBalanceReleaseMessage => {
            // Check that domain present in the storage
            var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
            assert(found) throw EXC_INCORRECT_DOMAIN;
            
            // Cancel sale if it is not cancelled yet
            if (storage.state != STATE_CANCELLED) {
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_FALSE_SLICE());  // Mark domain as not received
                cancelSale(mutate storage, 0, "Your domain has expired");
            }
            
            return;
        }

        // Add "hot" promotion
        MakeHotMessage => {
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        // Add "colored" promotion
        MakeColoredMessage => {
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        
        ExcessesMessage => {
            return;
        }

        else => {
            var (op, queryId) = loadOpAndQueryId(mutate in.body);
            var senderAddress = in.senderAddress;
            
            if (op == OP_DEDUST_PAYOUT || op == OP_BIDASK_PAYOUT) {  // If dedust payout, extract sender address from the message
                op = 0;
                senderAddress = in.body.loadRef()!.beginParse() as address;
            }
            
            try {
                assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
                
                if (op == 0) {
                    val nowTs: uint32 = blockchain.now();
                    assert((storage.domainsReceived == storage.domainsTotal) && (storage.validUntil > nowTs)) throw EXC_DEAL_NOT_ACTIVE;  // Check that all domains were received and sale is not expired
                    assert(storage.lastRenewalTime > nowTs - (ONE_YEAR - ONE_DAY)) throw EXC_DOMAIN_EXPIRED;
                    assert(in.valueCoins >= storage.price + TONS_TON_SIMPLE_PURCHASE * storage.domainsTotal) throw EXC_OUT_OF_GAS;

                    // Send marketplace commission
                    createMessage({
                        bounce: false,
                        value: storage.commission,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);

                    // Send all domains to buyer
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

                    // Send unused TONs to seller
                    createMessage({
                        bounce: false,
                        value: (contract.getOriginalBalance() - in.valueCoins) + storage.price - storage.commission,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Payout for multiple domains sale on webdom.market" }
                    }).send(SEND_MODE_REGULAR);

                    // Send excess TONs to buyer
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: senderAddress,
                        body: ExcessesMessage { queryId: queryId }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);

                    // Set sale state to completed
                    storage.state = STATE_COMPLETED;
                    storage.validUntil = blockchain.now();
                    storage.buyerAddress = senderAddress;
                    storage.save();
                    return;
                }
                else if (op == OP_CANCEL_DEAL) {
                    assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;  // Check that message sender is the seller or admin
                    cancelSale(mutate storage, queryId, "Sale cancelled");  // Cancel sale
                    return;
                }
                else {
                    throw EXC_UNSUPPORTED_OP;
                }
            } catch (e, _) {  // If error occurs, return TONs to sender (we can't just bounce in case of dedust payout)
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

fun onExternalMessage(in: InMessage): void {
    var storage: Storage = lazy Storage.load();
    var autoRenewData: AutoRenewData = lazy storage.autoRenewData.load();
    var nowTs: uint32 = blockchain.now();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }

    var (opCode, queryId) = loadOpAndQueryId(mutate in.body);
    if (opCode == OP_CANCEL_DEAL) {
        // Allow anyone to cancel expired sales
        assert(nowTs >= storage.validUntil || storage.lastRenewalTime < nowTs - ONE_YEAR + ONE_DAY) throw 0xfffe;
        assert(contract.getOriginalBalance() >= (TONS_NFT_TRANSFER + ton("0.0075")) * storage.domainsReceived) throw EXC_OUT_OF_GAS;
        acceptExternalMessage();
        
        cancelSale(mutate storage, queryId, "Your sale offer has expired");
        return;
    }

    if (opCode == OP_TRIGGER_AUTORENEW) {
        assert(autoRenewData.autoRenewIterations > 0) throw EXC_UNSUPPORTED_OP;
        assert(storage.domainsReceived == storage.domainsTotal) throw EXC_DEAL_NOT_ACTIVE;
        assert(nowTs < storage.validUntil) throw EXC_DEAL_NOT_ACTIVE;
        assert(storage.lastRenewalTime <= nowTs - autoRenewData.autoRenewCooldown) throw 0xfffe;

        acceptExternalMessage();
        val gasToReserve: coins = getTonsToReserve(storage.domainsTotal, autoRenewData.autoRenewIterations - 1, false);
        val renewCost: coins = TONS_RENEW_DOMAIN * storage.domainsTotal;
        if (contract.getOriginalBalance() < gasToReserve + renewCost || storage.lastRenewalTime <= nowTs - (ONE_YEAR - ONE_HOUR)) {
            cancelSale(mutate storage, queryId, "Your sale offer has expired");
            return;
        }

        storage.lastRenewalTime = nowTs;
        autoRenewData.autoRenewIterations -= 1;
        storage.autoRenewData = autoRenewData.toCell();
        storage.save();

        var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
        while (found) {
            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: domainAddress! as address
            }).send(SEND_MODE_PAY_FEES_SEPARATELY);
            (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
        }
        return;
    }
    
    throw EXC_UNSUPPORTED_OP;
}

get fun get_storage_data() {
    var storage = Storage.load();
    var autoRenewData: AutoRenewData = lazy storage.autoRenewData.load();
    
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
        getTonsToReserve(storage.domainsTotal, autoRenewData.autoRenewIterations, true),
        autoRenewData.autoRenewCooldown,
        autoRenewData.autoRenewIterations,
        storage.hotUntil,
        storage.coloredUntil,
        BURN_ADDRESS,
        contract.getCode().hash()
    );
} 

get fun get_fix_price_data_v4() {
    var storage = lazy Storage.load();
    var (domainAddress, _, _) = storage.domainsDict.sDictGetFirst(267);

    return (
        storage.state > STATE_ACTIVE,
        storage.createdAt,
        MARKETPLACE_ADDRESS,
        domainAddress,
        storage.sellerAddress,
        storage.price,
        MARKETPLACE_ADDRESS,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER * 10, storage.price),
        BURN_ADDRESS,
        0,
        ((storage.validUntil > blockchain.now()) | (storage.state != STATE_COMPLETED)) ? (0 as uint32) : storage.validUntil,
        0,
        null
    );
}

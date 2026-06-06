import "../../imports/gas";
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

// Cancel the sale, returning every received domain to the seller, then notify and carry the
// remaining balance to them.
@inline
fun cancelSale(mutate storage: Storage, queryId: uint64, cancelReason: slice) {
    setGasLimitToMaximum();
    
    storage.state = STATE_CANCELLED;
    storage.validUntil = blockchain.now();
    storage.save();
    commitContractDataAndActions();

    var (domainAddress, domainReceived, found) = storage.domainsDict.sDictGetFirst(267);
    while (found) {
        if (domainReceived!.bitsEqual(BIT_TRUE_SLICE())) {  // check that domain was received
            // Return NFT back to seller
            createMessage({
                bounce: false,
                value: domainRefillFee(),
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
    }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);
}


// Forward bounced funds back to the seller as excesses
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

// Calculate TON amount to reserve 
@inline
fun getTonsToReserve(domainsTotal: uint8, autoRenewIterations: uint8, autoRenewCooldown: uint32, nothrow: bool): int {
    val tonsForAutoCancel = (domainRefillFee() * domainsTotal + saleStorageReserve(ONE_YEAR, domainsTotal) + cancelGasBudget(domainsTotal)) as coins;  // External-cancel budget: domain returns + own storage + cancel compute
    val tonsForAutoRenew = (getAutoRenewLockPerIter(domainsTotal, autoRenewCooldown) * autoRenewIterations) as coins;
    val tonsToReserve = tonsForAutoCancel + tonsForAutoRenew;
    assert( contract.getOriginalBalance() >= tonsToReserve || nothrow) throw EXC_OUT_OF_GAS;
    return tonsToReserve as int;
}


fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    var storage: Storage = lazy Storage.load();
    var storage2: StorageDs2 = lazy storage.ds2.load();
    
    // Allow admin operations when sale is not active or expired
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.validUntil + 600 < blockchain.now();
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: allowAdminCommands,
        allowChangeData: allowAdminCommands,
        allowSendAnyMessage: allowAdminCommands,
        allowWithdrawTon: true,
        allowWithdrawJetton: true,
    });
    
    var msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Deploy and activate the jetton sale
        DeployAndSetWalletMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                if (storage2.autoRenewIterations > 0) {
                    createMessage<AutoRenewPrepayMessage>({
                        bounce: false,
                        value: storage2.autoRenewIterations * TONS_AUTORENEW_MARKETPLACE_FEE,
                        dest: MARKETPLACE_ADDRESS,
                        body: AutoRenewPrepayMessage {
                            queryId: msg.queryId,
                            ownerAddress: storage.sellerAddress,
                            iterations: storage2.autoRenewIterations
                        }
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                }
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE; 
                storage.save();
            }
            return;
        }
        
        // Seller transfers domain to this contract
        NftOwnershipAssignedMessage => {
            try {
                // Check that domain present in the storage
                var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
                assert(found) throw EXC_INCORRECT_DOMAIN; 
                
                // Mark domain as received
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                storage.domainsReceived += 1;

                if (storage.domainsReceived == storage.domainsTotal) {  // If all domains were received, reserve required TONs and send excess to seller
                    reserveToncoinsOnBalance(getTonsToReserve(storage.domainsTotal, storage2.autoRenewIterations, storage2.autoRenewCooldown, false), RESERVE_MODE_EXACT_AMOUNT);
                    
                    createMessage({
                        bounce: false,
                        value: 0,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Multiple sale on webdom.market is active".literalSlice() }
                    }).send(SEND_MODE_CARRY_ALL_BALANCE);
                }
                storage.save();
                return;
            } catch (e, _) {
                returnNftToSender(in.senderAddress, msg, e);
            }
        }
        
        // Handle domain expiration notification
        DnsBalanceReleaseMessage => {
            // Check that domain present in the storage
            var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
            assert(found) throw EXC_INCORRECT_DOMAIN;

            // Cancel sale if it is not cancelled yet
            if (storage.state != STATE_CANCELLED) {
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_FALSE_SLICE());
                cancelSale(mutate storage, 0, "Your domain has expired".literalSlice());
            }
            
            return;
        }
        
        // Handle jetton purchase
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var fromAddress = msg.fromAddress;

            // Parse forward payload in case jettons were received via dedust swap
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                msg.forwardPayload = msg.forwardPayload.load();
            }
            if (msg.forwardPayload.remainingBitsCount() == 267) {
                // Get real sender address
                fromAddress = address.fromSlice(msg.forwardPayload);
            }

            try {
                // Verify purchase conditions
                val nowTs: uint32 = blockchain.now();
                assert(storage.state == STATE_ACTIVE && storage.validUntil > nowTs && storage.domainsReceived == storage.domainsTotal) throw EXC_DEAL_NOT_ACTIVE;
                assert(storage.lastRenewalTime > nowTs - (ONE_YEAR - ONE_DAY)) throw EXC_DOMAIN_EXPIRED;
                assert(storage.jettonWalletAddress != null && in.senderAddress == storage.jettonWalletAddress!) throw EXC_INCORRECT_SENDER;
                val jettonWalletAddr: address = storage.jettonWalletAddress!;
                assert(in.valueCoins >= TONS_PURCHASE_PER_DOMAIN() * storage.domainsTotal + TONS_JETTON_MULTIPLE_PURCHASE()) throw EXC_OUT_OF_GAS;
                assert(msg.transferredJettons >= storage.price) throw EXC_NOT_ENOUGH_JETTONS;
                
                // Return excess jettons to buyer (used when jettons were received via dedust swap)
                var excesses = msg.transferredJettons - storage.price;
                if (excesses > 0) {
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER,
                        dest: jettonWalletAddr,
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
                    // Send marketplace commission
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
                        dest: jettonWalletAddr,
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

                // Send all domains to buyer
                var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
                while (found) {
                    createMessage({
                        bounce: false,
                        value: TONS_PURCHASE_NOTIFICATION + domainRefillFee(),
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

                // Send seller payout with unused TONs
                var sellerTonExcesses = contract.getOriginalBalance() - in.valueCoins;
                createMessage({
                    bounce: false,
                    value: TONS_JETTON_TRANSFER + sellerTonExcesses,
                    dest: jettonWalletAddr,
                    body: SendJettonsMessage<cell> {
                        queryId: msg.queryId,
                        jettonAmount: storage.price - storage.commission,
                        toAddress: storage.sellerAddress,
                        responseAddress: fromAddress,
                        forwardTonAmount: sellerTonExcesses,
                        forwardPayload: MULTIPLE_SALE_NOTIFICATION()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);

                // Set sale state to completed
                storage.state = STATE_COMPLETED;
                storage.validUntil = blockchain.now();
                storage2.buyerAddress = fromAddress;
                storage.ds2 = storage2.toCell();
                storage.save();
                return;
            } catch (e, _) {
                returnJettonsToSender(in.senderAddress, msg, e);
            }
        }
        
        // Change price and validity period
        ChangePriceMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            // Check that new validUntil time is greater than current time and less than domain expiration time
            val maxValidUntil = storage.lastRenewalTime + storage2.autoRenewCooldown * storage2.autoRenewIterations + ONE_YEAR - ONE_DAY;
            assert((msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) && 
                   (msg.newValidUntil <= maxValidUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            assert(msg.newPrice > 0) throw EXC_INCORRECT_PRICE;
            var newCommission = mulDivFloor(msg.newPrice, storage.commission, storage.price);

            storage.validUntil = msg.newValidUntil;
            storage.price = msg.newPrice;
            storage.commission = newCommission;
            storage.save();
            
            val isWeb3 = storage2.jettonMinterAddress == WEB3_ADDRESS;
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                    .storeUint(0, 32)
                    .storeSlice("Price changed to ".literalSlice())
                    .storeStrFloat(msg.newPrice, isWeb3 ? 1000 : 1000000)
                    .storeSlice(isWeb3 ? " WEB3".literalSlice() : " USDT".literalSlice())
                .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            return;
        }
        
        // Renew all domains and extend sale validity
        RenewDomainMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;  // Check that message sender is the seller
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            assert(in.valueCoins >= TONS_RENEW_REQUEST + renewDomainFee() * storage.domainsTotal) throw EXC_OUT_OF_GAS;  // Check that enough TONs are sent
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // Check that domain is not expired

            // Reserve TONs required for storage
            reserveToncoinsOnBalance(max(getTonsToReserve(storage.domainsTotal, storage2.autoRenewIterations, storage2.autoRenewCooldown, false), contract.getOriginalBalance() - in.valueCoins), RESERVE_MODE_EXACT_AMOUNT);
            
            // Renew all domains
            var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
            while (found) {
                createMessage({
                    bounce: false,
                    value: renewDomainFee(),
                    dest: domainAddress! as address
                }).send(SEND_MODE_REGULAR);
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
            val maxValidUntil = blockchain.now() + storage2.autoRenewCooldown * storage2.autoRenewIterations + ONE_YEAR - ONE_DAY;
            if (msg.newValidUntil != null) {
                assert(msg.newValidUntil <= maxValidUntil) throw EXC_INCORRECT_VALID_UNTIL;
                storage.validUntil = max(msg.newValidUntil, storage.validUntil);
            } else {
                storage.validUntil = maxValidUntil;
            }
            
            storage.lastRenewalTime = blockchain.now();
            storage.save();
            return;
        }

        // Update auto-renew settings and paid iterations
        SetAutoRenewParamsMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert((msg.autoRenewCooldown >= ONE_DAY) && (msg.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            assert(msg.autoRenewIterations >= storage2.autoRenewIterations) throw EXC_INCORRECT_VALID_UNTIL;

            val addIterations: uint8 = msg.autoRenewIterations - storage2.autoRenewIterations;
            if (addIterations > 0) {
                val topUpReserve: coins = (getAutoRenewLockPerIter(storage.domainsTotal, msg.autoRenewCooldown) + TONS_AUTORENEW_MARKETPLACE_FEE) * addIterations;
                assert(in.valueCoins >= topUpReserve + gasFee(GAS_AUTORENEW_TOPUP)) throw EXC_OUT_OF_GAS;
            }

            val maxValidUntil: int = storage.lastRenewalTime + msg.autoRenewCooldown * msg.autoRenewIterations + ONE_YEAR - ONE_DAY;
            if (msg.newValidUntil != null) {
                assert(msg.newValidUntil <= maxValidUntil && msg.newValidUntil >= storage.validUntil) throw EXC_INCORRECT_VALID_UNTIL;
                storage.validUntil = msg.newValidUntil;
            }
            else {
                storage.validUntil = maxValidUntil;
            }

            storage2.autoRenewCooldown = msg.autoRenewCooldown;
            storage2.autoRenewIterations = msg.autoRenewIterations;
            storage.ds2 = storage2.toCell();
            storage.save();

            reserveToncoinsOnBalance(getTonsToReserve(storage.domainsTotal, storage2.autoRenewIterations, storage2.autoRenewCooldown, false), RESERVE_MODE_EXACT_AMOUNT);

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
            if (op == OP_CANCEL_DEAL) {
                assert(in.senderAddress == storage.sellerAddress || in.senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                // Handle sale cancellation
                cancelSale(mutate storage,  queryId, "Sale cancelled".literalSlice());
                return;
            }
            throw EXC_UNSUPPORTED_OP;
        }
    }
}

fun onExternalMessage(inMsg: slice): void {
    var storage: Storage = lazy Storage.load();
    var storage2: StorageDs2 = lazy storage.ds2.load();
    var nowTs: uint32 = blockchain.now();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }

    var (opCode, queryId) = loadOpAndQueryId(mutate inMsg);
    if (opCode == OP_CANCEL_DEAL) {
        // Allow anyone to cancel expired sales
        assert(nowTs >= storage.validUntil || storage.lastRenewalTime < nowTs - ONE_YEAR + ONE_DAY) throw 0xfffe;
        assert(contract.getOriginalBalance() >= domainRefillFee() * storage.domainsReceived + cancelGasBudget(storage.domainsReceived)) throw EXC_OUT_OF_GAS;
        acceptExternalMessage();

        cancelSale(mutate storage, queryId, "Your sale offer has expired".literalSlice());
        return;
    }

    if (opCode == OP_TRIGGER_AUTORENEW) {
        assert(storage2.autoRenewIterations > 0) throw EXC_UNSUPPORTED_OP;
        assert(storage.domainsReceived == storage.domainsTotal) throw EXC_DEAL_NOT_ACTIVE;
        assert(nowTs < storage.validUntil) throw EXC_DEAL_NOT_ACTIVE;
        assert(storage.lastRenewalTime <= nowTs - storage2.autoRenewCooldown) throw 0xfffe;

        acceptExternalMessage();
        val gasToReserve: coins = getTonsToReserve(storage.domainsTotal, storage2.autoRenewIterations - 1, storage2.autoRenewCooldown, false);
        val renewCost: coins = renewDomainFee() * storage.domainsTotal;
        if (contract.getOriginalBalance() < gasToReserve + renewCost || storage.lastRenewalTime <= nowTs - (ONE_YEAR - ONE_HOUR)) {
            cancelSale(mutate storage, queryId, "Your sale offer has expired".literalSlice());
            return;
        }

        storage.lastRenewalTime = nowTs;
        storage2.autoRenewIterations -= 1;
        storage.ds2 = storage2.toCell();
        storage.save();

        var (domainAddress, _, found) = storage.domainsDict.sDictGetFirst(267);
        while (found) {
            createMessage({
                bounce: false,
                value: renewDomainFee(),
                dest: domainAddress! as address
            }).send(SEND_MODE_REGULAR);
            (domainAddress, _, found) = storage.domainsDict.sDictGetNext(267, domainAddress!);
        }
        return;
    }
    
    throw EXC_UNSUPPORTED_OP;
}

get fun get_storage_data() {
    var storage = Storage.load();
    var storage2: StorageDs2 = lazy storage.ds2.load();
    
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
        storage2.buyerAddress == null ? (createAddressNone() as address) : storage2.buyerAddress!,
        getTonsToReserve(storage.domainsTotal, storage2.autoRenewIterations, storage2.autoRenewCooldown, true),
        storage.jettonWalletAddress == null ? (createAddressNone() as address) : storage.jettonWalletAddress!,
        storage2.autoRenewCooldown,
        storage2.autoRenewIterations,
        storage.hotUntil,
        storage.coloredUntil,
        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
}

get fun get_fix_price_data_v4() {
    var storage = lazy Storage.load();

    var (domainAddress, _, _) = storage.domainsDict.sDictGetFirst(267);
    var jettonPriceDict = createEmptyDict();
    val jwAddr: address = storage.jettonWalletAddress == null ? (createAddressNone() as address) : storage.jettonWalletAddress!;
    jettonPriceDict.uDictSetBuilder(256, jwAddr.getWorkchainAndHash().1, beginCell().storeCoins(storage.price));

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

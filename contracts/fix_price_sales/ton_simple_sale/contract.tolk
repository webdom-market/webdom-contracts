import "@stdlib/tvm-dicts"
import "@stdlib/gas-payments"
import "../../imports/gas"
import "../../imports/constants"
import "../../imports/messages"
import "../../imports/utils"
import "../../imports/handle_promotion"
import "../../imports/admin_message"
import "../constants"
import "../messages"
import "storage"
import "messages"
import "constants"


@inline
fun cancelDeal(mutate storage: Storage, queryId: uint64): void {
    // Return domain to seller
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

    // Update sale state
    storage.state = STATE_CANCELLED;
    if (storage.validUntil > blockchain.now()) {
        storage.validUntil = blockchain.now();
    }
    storage.save();
    return;
}

@inline
fun getRequiredReserve(autoRenewIterations: uint8, autoRenewCooldown: uint32): coins {
    // Autocancel reserve = sale's own 1yr storage + cost to send the domain NFT back on cancel
    // (nftTransferFee; domain storage is pre-funded at deposit). Auto-renew lock adds one cooldown
    // of storage per iteration.
    return saleStorageReserve(ONE_YEAR) + nftTransferFee() + autoRenewLockPerIter(autoRenewCooldown) * autoRenewIterations;
}

fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    var storage: Storage = lazy Storage.load();
    var autoRenewData: AutoRenewData = lazy storage.autoRenewData.load();

    // Handle admin messages for contract management
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state != STATE_ACTIVE,
        allowChangeData: storage.state != STATE_ACTIVE,
        allowSendAnyMessage: storage.state != STATE_ACTIVE,
        allowWithdrawTon: storage.state != STATE_ACTIVE,
        allowWithdrawJetton: true,
    });
    
    val msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Activate the sale when deployed by marketplace
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
                return;
            }
            return;
        }
                
        // Allow seller to change price and validity period
        ChangePriceMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;

            // Check that new validUntil time is greater than current time and less than domain expiration time
            assert(msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            if (!storage.isTgUsername) {
                val maxValidUntil = storage.lastRenewalTime + autoRenewData.autoRenewCooldown * autoRenewData.autoRenewIterations + ONE_YEAR - ONE_DAY;
                assert(msg.newValidUntil <= maxValidUntil) throw EXC_INCORRECT_VALID_UNTIL;
            }

            assert(msg.newPrice > 0) throw EXC_INCORRECT_PRICE;

            // Update data and recalculate commission
            var oldPrice = storage.price;
            storage.price = msg.newPrice;
            storage.commission = mulDivFloor(msg.newPrice, storage.commission, oldPrice);
            storage.validUntil = msg.newValidUntil;
            storage.save();
                        
            // Notify seller about successful price change
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
        
        // Allow seller to renew domain and extend sale validity
        RenewDomainMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            assert(in.valueCoins >= TONS_RENEW_REQUEST + renewDomainFee()) throw EXC_OUT_OF_GAS;
                        
            // Reserve minimum balance for auto-cancellation
            reserveToncoinsOnBalance(getRequiredReserve(autoRenewData.autoRenewIterations, autoRenewData.autoRenewCooldown), RESERVE_MODE_EXACT_AMOUNT);

            // Send renewal transaction to domain contract
            createMessage({
                bounce: false,
                value: renewDomainFee(),
                dest: storage.domainAddress,
            }).send(SEND_MODE_REGULAR);
            
            // Send renewal fee to marketplace
            createMessage<RenewalFeeMessage>({
                bounce: false,
                value: 0,
                dest: MARKETPLACE_ADDRESS,
                body: RenewalFeeMessage { queryId: msg.queryId, ownerAddress: storage.sellerAddress }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            // Calculate new validity period
            val maxValidUntil = blockchain.now() + autoRenewData.autoRenewCooldown * autoRenewData.autoRenewIterations + ONE_YEAR - ONE_DAY;
            if (msg.newValidUntil != null) {
                assert(msg.newValidUntil <= maxValidUntil) throw EXC_INCORRECT_VALID_UNTIL;
                storage.validUntil = max(msg.newValidUntil, storage.validUntil);
            } else {
                storage.validUntil = maxValidUntil;
            }

            // Update storage with new renewal time
            storage.lastRenewalTime = blockchain.now();
            storage.save();
            return;
        }

        // Update auto-renew settings and paid iterations
        SetAutoRenewParamsMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
            assert((msg.autoRenewCooldown >= ONE_DAY) && (msg.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            assert(msg.autoRenewIterations >= autoRenewData.autoRenewIterations) throw EXC_INCORRECT_VALID_UNTIL;

            val addIterations: uint8 = msg.autoRenewIterations - autoRenewData.autoRenewIterations;
            if (addIterations > 0) {
                val topUpReserve: coins = (autoRenewLockPerIter(msg.autoRenewCooldown) + TONS_AUTORENEW_MARKETPLACE_FEE) * addIterations;
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

            autoRenewData.autoRenewCooldown = msg.autoRenewCooldown;
            autoRenewData.autoRenewIterations = msg.autoRenewIterations;
            storage.autoRenewData = autoRenewData.toCell();
            storage.save();

            reserveToncoinsOnBalance(getRequiredReserve(autoRenewData.autoRenewIterations, autoRenewData.autoRenewCooldown), RESERVE_MODE_EXACT_AMOUNT);

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
            assert(in.senderAddress == storage.domainAddress) throw EXC_INCORRECT_DOMAIN;
            
            // Cancel the sale
            storage.state = STATE_CANCELLED;
            storage.save();
            commitContractDataAndActions();
            
            // Notify seller about domain expiration
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.sellerAddress,
                body: CommentMessage { comment: "Your domain has expired" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);
            
            return;
        }

        // Handle "hot" promotion for the domain sale
        MakeHotMessage => {
            handleMakeHot<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }

        // Handle "colored" promotion for the domain sale
        MakeColoredMessage => {
            handleMakeColored<Storage>(mutate storage, msg.promotionUntil, msg.queryId, in.senderAddress);
            return;
        }
        
        // Accept excess
        ExcessesMessage => {
            return;
        }

        else => {
            var (op, queryId) = loadOpAndQueryId(mutate in.body);
            var senderAddress: address = in.senderAddress;
            
            // Handle DeDust payout (extract real sender from payload)
            if (op == OP_DEDUST_PAYOUT || op == OP_BIDASK_PAYOUT) {
                op = 0;
                senderAddress = in.body.loadRef().beginParse() as address;
            }
            
            try {
                if (op == 0) {
                    // Handle domain purchase
                    val nowTs: uint32 = blockchain.now();
                    assert(storage.state == STATE_ACTIVE && storage.validUntil > nowTs) throw EXC_DEAL_NOT_ACTIVE;  // check that sale is active 
                    assert(storage.isTgUsername || storage.lastRenewalTime > nowTs - (ONE_YEAR - ONE_DAY)) throw EXC_DOMAIN_EXPIRED;
                    assert(in.valueCoins >= storage.price + tonSimplePurchaseFee()) throw EXC_OUT_OF_GAS;  // check msg value is enough to pay for the sale

                    // Send marketplace commission
                    createMessage<CommentMessage>({
                        bounce: false,
                        value: storage.commission,
                        dest: MARKETPLACE_ADDRESS,
                        body: CommentMessage { comment: "Marketplace commission" }
                    }).send(SEND_MODE_REGULAR);
                    
                    // Send payment to seller
                    createMessage<cell>({
                        bounce: false,
                        value: storage.price - storage.commission + contract.getOriginalBalance() - in.valueCoins,
                        dest: storage.sellerAddress,
                        body: getPayoutNotificationBody(storage.domainNameCell)
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);

                    // Transfer domain to buyer
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

                    // Update sale state
                    storage.state = STATE_COMPLETED;
                    storage.validUntil = blockchain.now();
                    storage.buyerAddressCell = senderAddress.toCell();
                    storage.save();

                    return;
                }
                else if (op == OP_CANCEL_DEAL) {
                    // Handle sale cancellation
                    assert(senderAddress == storage.sellerAddress || senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                    assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
                    cancelDeal(mutate storage, in.body.remainingBitsCount() >= 64 ? in.body.loadUint(64) : 0);

                    return;
                }
            } catch (e, _) {
                // Send error notification
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: senderAddress,
                    body: beginCell().storeUint(0, 32).storeSlice("Error, code").storeNumber10(e).endCell()
                }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                
                commitContractDataAndActions();

                throw e;
            }

            throw EXC_UNSUPPORTED_OP;
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
        assert(nowTs >= storage.validUntil || (!storage.isTgUsername && storage.lastRenewalTime < nowTs - ONE_YEAR + ONE_DAY)) throw 0xfffe;
        acceptExternalMessage();
        cancelDeal(mutate storage, queryId);
        return;
    }

    if (opCode == OP_TRIGGER_AUTORENEW) {
        assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
        assert(autoRenewData.autoRenewIterations > 0) throw EXC_UNSUPPORTED_OP;
        assert(nowTs < storage.validUntil) throw EXC_DEAL_NOT_ACTIVE;
        assert(storage.lastRenewalTime <= nowTs - autoRenewData.autoRenewCooldown) throw 0xfffe;

        acceptExternalMessage();
        val gasToReserve: coins = getRequiredReserve(autoRenewData.autoRenewIterations - 1, autoRenewData.autoRenewCooldown);
        if (contract.getOriginalBalance() < gasToReserve + renewDomainFee() || storage.lastRenewalTime <= nowTs - (ONE_YEAR - ONE_HOUR)) {
            cancelDeal(mutate storage, queryId);
            return;
        }

        storage.lastRenewalTime = nowTs;
        autoRenewData.autoRenewIterations -= 1;
        storage.autoRenewData = autoRenewData.toCell();
        storage.save();

        createMessage({
            bounce: false,
            value: renewDomainFee(),
            dest: storage.domainAddress,
        }).send(SEND_MODE_REGULAR);
        return;
    }

    throw EXC_UNSUPPORTED_OP;
}

// Get contract storage data for external queries
get fun get_storage_data() {
    var storage: Storage = Storage.load();
    var autoRenewData: AutoRenewData = lazy storage.autoRenewData.load();
    
    // Create dictionary with single domain
    var domainsDict: dict = createEmptyDict();
    domainsDict.sDictSet(267, storage.domainAddress as slice, BIT_TRUE_SLICE());
    
    var buyerAddress: address = storage.buyerAddressCell == null ? createAddressNone() : storage.buyerAddressCell!.load();
    
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
        storage.isTgUsername,       
        autoRenewData.autoRenewCooldown,
        autoRenewData.autoRenewIterations,
        storage.hotUntil,            
        storage.coloredUntil,
        BURN_ADDRESS,                // Jetton minter address (unused)
        contract.getCode().hash()    // contract version index
    );
} 

// Legacy method from https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-fixprice-sale-v3r3.fc
get fun get_sale_data() {
    var storage: Storage = Storage.load();

    return (
        0x46495850,              
        storage.state > STATE_ACTIVE, 
        storage.createdAt,       
        MARKETPLACE_ADDRESS,     
        storage.domainAddress,   
        storage.sellerAddress,   
        storage.price,           
        MARKETPLACE_ADDRESS,     
        storage.commission,      
        BURN_ADDRESS,            
        0                        
    );
}

get fun get_fix_price_data() {
    var storage: Storage = Storage.load();

    return (
        storage.state > STATE_ACTIVE,
        storage.createdAt,
        MARKETPLACE_ADDRESS,
        storage.domainAddress,
        storage.sellerAddress,
        storage.price,
        MARKETPLACE_ADDRESS,
        storage.commission,
        BURN_ADDRESS,
        0,
        storage.validUntil > blockchain.now() ? (0 as uint32) : storage.validUntil,
        0
    );
}

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


@inline
fun cancelDeal(mutate storage: Storage, domainAddress: address, queryId: uint64): void {
    // Return domain to seller
    createMessage<NftTransferMessage<cell>>({
        bounce: false,
        value: 0,
        dest: domainAddress,
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
    storage.validUntil = min(storage.validUntil, blockchain.now());
    storage.save();

    return;
}

@inline
fun getRequiredReserve(autoRenewIterations: uint8, autoRenewCooldown: uint32): coins {
    // Sale's own 1yr storage + lean transfer-out cost (domain storage is pre-funded at deposit via
    // domainRefillFee). Auto-renew lock adds one cooldown of storage per iteration.
    return saleStorageReserve(ONE_YEAR) + nftTransferFee() + autoRenewLockPerIter(autoRenewCooldown) * autoRenewIterations;
}


fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);

    var storage: Storage = lazy Storage.load();

    // Allow admin commands when sale is inactive or expired
    val allowAdminCommands: bool = storage.state != STATE_ACTIVE || storage.validUntil + 600 < blockchain.now();
    handleAdminMessage(
        in.senderAddress,
        in.body,
        Permissions {
            allowChangeCode: allowAdminCommands,
            allowChangeData: allowAdminCommands,
            allowSendAnyMessage: allowAdminCommands,
            allowWithdrawTon: allowAdminCommands,
            allowWithdrawJetton: true
        }
    );

    var msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);

    match(msg) {
        // Deploy and activate the jetton sale
        DeployAndSetWalletMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                
                // Set jetton wallet and activate sale
                storage.jettonWalletAddress = msg.jettonWalletAddress;
                storage.state = STATE_ACTIVE;
                storage.save();
                
                // Forward marketplace auto-renew prepay (if any). Deploy value is sized to reserve +
                // activation gas, so any tiny surplus just stays on the sale's balance.
                var storage2: StorageDs2 = lazy storage.ds2.load();
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

                return;
            }
            return;
        }

        // Handle NFT purchase
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            
            // Parse forward payload in case jettons were received via dedust swap
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                msg.forwardPayload = msg.forwardPayload.load(); 
            }
            if ((msg.forwardPayload as slice).remainingBitsCount() == 267) {
                // Get real sender address
                msg.fromAddress = address.fromSlice(msg.forwardPayload);
            }

            try {
                // Verify purchase conditions
                val nowTs: uint32 = blockchain.now();
                assert(storage.jettonWalletAddress != null && in.senderAddress == storage.jettonWalletAddress!) throw EXC_INCORRECT_SENDER;
                assert(storage.state == STATE_ACTIVE && storage.validUntil > nowTs) throw EXC_DEAL_NOT_ACTIVE;
                assert(storage.isTgUsername || storage.lastRenewalTime > nowTs - (ONE_YEAR - ONE_DAY)) throw EXC_DOMAIN_EXPIRED;
                assert(in.valueCoins >= jettonSimplePurchaseFee()) throw EXC_OUT_OF_GAS;
                assert(msg.transferredJettons >= storage.price) throw EXC_NOT_ENOUGH_JETTONS;

                // Return excess jettons to buyer (used when jettons were received via dedust swap)
                var excesses: coins = msg.transferredJettons - storage.price;
                if (excesses > 0) {
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER,
                        dest: in.senderAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: excesses,
                            toAddress: msg.fromAddress,
                            responseAddress: msg.fromAddress,
                            forwardTonAmount: 1,
                            forwardPayload: (CommentMessage { comment: "Excesses".literalSlice() }).toCell()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                if (storage.commission > 0) {
                    // Send marketplace commission
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
                        dest: in.senderAddress,
                        body: SendJettonsMessage<cell> {
                            queryId: msg.queryId,
                            jettonAmount: storage.commission,
                            toAddress: MARKETPLACE_ADDRESS,
                            responseAddress: msg.fromAddress,
                            forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                            forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);
                }

                // Send payment to seller
                createMessage({
                    bounce: false,
                    value: TONS_JETTON_TRANSFER + contract.getOriginalBalance() - in.valueCoins,
                    dest: in.senderAddress,
                    body: SendJettonsMessage<cell> {
                        queryId: msg.queryId,
                        jettonAmount: storage.price - storage.commission,
                        toAddress: storage.sellerAddress,
                        responseAddress: storage.sellerAddress,
                        forwardTonAmount: 1,
                        forwardPayload: getPayoutNotificationBody(storage.domainNameCell)
                    }
                }).send(SEND_MODE_REGULAR);

                // Transfer domain to buyer
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: storage2.domainAddress,
                    body: NftTransferMessage<cell> {
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        responseAddress: msg.fromAddress,
                        forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
                        forwardPayload: BUYER_NOTIFICATION()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);

                // Update sale state
                storage.state = STATE_COMPLETED;
                storage.validUntil = blockchain.now();
                storage2.buyerAddress = msg.fromAddress;
                storage.ds2 = storage2.toCell();
                storage.save();

                return;
            } catch (e, _) {
                // Return jettons to sender on error
                returnJettonsToSender(in.senderAddress, msg, e);
            }
        }

        // Allow seller to change price and validity period
        ChangePriceMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;  // check that sender is seller
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;
            
            // Check that new validUntil time is greater than current time and less than domain expiration time
            assert(msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;  // check that new validity period is greater than current
            if (!storage.isTgUsername) {
                // Cap sale validity at the domain's guaranteed lifetime (last renewal + prepaid auto-renew + ~1yr).
                // TG usernames never expire, so they are exempt.
                val maxValidUntil = storage.lastRenewalTime + storage2.autoRenewCooldown * storage2.autoRenewIterations + ONE_YEAR - ONE_DAY;
                assert(msg.newValidUntil <= maxValidUntil) throw EXC_INCORRECT_VALID_UNTIL;
            }
        
            assert(msg.newPrice > 0) throw EXC_INCORRECT_PRICE;

            // Determine jetton display parameters
            var (oneJetton, symbol) = storage2.jettonMinterAddress == WEB3_ADDRESS ? (1000, "WEB3".literalSlice()) : (1000000, "USDT".literalSlice());
            
            // Notify seller about successful price change
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                        .storeUint(0, 32)
                        .storeSlice("Price changed to ".literalSlice())
                        .storeStrJettons(msg.newPrice, oneJetton, symbol)
                      .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);

            // Update price and recalculate commission
            storage.commission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
            storage.price = msg.newPrice;
            storage.validUntil = msg.newValidUntil;
            storage.save();

            return;
        }

        // Allow seller to renew domain and extend sale validity
        RenewDomainMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            assert(in.valueCoins >= TONS_RENEW_REQUEST + renewDomainFee()) throw EXC_OUT_OF_GAS;

            // Reserve minimum balance for auto-cancellation
            reserveToncoinsOnBalance(getRequiredReserve(storage2.autoRenewIterations, storage2.autoRenewCooldown), RESERVE_MODE_EXACT_AMOUNT);

            // Send renewal transaction to domain contract
            createMessage({
                bounce: false,
                value: renewDomainFee(),
                dest: storage2.domainAddress,
            }).send(SEND_MODE_REGULAR);
            
            // Send renewal fee to marketplace
            createMessage<RenewalFeeMessage>({
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

            // Update storage with new renewal time
            storage.lastRenewalTime = blockchain.now();
            storage.save();

            return;
        }

        // Update auto-renew settings and paid iterations
        SetAutoRenewParamsMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
            assert((msg.autoRenewCooldown >= ONE_DAY) && (msg.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            assert(msg.autoRenewIterations >= storage2.autoRenewIterations) throw EXC_INCORRECT_VALID_UNTIL;

            val addIterations: uint8 = msg.autoRenewIterations - storage2.autoRenewIterations;
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

            storage2.autoRenewCooldown = msg.autoRenewCooldown;
            storage2.autoRenewIterations = msg.autoRenewIterations;
            storage.ds2 = storage2.toCell();
            storage.save();

            reserveToncoinsOnBalance(getRequiredReserve(storage2.autoRenewIterations, storage2.autoRenewCooldown), RESERVE_MODE_EXACT_AMOUNT);

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
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage2.domainAddress) throw EXC_INCORRECT_DOMAIN;

            // Cancel the sale
            storage.state = STATE_CANCELLED;
            storage.save();
            commitContractDataAndActions();

            // Notify seller about domain expiration
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.sellerAddress,
                body: CommentMessage { comment: "Your domain has expired".literalSlice() }
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

        // Accept excess coins from operations
        ExcessesMessage => { 
            return; 
        }

        else => {
            var (op, queryId) = loadOpAndQueryId(mutate in.body);
            if (op == OP_CANCEL_DEAL) {
                assert(in.senderAddress == storage.sellerAddress || in.senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                var storage2: StorageDs2 = lazy storage.ds2.load();
                cancelDeal(mutate storage, storage2.domainAddress, queryId);
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
        assert(nowTs >= storage.validUntil || (!storage.isTgUsername && storage.lastRenewalTime < nowTs - ONE_YEAR + ONE_DAY)) throw 0xfffe;
        acceptExternalMessage();
        cancelDeal(mutate storage, storage2.domainAddress, queryId);
        return;
    }

    if (opCode == OP_TRIGGER_AUTORENEW) {
        assert(!storage.isTgUsername) throw EXC_UNSUPPORTED_OP;
        assert(storage2.autoRenewIterations > 0) throw EXC_UNSUPPORTED_OP;
        assert(nowTs < storage.validUntil) throw EXC_DEAL_NOT_ACTIVE;
        assert(storage.lastRenewalTime <= nowTs - storage2.autoRenewCooldown) throw 0xfffe;

        acceptExternalMessage();
        val gasToReserve: coins = getRequiredReserve(storage2.autoRenewIterations - 1, storage2.autoRenewCooldown);
        if (contract.getOriginalBalance() < gasToReserve + renewDomainFee() || storage.lastRenewalTime <= nowTs - (ONE_YEAR - ONE_HOUR)) {
            cancelDeal(mutate storage, storage2.domainAddress, queryId);
            return;
        }

        storage.lastRenewalTime = nowTs;
        storage2.autoRenewIterations -= 1;
        storage.ds2 = storage2.toCell();
        storage.save();

        createMessage({
            bounce: false,
            value: renewDomainFee(),
            dest: storage2.domainAddress,
        }).send(SEND_MODE_REGULAR);
        return;
    }

    throw EXC_UNSUPPORTED_OP;
}


get fun get_storage_data() {
    var storage: Storage = lazy Storage.load();
    var storage2: StorageDs2 = lazy storage.ds2.load();
    
    // Create dictionary with single domain
    var dict: dict = createEmptyDict();
    dict.sDictSet(267, storage2.domainAddress as slice, BIT_TRUE_SLICE());
 
    return (
        storage.sellerAddress,
        dict,
        1,
        1,
        storage.state,
        storage.price,
        mulDivFloor(storage.commission, COMMISSION_DIVIDER, storage.price),
        storage.createdAt,
        storage.lastRenewalTime,
        storage.validUntil,
        storage2.buyerAddress == null ? (createAddressNone() as address) : storage2.buyerAddress!,
        storage.domainNameCell,
        storage.isTgUsername,
        storage.jettonWalletAddress == null ? (createAddressNone() as address) : storage.jettonWalletAddress!,
        storage2.autoRenewCooldown,
        storage2.autoRenewIterations,

        storage.hotUntil,
        storage.coloredUntil,

        storage2.jettonMinterAddress,
        contract.getCode().hash()
    );
} 

// Legacy method for compatibility with getgems parsers
get fun get_fix_price_data_v4() {
    var storage: Storage = lazy Storage.load();
    var storage2: StorageDs2 = lazy storage.ds2.load();
    
    // Create jetton price dictionary
    var jettonPriceDict: dict = createEmptyDict();
    val jwAddr: address = storage.jettonWalletAddress == null ? (createAddressNone() as address) : storage.jettonWalletAddress!;
    jettonPriceDict.uDictSetBuilder(256, jwAddr.getWorkchainAndHash().1, beginCell().storeCoins(storage.price));

    return (
        storage.state > STATE_ACTIVE,
        storage.createdAt,
        MARKETPLACE_ADDRESS,
        storage2.domainAddress,
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

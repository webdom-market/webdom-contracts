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

// Minimum TON that must remain on balance to cover storage for ~1 year
const TONS_MIN_TON_FOR_STORAGE: coins = ton("0.035");  // TON for paying storage fees for 1 year

// Cancel the multiple sale and return all received domains back to the seller
// - Iterates over all domains and transfers only those that were actually received
// - Sends a final notification and carries all remaining balance to the seller
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
fun getTonsToReserve(domainsTotal: uint8, nothrow: bool): int {
    var tonsToReserve = (TONS_NFT_TRANSFER + ton("0.0075")) * domainsTotal + TONS_MIN_TON_FOR_STORAGE;  // Balance required to cancel the sale via external message
    var actualBalance = contract.getOriginalBalance() - ton("0.01") - storageFees();
    assert(actualBalance >= TONS_MIN_TON_FOR_STORAGE || nothrow) throw EXC_OUT_OF_GAS;
    if (actualBalance < tonsToReserve) {  // If balance is less than required, return minimal reserve
        return TONS_MIN_TON_FOR_STORAGE;
    }
    return tonsToReserve as int;
}

fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    var storage: Storage = lazy Storage.load();
    
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
        // Deploy and activate the jetton sale
        DeployAndSetWalletMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                
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
        
        // Handle domain expiration notification
        DnsBalanceReleaseMessage => {
            // Check that domain present in the storage
            var (_, found) = storage.domainsDict.sDictGet(267, in.senderAddress as slice);
            assert(found) throw EXC_INCORRECT_DOMAIN;

            // Cancel sale if it is not cancelled yet
            if (storage.state != STATE_CANCELLED) {
                storage.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_FALSE_SLICE());
                cancelSale(mutate storage, 0, "Your domain has expired");
            }
            
            return;
        }
        
        // Handle jetton purchase
        JettonsTransferNotificationMessage<SerializableSlice> => {
            var fromAddress = msg.fromAddress;

            // Parse forward payload in case jettons were received via dedust swap
            if (msg.forwardPayload is Cell<SerializableSlice>) {
                fromAddress = address.fromSlice(msg.forwardPayload.load());
            }
            else if (msg.forwardPayload.remainingBitsCount() == 267) {
                // Get real sender address
                fromAddress = address.fromSlice(msg.forwardPayload);
            }

            try {
                // Verify purchase conditions
                assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now() && storage.domainsReceived == storage.domainsTotal) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.senderAddress == storage.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                assert(in.valueCoins >= TONS_TON_SIMPLE_PURCHASE * storage.domainsTotal + TONS_JETTON_MULTIPLE_PURCHASE) throw EXC_OUT_OF_GAS;
                assert(msg.transferredJettons >= storage.price) throw EXC_NOT_ENOUGH_JETTONS;
                
                // Return excess jettons to buyer (used when jettons were received via dedust swap)
                var excesses = msg.transferredJettons - storage.price;
                if (excesses > 0) {
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
                    // Send marketplace commission
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

                // Send all domains to buyer
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

                // Send seller payout with unused TONs
                var sellerTonExcesses = contract.getOriginalBalance() - in.valueCoins - storageFees();
                createMessage({
                    bounce: false,
                    value: TONS_JETTON_TRANSFER + sellerTonExcesses,
                    dest: storage.jettonWalletAddress,
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
                storage.buyerAddressCell = fromAddress.toCell();
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
        
        // Renew all domains and extend sale validity
        RenewDomainMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;  // Check that message sender is the seller
            assert(storage.state == STATE_ACTIVE) throw EXC_DEAL_NOT_ACTIVE;  // Check that sale is active
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN * storage.domainsTotal) throw EXC_OUT_OF_GAS;  // Check that enough TONs are sent
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // Check that domain is not expired

            // Reserve TONs required for storage
            reserveToncoinsOnBalance(max(getTonsToReserve(storage.domainsTotal, false), contract.getOriginalBalance() - in.valueCoins - ton("0.007")), RESERVE_MODE_EXACT_AMOUNT);
            
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

            // Set new validUntil time
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
            if (in.body.remainingBitsCount() >= 32) {
                var op = in.body.loadUint(32);
                if ((op == 0 && in.body.bitsEqual("cancel")) || op == OP_CANCEL_DEAL) {
                    // Handle sale cancellation
                    cancelSale(mutate storage,  0, "Sale cancelled");
                    return;
                }
            }
            throw EXC_UNSUPPORTED_OP;
        }
    }
}

fun onExternalMessage(in: InMessage): void {
    var storage: Storage = Storage.load();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }

    // Cancel sale if it is expired
    if (blockchain.now() >= storage.validUntil) {
        var opCode = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        var queryId = in.body.loadUint(64);
        
        assert(contract.getOriginalBalance() >= (TONS_NFT_TRANSFER + ton("0.0075")) * storage.domainsReceived) throw EXC_OUT_OF_GAS;
        acceptExternalMessage();
        
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

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
            allowWithdrawTon: true,
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
                
                // Send excess to seller
                val msgValue: coins = contract.getOriginalBalance() - TONS_MIN_RESERVE_FOR_AUTOCANCEL;
                if (msgValue > TONS_MIN_EXCESS) {
                    createMessage<CommentMessage>({
                        bounce: false,
                        value: msgValue,
                        dest: storage.sellerAddress,
                        body: CommentMessage { comment: "Domain sale deployed successfully" }
                    }).send(SEND_MODE_REGULAR);
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
                assert(in.senderAddress == storage.jettonWalletAddress) throw EXC_INCORRECT_SENDER;
                assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;
                assert(in.valueCoins >= TONS_JETTON_SIMPLE_PURCHASE) throw EXC_OUT_OF_GAS;
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
                            forwardPayload: (CommentMessage { comment: "Excesses" }).toCell()
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
                        responseAddress: msg.fromAddress,
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
            assert(msg.newValidUntil >= max(blockchain.now() + 300, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;  // check that new validity period is greater than current

            // Determine jetton display parameters
            var (oneJetton, symbol) = storage2.jettonMinterAddress == WEB3_ADDRESS ? (1000, "WEB3") : (1000000, "USDT");
            
            // Notify seller about successful price change
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: in.senderAddress,
                body: beginCell()
                        .storeUint(0, 32)
                        .storeSlice("Price changed to ")
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
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN) throw EXC_OUT_OF_GAS;
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // Check that domain expires later than in one day

            // Reserve minimum balance for auto-cancellation
            reserveToncoinsOnBalance(TONS_MIN_RESERVE_FOR_AUTOCANCEL, RESERVE_MODE_EXACT_AMOUNT);

            // Send renewal transaction to domain contract
            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: storage2.domainAddress,
            }).send(SEND_MODE_PAY_FEES_SEPARATELY);
            
            // Send renewal fee to marketplace
            createMessage<RenewalFeeMessage>({
                bounce: false,
                value: 0,
                dest: MARKETPLACE_ADDRESS,
                body: RenewalFeeMessage { queryId: msg.queryId, ownerAddress: storage.sellerAddress }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
            // Calculate new validity period
            var newValidUntil: uint32;
            if (msg.newValidUntil != null) {
                newValidUntil = min(blockchain.now() + ONE_YEAR - ONE_DAY, msg.newValidUntil);
            } else {
                newValidUntil = blockchain.now() + ONE_YEAR - ONE_DAY;
            }
            
            assert(newValidUntil >= max(blockchain.now() + ONE_HOUR, storage.validUntil)) throw EXC_INCORRECT_VALID_UNTIL;
            
            // Update storage with new renewal time
            storage.validUntil = newValidUntil;
            storage.lastRenewalTime = blockchain.now();
            storage.save();

            return;
        }

        // Handle domain expiration notification
        DnsBalanceReleaseMessage => {
            var storage2: StorageDs2 = lazy storage.ds2.load();
            assert(in.senderAddress == storage2.domainAddress) throw EXC_INCORRECT_DOMAIN;

            // Cancel the sale
            storage.state = STATE_CANCELLED;
            storage.validUntil = min(storage.validUntil, blockchain.now());
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

        // Accept excess coins from operations
        ExcessesMessage => { 
            return; 
        }

        else => {
            if (in.body.remainingBitsCount() >= 32) {
                var op: uint32 = in.body.loadUint(32);
                if ((op == 0 && in.body.bitsEqual("cancel")) || op == OP_CANCEL_DEAL) {
                    // Handle sale cancellation if op == OP_CANCEL_DEAL or msgBody == "cancel"
                    var storage2: StorageDs2 = lazy storage.ds2.load();
                    cancelDeal(mutate storage, storage2.domainAddress, 0);
                    return;
                }
            }
            throw EXC_UNSUPPORTED_OP;
        }
    }
}


fun onExternalMessage(in: InMessage): void {
    var storage: Storage = lazy Storage.load();
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }
    
    // Allow anyone to cancel expired sales
    if (blockchain.now() >= storage.validUntil) {
        var opCode: uint32 = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        var queryId = in.body.loadUint(64);
        
        acceptExternalMessage();
        var storage2: StorageDs2 = lazy storage.ds2.load();
        cancelDeal(mutate storage, storage2.domainAddress, queryId);
        
        return;
    }
    
    throw 0xfffe;
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
        storage2.buyerAddress,
        storage.domainNameCell,
        storage.jettonWalletAddress,

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
    jettonPriceDict.uDictSetBuilder(256, storage.jettonWalletAddress.getWorkchainAndHash().1, beginCell().storeCoins(storage.price));

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
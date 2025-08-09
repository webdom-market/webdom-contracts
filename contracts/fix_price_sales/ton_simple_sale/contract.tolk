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


fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    var storage: Storage = lazy Storage.load();

    // Handle admin messages for contract management
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state != STATE_ACTIVE,
        allowChangeData: storage.state != STATE_ACTIVE,
        allowSendAnyMessage: storage.state != STATE_ACTIVE,
        allowWithdrawTon: true,
        allowWithdrawJetton: true,
    });
    
    val msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    
    match (msg) {
        // Activate the sale when deployed by marketplace
        FillUpBalanceMessage => {
            if (storage.state == STATE_UNINIT) {
                assert(in.senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
                storage.state = STATE_ACTIVE;
                storage.save();
                return;
            }
            return;
        }
                
        // Allow seller to change price and validity period
        ChangePriceMessage => {
            assert(in.senderAddress == storage.sellerAddress) throw EXC_INCORRECT_SENDER;
            assert((msg.newValidUntil >= max(blockchain.now() + 600, storage.validUntil)) && 
                   (msg.newValidUntil <= storage.lastRenewalTime + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;
            
            // Update data and recalculate commission
            storage.price = msg.newPrice;
            storage.commission = mulDivFloor(msg.newPrice, storage.commission, storage.price);
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
            assert(in.valueCoins >= TONS_RENEW_REQUEST + TONS_RENEW_DOMAIN) throw EXC_OUT_OF_GAS;
            assert(storage.lastRenewalTime + ONE_YEAR - ONE_DAY >= blockchain.now()) throw EXC_DOMAIN_EXPIRED;  // Check that domain expires later than in one day
                        
            // Reserve minimum balance for auto-cancellation
            reserveToncoinsOnBalance(TONS_MIN_RESERVE_FOR_AUTOCANCEL, RESERVE_MODE_EXACT_AMOUNT);

            // Send renewal transaction to domain contract
            createMessage({
                bounce: false,
                value: TONS_RENEW_DOMAIN,
                dest: storage.domainAddress,
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
            assert(in.senderAddress == storage.domainAddress) throw EXC_INCORRECT_DOMAIN;
            
            // Cancel the sale
            storage.state = STATE_CANCELLED;
            if (storage.validUntil > blockchain.now()) {
                storage.validUntil = blockchain.now();
            }
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
            if (op == OP_DEDUST_PAYOUT) {
                op = 0;
                senderAddress = in.body.loadMaybeRef()!.beginParse() as address;
            }
            
            try {
                if (op == 0) {
                    // Handle domain purchase
                    assert(storage.state == STATE_ACTIVE && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;  // check that sale is active 
                    assert(in.valueCoins >= storage.price + TONS_TON_SIMPLE_PURCHASE) throw EXC_OUT_OF_GAS;  // check msg value is enough to pay for the sale

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
                    body: beginCell().storeUint(0, 32).storeSlice("Error, code 44").endCell()
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
    
    if (storage.state != STATE_ACTIVE) {
        throw EXC_DEAL_NOT_ACTIVE;
    }
    
    // Allow anyone to cancel expired sales
    if (blockchain.now() >= storage.validUntil) {
        var opCode: uint32 = in.body.loadUint(32);
        if (opCode != OP_CANCEL_DEAL) {
            throw EXC_UNSUPPORTED_OP;
        }
        
        acceptExternalMessage();
        cancelDeal(mutate storage, in.body.loadUint(64));
        
        return;
    }
    
    throw 0xfffe;
}

// Get contract storage data for external queries
get fun get_storage_data() {
    var storage: Storage = Storage.load();
    
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

//
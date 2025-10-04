import "../imports/messages"
import "../imports/types"
import "../imports/constants"
import "../imports/dns"
import "../imports/utils"
import "storage"
import "utils"
import "@stdlib/tvm-dicts"
import "@stdlib/tvm-lowlevel"
import "types"
import "constants"


@inline
fun handleSimpleDeploy(
    storage: MarketplaceStorage,
    op: int,
    queryId: uint64,
    payload: slice,
    fromAddress: address,
    msgValue: coins
): void {
    var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, op, DEPLOY_SIMPLE);
    var commissionDiscount: uint16 = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
    
    // Create arguments of deploy function
    val args = SimpleDeployArgs {
        fromAddress: fromAddress,
        payloadSlice: payload,
        deployInfoSlice: deployInfo.specificInfo,
        code: deployInfo.dealCode,
        commissionDiscount: commissionDiscount,
        queryId: queryId,
        publicKey: storage.publicKey,
        contractCodes: storage.contractCodes
    };

    // Extract deploy function code from deploy info and execute it
    val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
    val requiredGas: coins = deployInfo.deployFee + executeDeploySimple(deployFunctionContinuation, args);
    checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

    // Update collected fees
    storage.collectedFeesTon += deployInfo.deployFee;
    storage.save();

    return;
}


@inline
fun handleNftOwnershipAssigned(
    storage: MarketplaceStorage,
    msgValue: coins,
    queryId: uint64,
    inMsgBody: slice,
    nftAddress: address
): void {
    val fromAddress: address = inMsgBody.loadAddress();

    try {
        var payload: slice = inMsgBody.loadBool() ? inMsgBody.loadRef().beginParse() : inMsgBody;
        val innerOp: int = payload.loadUint(32);

        if (innerOp < 0x0fffffff) {  // innerOp is a deal identificator 

            val domainNameCell: cell = payload.loadRef();  // Domain name is used for onchain notifications  
            var domainNameSlice: slice = domainNameCell.beginParse();
            val isTgUsername: bool = domainNameSlice.getLastBits(5 * 8).bitsEqual(".t.me");
            val contractCodes: ContractCodes = lazy storage.contractCodes.load();
            var domainAddressBuilder: builder;
            if (isTgUsername) {
                domainAddressBuilder = tgUsernameToAddress(domainNameSlice.removeLastBits(5 * 8), contractCodes.tgUsernameCode);
            } else {
                domainAddressBuilder = domainNameToAddress(domainNameSlice.removeLastBits(4 * 8), contractCodes.domainCode);
            }
            val domainAddress: address = domainAddressBuilder.endCell().beginParse() as address;
            assert(domainAddress == nftAddress) throw EXC_INCORRECT_SENDER;  // Validate provided domain name by comparing calculated address with the real one
            
            var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, innerOp, DEPLOY_WITH_NFT_TRANSFER);
            var commissionDiscount = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
           
            // Create arguments of deploy function
            val args = DeployWithNftTransferArgs {
                commonArgs: SimpleDeployArgs {
                    fromAddress: fromAddress,
                    payloadSlice: payload,
                    deployInfoSlice: deployInfo.specificInfo,
                    code: deployInfo.dealCode,
                    commissionDiscount: commissionDiscount,
                    queryId: queryId,
                    publicKey: storage.publicKey,
                    contractCodes: storage.contractCodes
                },
                domainAddress: domainAddress,
                domainNameCell: domainNameCell as Cell<SerializableSlice>
            };

            // Extract deploy function code from deploy info and execute it
            val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
            val requiredGas: coins = deployInfo.deployFee + executeDeployWithNftTransfer(deployFunctionContinuation, args);
            checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

            // Update collected fees
            storage.collectedFeesTon += deployInfo.deployFee;
            storage.save();
            
            return;
        }
        
        throw EXC_UNSUPPORTED_OP;
    } catch (e, _) {
        // Return NFT on error
        createMessage({
            bounce: false,
            value: 0,
            dest: nftAddress,
            body: NftTransferMessage<cell> {
                queryId: 0,
                toAddress: fromAddress,
                responseAddress: fromAddress,
                forwardTonAmount: 1,
                forwardPayload: beginCell()
                    .storeUint(0, 32)
                    .storeSlice("Error, code ")
                    .storeNumber10(e)
                .endCell()
            }
        }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
        commitContractDataAndActions();
        throw e;
    }
}

@inline
fun handleJettonsTransferNotification(
    storage: MarketplaceStorage,
    msgValue: coins,
    queryId: uint64,
    inMsgBody: slice,
    jettonWalletAddress: address
): void {
    val transferredJettons: coins = inMsgBody.loadCoins();
    val fromAddress: address = inMsgBody.loadAddress();

    try {
        var payload: slice = inMsgBody.loadBool() ? inMsgBody.loadRef().beginParse() : inMsgBody;
        val innerOp: int = payload.loadUint(32);
        
        if (payload.bitsEqual("Marketplace commission")) {  
            // Accept collected fees
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.save();
            return;
        }
        
        if ((innerOp == OP_MAKE_HOT) || (innerOp == OP_MAKE_COLORED)) {
            // Handle hot or colored promotion
            val ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
            assert(jettonWalletAddress == ds2.web3WalletAddress) throw EXC_INCORRECT_SENDER;  // Purchasing promotions are only available for WEB3
            
            val saleAddress: address = payload.loadAddress();  // Address of the deal to be promoted
            val promotionPeriod: uint32 = payload.loadUint(32);     // Period of the promotion
            
            var (priceInfo: slice?, found: bool) = ds2.promotionPrices.uDictGet(32, promotionPeriod);  // Get the price of the promotion
            assert(found) throw EXC_INCORRECT_VALID_UNTIL;
            
            val hotPrice: uint64 = priceInfo!.loadUint(64);       // Price of the hot promotion
            val coloredPrice: uint64 = priceInfo!.loadUint(64);   // Price of the colored promotion
            
            val expectedPrice: uint64 = (innerOp == OP_MAKE_HOT) ? hotPrice : coloredPrice;
            assert(expectedPrice == transferredJettons) throw EXC_NOT_ENOUGH_JETTONS;  // Check that the amount of transferred jettons is correct

            // Update collected fees
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.save();
            
            // Send message to the deal to be promoted
            createMessage({
                bounce: false,
                value: 0,
                dest: saleAddress,
                body:  beginCell()
                        .storeUint(innerOp, 32)
                        .storeUint(queryId, 64)
                        .storeUint(blockchain.now() + promotionPeriod, 32)
                    .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
            return;
        }

        if (innerOp == OP_MOVE_UP_SALE) {
            val ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
            assert(jettonWalletAddress == ds2.web3WalletAddress) throw EXC_INCORRECT_SENDER;     // Move up sale is only available for WEB3
            assert(transferredJettons == storage.moveUpSalePrice) throw EXC_NOT_ENOUGH_JETTONS;  // Check that the amount of transferred jettons is correct

            // Update collected fees and top sale address
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.currentTopSale = payload.loadAddress();
            storage.save();

            // Send excess
            createMessage({
                bounce: false,
                value: 0,
                dest: fromAddress,
                body: ExcessesMessage {queryId: queryId}
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);

            return;
        }
        
        // Deploy with jetton transfer
        if (innerOp < 0x0fffffff) {  // innerOp is a deal identificator
            val ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
            var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, innerOp, DEPLOY_WITH_JETTON_TRANSFER);
            var commissionDiscount: uint16 = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
           
            // Arguments of deploy function
            val args = DeployWithJettonTransferArgs {
                commonArgs: SimpleDeployArgs {
                    fromAddress: fromAddress,
                    payloadSlice: payload,
                    deployInfoSlice: deployInfo.specificInfo,
                    code: deployInfo.dealCode,
                    commissionDiscount: commissionDiscount,
                    queryId: queryId,
                    publicKey: storage.publicKey,
                    contractCodes: storage.contractCodes
                },
                transferredJettons: transferredJettons,
                jettonWalletAddress: jettonWalletAddress,
                isWeb3: jettonWalletAddress == ds2.web3WalletAddress
            };

            // Extract deploy function code from deploy info and execute it
            val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
            val requiredGas: coins = deployInfo.deployFee + executeDeployWithJettonTransfer(deployFunctionContinuation, args);
            checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

            // Update collected fees
            storage.collectedFeesTon += deployInfo.deployFee;
            storage.save();
            
            return;
        }
        
        throw EXC_UNSUPPORTED_OP;
    } catch (e, _) {
        // Return jettons on error
        createMessage({
            bounce: true,
            value: 0,
            dest: jettonWalletAddress,
            body: SendJettonsMessage<cell> {
                queryId: queryId,
                jettonAmount: transferredJettons,
                toAddress: fromAddress,
                responseAddress: fromAddress,
                customPayload: null,
                forwardTonAmount: 1,
                forwardPayload: beginCell()
                                .storeUint(0, 32)
                                .storeSlice("Error. Code ")
                                .storeNumber10(e)
                            .endCell()
            }
        }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        
        commitContractDataAndActions();
        throw e;
    }
}


fun handleBuySubscription(storage: MarketplaceStorage, msgBody: slice, msgValue: coins, senderAddress: address): void {
    val subscriptionLevel: uint8 = msgBody.loadUint(8);
    val subscriptionPeriod: uint32 = msgBody.loadUint(32);

    var ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
    var (subscriptionInfoSlice: slice?, found: bool) = ds2.subscriptionsInfo.uDictGet(8, subscriptionLevel);
    assert(found) throw EXC_INCORRECT_SUBSCRIPTION_LEVEL;

    val subscriptionInfoCell: dict = subscriptionInfoSlice!.loadDict();
    var (subscriptionPriceSlice: slice?, found2: bool) = subscriptionInfoCell.uDictGet(32, subscriptionPeriod);
    assert(found2) throw EXC_INCORRECT_SUBSCRIPTION_PERIOD;
    val subscriptionPrice: uint64 = subscriptionPriceSlice!.loadUint(64);
    assert(subscriptionPrice <= msgValue) throw EXC_OUT_OF_GAS;

    var (userSubscriptionSlice: slice?, found3: bool) = ds2.userSubscriptions.sDictGet(267, senderAddress as slice);
    var userSubscriptionEndTime: uint32 = 0;
    if (found3 && userSubscriptionSlice!.loadUint(8) == subscriptionLevel) {  
        // Extend user subscription if it already exists
        userSubscriptionEndTime = max(userSubscriptionSlice!.loadUint(32), blockchain.now()) + subscriptionPeriod;
    }
    else {
        userSubscriptionEndTime = blockchain.now() + subscriptionPeriod;
    }
    
    // Save user subscription info in storage 
    ds2.userSubscriptions.sDictSetBuilder(267, senderAddress as slice, beginCell().storeUint(subscriptionLevel, 8).storeUint(userSubscriptionEndTime, 32));
    storage.ds2 = ds2.toCell();
    storage.collectedFeesTon += subscriptionPrice;
    storage.save();

    return;
}



fun handleRenewalFee(storage: MarketplaceStorage, msgBody: slice, msgValue: coins, queryId: uint64): void {
    assert(msgValue > ton("0.003")) throw 0;

    var excess: coins = msgValue - TONS_RENEW_REQUEST;
    if (excess > TONS_MIN_EXCESS) {  // Send excess if attached TON exceeds renewal fee
        val ownerAddress: address = msgBody.loadAddress();
        createMessage({
            bounce: false,
            value: 0,
            dest: ownerAddress,
            body: ExcessesMessage {queryId: queryId}
        }).send(SEND_MODE_REGULAR);
    };

    // Update collected fees
    storage.collectedFeesTon += min(TONS_RENEW_REQUEST, msgValue) - ton("0.003");
    storage.save();

    return;
}

fun handleTonMarketplaceCommission(storage: MarketplaceStorage, msgBody: slice, msgValue: coins): void {
    // Just accept TONs if comment is "Marketplace commission". Other comments are not allowed. 
    assert(msgBody.bitsEqual("Marketplace commission")) throw EXC_UNSUPPORTED_OP;
    assert(msgValue > ton("0.003")) throw 0;
    storage.collectedFeesTon += msgValue - ton("0.003");
    storage.save();
}


fun handleUpdateDeployInfo(storage: MarketplaceStorage, msgBody: slice, senderAddress: address): void {
    // DeployInfos is a huge dict (because it stores all deals codes), so we support partial update of it
    assert(senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;

    var updatesDict: dict = msgBody.loadDict();  // dealIdentificator (uint32) -> deployInfo
    var (keyOp: int?, deployInfoSlice: slice?, found: bool) = updatesDict.uDictGetFirst(32);
    while (found) {
        storage.deployInfos.uDictSet(32, keyOp!, deployInfoSlice!);
        (keyOp, deployInfoSlice, found) = updatesDict.uDictGetNext(32, keyOp!);
    }
    storage.save();

    // Send excess
    createMessage({
        bounce: false,
        value: 0,
        dest: ADMIN_ADDRESS,
        body: ExcessesMessage {queryId: 0}
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

fun handleSetSubscriptions(storage: MarketplaceStorage, msgBody: slice, senderAddress: address): void {
    // Allow admin to set new user subscriptions (e.g. for giveaways) 
    assert(senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;

    var ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
    ds2.userSubscriptions = msgBody.loadDict();  // userAddress -> subscriptionInfo
    storage.ds2 = ds2.toCell();
    storage.save();

    // Send excess
    createMessage({
        bounce: false,
        value: 0,
        dest: ADMIN_ADDRESS,
        body: ExcessesMessage {queryId: 0}
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}


fun handleChangeMoveUpPrice(storage: MarketplaceStorage, msgBody: slice, senderAddress: address): void {
    assert(senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
    storage.moveUpSalePrice = msgBody.loadCoins();
    storage.save(); 

    // Send excess
    createMessage({
        bounce: false,
        value: 0,
        dest: ADMIN_ADDRESS,
        body: ExcessesMessage {queryId: 0}
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

fun handleChangePromotionPrice(storage: MarketplaceStorage, msgBody: slice, senderAddress: address): void {
    assert(senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
    var ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
    ds2.promotionPrices = msgBody.loadDict();
    storage.ds2 = ds2.toCell();
    storage.save();

    // Send excess
    createMessage({
        bounce: false,
        value: 0,
        dest: ADMIN_ADDRESS,
        body: ExcessesMessage {queryId: 0}
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);

}
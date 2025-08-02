import "../imports/messages"
import "../imports/types"
import "../imports/constants"
import "../imports/admin_message"
import "../imports/dns"
import "../imports/utils"
import "storage"
import "utils"
import "@stdlib/tvm-dicts"
import "@stdlib/tvm-lowlevel"
import "types"
import "constants"



fun handleSimpleDeploy(
    storage: MarketplaceStorage,
    op: int,
    queryId: uint64,
    payload: slice,
    fromAddress: address,
    msgValue: coins
): void {
    var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, op, DEPLOY_SIMPLE);
    var commissionDiscount = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
    
    // arguments for deploy function
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

    // deploy function continuation
    val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
    val requiredGas: coins = deployInfo.deployFee + executeDeploySimple(deployFunctionContinuation, args);
    checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

    storage.collectedFeesTon += deployInfo.deployFee;
    storage.save();
}

@inline
fun handleNftOwnershipAssigned(
    storage: MarketplaceStorage,
    msgValue: coins,
    queryId: uint64,
    inMsgBody: slice,
    nftAddress: address
): void {
    val fromAddress = inMsgBody.loadAddress();

    try {
        var payload = inMsgBody.loadBool() ? inMsgBody.loadRef().beginParse() : inMsgBody;
        val innerOp: int = payload.loadUint(32);
        if (innerOp < 0x0fffffff) {
            val domainNameCell: cell = payload.loadRef();
            val domainNameSlice: slice = domainNameCell.beginParse();
            val isTgUsername = domainNameSlice.getLastBits(5 * 8).bitsEqual(".t.me");
            val contractCodes = lazy storage.contractCodes.load();
            var domainAddressBuilder: builder;
            if (isTgUsername) {
                domainAddressBuilder = tgUsernameToAddress(domainNameSlice.getFirstBits(domainNameSlice.remainingBitsCount() - 5 * 8), contractCodes.tgUsernameCode);
            } else {
                domainAddressBuilder = domainNameToAddress(domainNameSlice.getFirstBits(domainNameSlice.remainingBitsCount() - 4 * 8), contractCodes.domainCode);
            }
            val domainAddress = domainAddressBuilder.endCell().beginParse() as address;
            assert(domainAddress == nftAddress) throw EXC_INCORRECT_SENDER;
            
            val ds2 = lazy storage.ds2.load();
            var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, innerOp, DEPLOY_WITH_NFT_TRANSFER);
            var commissionDiscount = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
           
            // arguments for deploy function
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

            // deploy function continuation
            val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
            val requiredGas: coins = deployInfo.deployFee + executeDeployWithNftTransfer(deployFunctionContinuation, args);
            checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

            storage.collectedFeesTon += deployInfo.deployFee;
            storage.save();
            
            return;
        }
        
        throw EXC_UNSUPPORTED_OP;
    } catch (e, _) {
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
        }).send(SEND_MODE_CARRY_ALL_BALANCE);
            
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
    val transferredJettons = inMsgBody.loadCoins();
    val fromAddress = inMsgBody.loadAddress();

    try {
        var payload = inMsgBody.loadBool() ? inMsgBody.loadRef().beginParse() : inMsgBody;
        val innerOp: int = payload.loadUint(32);
        
        if (payload.bitsEqual("Marketplace commission")) {
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.save();
            return;
        }
        
        if ((innerOp == OP_MAKE_HOT) || (innerOp == OP_MAKE_COLORED)) {
            val ds2 = lazy storage.ds2.load();
            assert(jettonWalletAddress == ds2.web3WalletAddress) throw EXC_INCORRECT_SENDER;
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            
            val saleAddress = payload.loadAddress();
            val period = payload.loadUint(32);
            
            var (priceInfo, found) = ds2.promotionPrices.uDictGet(32, period);
            assert(found) throw EXC_INCORRECT_VALID_UNTIL;
            
            val hotPrice = priceInfo!.loadUint(64);
            val coloredPrice = priceInfo!.loadUint(64);
            
            val expectedPrice = (innerOp == OP_MAKE_HOT) ? hotPrice : coloredPrice;
            assert(expectedPrice == transferredJettons) throw EXC_NOT_ENOUGH_JETTONS;
                
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: saleAddress,
                body:  beginCell()
                        .storeUint(innerOp, 32)
                        .storeUint(queryId, 64)
                        .storeUint(blockchain.now() + period, 32)
                    .endCell()
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
            storage.ds2 = ds2.toCell();
            storage.save();
            return;
        }

        if (innerOp == OP_MOVE_UP_SALE) {
            val ds2 = lazy storage.ds2.load();
            assert(jettonWalletAddress == ds2.web3WalletAddress) throw EXC_INCORRECT_SENDER;
            assert(transferredJettons == storage.moveUpSalePrice) throw EXC_NOT_ENOUGH_JETTONS;

            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.currentTopSale = payload.loadAddress();
            storage.save();

            createMessage({
                bounce: false,
                value: 0,
                dest: fromAddress,
                body: ExcessesMessage {queryId: queryId}
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);

            return;
        }
        
        // deploy with jetton transfer
        if (innerOp < 0x0fffffff) {
            val ds2 = lazy storage.ds2.load();
            var deployInfo: DeployInfo<SerializableSlice> = parseDeployInfo(storage, innerOp, DEPLOY_WITH_JETTON_TRANSFER);
            var commissionDiscount = getCommissionDiscount(payload.loadMaybeRef(), fromAddress, storage.publicKey);
           
            // arguments for deploy function
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

            // deploy function continuation
            val deployFunctionContinuation: continuation = transformSliceToContinuation(deployInfo.deployFunctionCode.beginParse());
            val requiredGas: coins = deployInfo.deployFee + executeDeployWithJettonTransfer(deployFunctionContinuation, args);
            checkEnoughGas(msgValue, requiredGas, fromAddress, queryId);

            storage.collectedFeesTon += deployInfo.deployFee;
            storage.save();
            
            return;
        }
        
        throw EXC_UNSUPPORTED_OP;
    } catch (e, _) {
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
    val subscriptionLevel = msgBody.loadUint(8);
    val subscriptionPeriod = msgBody.loadUint(32);

    var ds2 = lazy storage.ds2.load();
    var (subscriptionInfoSlice, found) = ds2.subscriptionsInfo.uDictGet(8, subscriptionLevel);
    assert(found) throw EXC_INCORRECT_SUBSCRIPTION_LEVEL;

    val subscriptionInfoCell = subscriptionInfoSlice!.loadDict();
    var (subscriptionPriceSlice, found2) = subscriptionInfoCell.uDictGet(32, subscriptionPeriod);
    assert(found2) throw EXC_INCORRECT_SUBSCRIPTION_PERIOD;
    val subscriptionPrice = subscriptionPriceSlice!.loadUint(64);
    assert(subscriptionPrice <= msgValue) throw EXC_OUT_OF_GAS;

    var (userSubscriptionSlice, found3) = ds2.userSubscriptions.sDictGet(267, senderAddress as slice);
    var userSubscriptionEndTime = 0;
    if (found3 && userSubscriptionSlice!.loadUint(8) == subscriptionLevel) {
        userSubscriptionEndTime = max(userSubscriptionSlice!.loadUint(32), blockchain.now()) + subscriptionPeriod;
    }
    else {
        userSubscriptionEndTime = blockchain.now() + subscriptionPeriod;
    }
    
    ds2.userSubscriptions.sDictSetBuilder(267, senderAddress as slice, beginCell().storeUint(subscriptionLevel, 8).storeUint(userSubscriptionEndTime, 32));
    storage.ds2 = ds2.toCell();
    storage.collectedFeesTon += subscriptionPrice;
    storage.save();
    return;
}


fun handleRenewalFee(storage: MarketplaceStorage, msgBody: slice, msgValue: coins, queryId: uint64): void {
    var excess: coins = msgValue - TONS_RENEW_REQUEST;
    if (excess > TONS_MIN_EXCESS) {
        val ownerAddress = msgBody.loadAddress();
        createMessage({
            bounce: false,
            value: 0,
            dest: ownerAddress,
            body: ExcessesMessage {queryId: queryId}
        }).send(excess);
    };
    storage.collectedFeesTon += min(TONS_RENEW_REQUEST, msgValue) - ton("0.003");
    storage.save();
    return;
}

fun handleTonMarketplaceCommission(storage: MarketplaceStorage, msgBody: slice, msgValue: coins): void {
    assert(msgBody.bitsEqual("Marketplace commission")) throw EXC_UNSUPPORTED_OP;
    storage.collectedFeesTon += msgValue - 2000000;
    storage.save();
}

fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: true,
        allowChangeData: true,
        allowSendAnyMessage: true
    });

    var op: int = 0;
    var queryId: uint64 = 0;
    if (in.body.remainingBitsCount() > 0) {
        op = in.body.loadUint(32);
        if (op != 0 && in.body.remainingBitsCount() >= 64) {
            queryId = in.body.loadUint(64);
        }
    }
        
    var storage = lazy MarketplaceStorage.load();

    match (op) {
        OP_FILL_UP_BALANCE => {
            return;
        }
        OP_OWNERSHIP_ASSIGNED => {
            handleNftOwnershipAssigned(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        }
        OP_TRANSFER_NOTIFICATION => {
            handleJettonsTransferNotification(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        }
        OP_RENEWAL_FEE => {
            handleRenewalFee(storage, in.body, in.valueCoins, queryId);
        }
        OP_COMMENT => {
            handleTonMarketplaceCommission(storage, in.body, in.valueCoins);
        }
        OP_BUY_SUBSCRIPTION => {
            handleBuySubscription(storage, in.body, in.valueCoins, in.senderAddress);
        }
        else => { // simple deploy
            assert(op < 0x0fffffff) throw EXC_UNSUPPORTED_OP;
            handleSimpleDeploy(storage, op, queryId, in.body, in.senderAddress, in.valueCoins);
            return;
        }
    }
}

get fun get_deploy_info(op: int): (uint2, coins, cell, cell, slice) {
    val storage = lazy MarketplaceStorage.load();
    var (deployInfoSlice, found) = storage.deployInfos.uDictGet(32, op);
    if (!found) {
        throw EXC_UNSUPPORTED_OP;
    }
    var info = DeployInfo<SerializableSlice>.fromSlice(deployInfoSlice!);
    return (info.deployType, info.deployFee, info.dealCode, info.deployFunctionCode, info.specificInfo);
}

get fun get_storage_data() {
    val storage = lazy MarketplaceStorage.load();
    val ds2 = storage.ds2.load();

    return (
        storage.ownerAddress,
        storage.publicKey,
        storage.deployInfos,

        ds2.userSubscriptions,
        ds2.subscriptionsInfo,

        storage.moveUpSalePrice,
        storage.currentTopSale,

        ds2.web3WalletAddress,

        storage.collectedFeesTon,
        storage.collectedFeesDict,
        ds2.promotionPrices
    )   
}
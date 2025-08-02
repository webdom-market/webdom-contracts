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
        
        // Обработка комиссии маркетплейса
        if (payload.bitsEqual("Marketplace commission")) {
            storage.collectedFeesDict = addCollectedFees(storage.collectedFeesDict, jettonWalletAddress, transferredJettons);
            storage.save();
            return;
        }
        
        // Обработка Make Hot/Colored
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
        
        // Обработка deploy операций для jetton
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

fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    // Обработка admin сообщений
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

    if (op == OP_FILL_UP_BALANCE) {
        return;
    }
    
    if (op == OP_OWNERSHIP_ASSIGNED) {
        handleNftOwnershipAssigned(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        return;
    }
    
    if (op == OP_TRANSFER_NOTIFICATION) {
        handleJettonsTransferNotification(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        return;
    }
    
    // Простые deploy операции (без NFT/Jetton transfer)
    if (op < 0x0fffffff) {
        handleSimpleDeploy(storage, op, queryId, in.body, in.senderAddress, in.valueCoins);
        return;
    }
    
    throw EXC_UNSUPPORTED_OP;
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
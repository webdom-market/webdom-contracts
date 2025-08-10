import "../imports/types"
import "../imports/constants"
import "../imports/admin_message"
import "../imports/utils"
import "storage"
import "@stdlib/tvm-dicts"
import "types"
import "constants"
import "message_handlers"


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
            // Deploy new deal with NFT transfer (e.g. ton simple sale)
            handleNftOwnershipAssigned(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        }
        OP_TRANSFER_NOTIFICATION => {
            // Deploy new deal with jetton transfer (e.g. jetton simple offer) / accept commissions in jettons / make promotions  
            handleJettonsTransferNotification(storage, in.valueCoins, queryId, in.body, in.senderAddress);
        }
        OP_RENEWAL_FEE => { 
            // Accept fee for renewing domains
            handleRenewalFee(storage, in.body, in.valueCoins, queryId);
        }
        OP_COMMENT => {
            // Accept commissions in TON
            handleTonMarketplaceCommission(storage, in.body, in.valueCoins);
        }
        OP_BUY_SUBSCRIPTION => {
            // Subscription purchase
            handleBuySubscription(storage, in.body, in.valueCoins, in.senderAddress);
        }
        OP_UPDATE_DEPLOY_INFO => {
            // Update info about available deals (admin command)
            handleUpdateDeployInfo(storage, in.body, in.senderAddress);
        }
        OP_SET_SUBSCRIPTIONS => {
            // Update info about subscription plans (admin command)
            handleSetSubscriptions(storage, in.body, in.senderAddress);
        }
        else => { 
            assert(op < 0x0fffffff) throw EXC_UNSUPPORTED_OP;
            // Simple deploy without jetton or NFT transfers (e.g. ton simple offer, jetton multiple auction)
            handleSimpleDeploy(storage, op, queryId, in.body, in.senderAddress, in.valueCoins);
            return;
        }
    }
}


get fun get_deploy_info(op: int): (uint2, coins, cell, cell, slice) {
    val storage: MarketplaceStorage = lazy MarketplaceStorage.load();
    var (deployInfoSlice: slice?, found: bool) = storage.deployInfos.uDictGet(32, op);
    if (!found) {
        throw EXC_UNSUPPORTED_OP;
    }
    var info = DeployInfo<SerializableSlice>.fromSlice(deployInfoSlice!);
    return (info.deployType, info.deployFee, info.dealCode, info.deployFunctionCode, info.specificInfo);
}


get fun get_storage_data() {
    val storage: MarketplaceStorage = lazy MarketplaceStorage.load();
    val ds2: MarketplaceStorageDs2 = storage.ds2.load();
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
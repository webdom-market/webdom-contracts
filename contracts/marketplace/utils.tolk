import "../imports/types"
import "storage"
import "@stdlib/tvm-dicts"
import "../imports/constants"
import "types"
import "constants"
import "@stdlib/gas-payments"
import "../imports/messages"


// Functions for executing deploy functions with differend arguments
@inline
fun executeDeploySimple(c: continuation, args: SimpleDeployArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithNftTransfer(c: continuation, args: DeployWithNftTransferArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithJettonTransfer(c: continuation, args: DeployWithJettonTransferArgs): coins 
    asm (args c) "EXECUTE";


// Marketplace supports discounts for whitelisted users 
@inline
fun getCommissionDiscount(discountInfoCell: cell?, fromAddress: address, publicKey: uint256): uint16 {
    if (discountInfoCell == null) {
        return 0;
    }
    
    var discountInfo: slice = discountInfoCell!.beginParse();
    var signature: slice = discountInfo.loadRef().beginParse();
    
    assert(
        isSignatureValid(discountInfo.hash(), signature, publicKey) &&   // Check that discountInfo was signed by the marketplace backend
        discountInfo.loadUint(32) + 600 >= blockchain.now() &&           // Check that signature is still valid
        discountInfo.loadAddress() == fromAddress                        // Check that discountInfo is for the current user
    ) throw EXC_INVALID_SIGNATURE;
    
    return discountInfo.loadUint(16);  // Return discount percentage (commission = baseCommission * (COMMISSION_DIVIDER - discount) / COMMISSION_DIVIDER)
}


@inline
fun addCollectedFees(collectedFeesDict: dict, jettonWalletAddress: address, transferredJettons: coins): dict {
    var (collectedFeesSlice: slice?, found: bool) = collectedFeesDict.sDictGet(267, jettonWalletAddress as slice);
    val currentFees: coins = found ? (coins.fromSlice(collectedFeesSlice!)) : (0 as coins);
    
    collectedFeesDict.sDictSetBuilder(
        267, jettonWalletAddress as slice, beginCell().storeCoins(currentFees + transferredJettons)
    );

    return collectedFeesDict;
}


@inline
fun checkEnoughGas(msgValue: coins, requiredGas: coins, fromAddress: address, queryId: uint64): void {
    // Calculate total required TONs accounting compute fees
    val totalRequired = requiredGas + calculateGasFee(WORKCHAIN, getGasConsumedAtTheMoment() + 200);
    if (msgValue - totalRequired >= TONS_MIN_EXCESS) {
        // Send excess
        createMessage({
            bounce: false,
            value: 0,
            dest: fromAddress,
            body: ExcessesMessage { queryId: queryId }
        }).send(SEND_MODE_CARRY_ALL_BALANCE);
        return;
    }
    assert(msgValue >= totalRequired) throw EXC_OUT_OF_GAS;
}


@inline
fun parseDeployInfo(storage: MarketplaceStorage, op: uint32, deployType: uint2): DeployInfo<SerializableSlice> {
    var (deployInfoSlice: slice?, found: bool) = storage.deployInfos.uDictGet(32, op);
    assert(found) throw EXC_UNSUPPORTED_OP;

    var deployInfo = DeployInfo<SerializableSlice>.fromSlice(deployInfoSlice!);
    assert(deployInfo.deployType == deployType) throw EXC_INCORRECT_DEPLOY_TYPE;

    // Reserve deploy fee
    reserveToncoinsOnBalance(deployInfo.deployFee, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);

    return deployInfo;
}

import "../imports/types"
import "storage"
import "@stdlib/tvm-dicts"
import "../imports/constants"
import "types"
import "constants"
import "@stdlib/gas-payments"
import "../imports/messages"


@inline
fun executeDeploySimple(c: continuation, args: SimpleDeployArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithNftTransfer(c: continuation, args: DeployWithNftTransferArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithJettonTransfer(c: continuation, args: DeployWithJettonTransferArgs): coins 
    asm (args c) "EXECUTE";


fun getCommissionDiscount(subscriptionInfoCell: cell?, fromAddress: address, publicKey: uint256): uint16 {
    if (subscriptionInfoCell == null) {
        return 0;
    }
    
    var subscriptionInfo = subscriptionInfoCell!.beginParse();
    var signature = subscriptionInfo.loadRef().beginParse();
    
    assert(
        isSignatureValid(subscriptionInfo.hash(), signature, publicKey) &&
        subscriptionInfo.loadUint(32) + 600 >= blockchain.now() && 
        subscriptionInfo.loadAddress() == fromAddress
    ) throw EXC_INVALID_SIGNATURE;
    
    return subscriptionInfo.loadUint(16);
}

@inline
fun addCollectedFees(collectedFeesDict: dict, senderAddress: address, transferredJettons: coins): dict {
    var (collectedFeesSlice, found) = collectedFeesDict.sDictGet(267, senderAddress as slice);
    val currentFees = found ? coins.fromSlice(collectedFeesSlice!) : 0 as coins;
    
    collectedFeesDict.sDictSetBuilder(
        267, senderAddress as slice, beginCell().storeCoins(currentFees + transferredJettons)
    );

    return collectedFeesDict;
}

@inline
fun checkEnoughGas(msgValue: coins, requiredGas: coins, fromAddress: address, queryId: uint64): void {
    val totalRequired = requiredGas + calculateGasFee(WORKCHAIN, getGasConsumedAtTheMoment() + 200);
    if (msgValue - totalRequired >= TONS_MIN_EXCESS) {
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
    var (deployInfoSlice, found) = storage.deployInfos.uDictGet(32, op);
    assert(found) throw EXC_UNSUPPORTED_OP;
    var deployInfo = DeployInfo<SerializableSlice>.fromSlice(deployInfoSlice!);
    assert(deployInfo.deployType == deployType) throw EXC_INCORRECT_DEPLOY_TYPE;
    reserveToncoinsOnBalance(deployInfo.deployFee, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);
    return deployInfo;
}

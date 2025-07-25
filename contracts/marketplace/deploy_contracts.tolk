import "../imports/types"

struct DeployInfo<T> {
    dealCode: cell;
    deployFee: coins;
    specificInfo: T;
}

struct SimpleDeployArgs {
    fromAddress: address;
    payloadSlice: slice;
    deployInfoSlice: slice;
    code: cell;
    commissionDiscount: uint16;
    queryId: uint64;
    publicKey: uint256;
}

struct DeployWithNftTransferArgs {
    commonArgs: SimpleDeployArgs;
    domainAddress: address;
    domainName: SerializableSlice;
}

struct DeployWithJettonTransferArgs {
    commonArgs: SimpleDeployArgs;
    isWeb3: bool;
}

fun executeSimpleDeploy<T>(c: continuation, args: T): void 
    asm (args c) "EXECUTE";



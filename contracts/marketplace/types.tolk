import "../imports/types"

struct ContractCodes {
    domainCode: cell;
    tgUsernameCode: cell;
    web3WalletCode: cell;
    usdtWalletCode: cell;
}

struct DeployInfo<T> {
    deployType: uint2;
    deployFee: coins;
    dealCode: cell;
    deployFunctionCode: cell;
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
    contractCodes: Cell<ContractCodes>;
}

struct DeployWithNftTransferArgs {
    commonArgs: SimpleDeployArgs;
    domainAddress: address;
    domainNameCell: Cell<SerializableSlice>;
}

struct DeployWithJettonTransferArgs {
    commonArgs: SimpleDeployArgs;
    jettonWalletAddress: address;
    transferredJettons: coins;
    isWeb3: bool;
}

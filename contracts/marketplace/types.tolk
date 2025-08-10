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
    fromAddress: address;                   // Sender address
    payloadSlice: slice;                    // Sender's message
    deployInfoSlice: slice;                 // Deploy info slice
    code: cell;                             // Code of the deal
    commissionDiscount: uint16;             // Discount size for the sender
    queryId: uint64;
    publicKey: uint256;                    
    contractCodes: Cell<ContractCodes>;     // Codes for calculating jetton wallets addresses and domains addresses
}

struct DeployWithNftTransferArgs {
    commonArgs: SimpleDeployArgs;
    domainAddress: address;                  
    domainNameCell: Cell<SerializableSlice>;  // Domain name is used for onchain notifications
}

struct DeployWithJettonTransferArgs {
    commonArgs: SimpleDeployArgs;
    jettonWalletAddress: address;
    transferredJettons: coins;
    isWeb3: bool;
}

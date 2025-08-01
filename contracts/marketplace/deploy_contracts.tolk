import "../imports/types"

const EXC_PRICE_TOO_LOW            = 70;
const EXC_EMPTY_DICT               = 71;
const EXC_INCORRECT_TIME_RANGE     = 72;
const EXC_INCORRECT_BID_INCREMENT  = 73;
const EXC_INCORRECT_TIME_INCREMENT = 74;

struct DeployInfo<T> {
    dealCode: cell;
    deployFee: coins;
    specificInfo: T;
}

struct ContractCodes {
    domainCode: cell;
    tgUsernameCode: cell;
    web3WalletCode: cell;
    usdtWalletCode: cell;
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
    isWeb3: bool;
}

fun executeSimpleDeploy<T>(c: continuation, args: T): void 
    asm (args c) "EXECUTE";



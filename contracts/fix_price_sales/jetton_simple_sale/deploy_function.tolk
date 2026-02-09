import "../../imports/utils";
import "../../imports/constants";
import "../../marketplace/types";
import "../../marketplace/constants";
import "../../imports/types";
import "../constants";
import "storage";
import "../../imports/messages";
import "constants";


struct DeployInfoForJetton {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct JettonSimpleSaleDeployInfo {
    usdtInfo: DeployInfoForJetton;
    web3Info: Cell<DeployInfoForJetton>;
}

struct JettonSimpleSaleDeployPayload {
    isWeb3: bool;
    price: coins;
    validUntil: uint32;
    autoRenewCooldown: uint32;
    autoRenewIterations: uint8;
}

const TONS_DEPLOY_JETTON_SIMPLE_SALE = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");

fun deployJettonSimpleSale(args: DeployWithNftTransferArgs): int {
    var payloadSlice = args.commonArgs.payloadSlice;
    var payload = JettonSimpleSaleDeployPayload {
        isWeb3: payloadSlice.loadBool(),
        price: payloadSlice.loadCoins(),
        validUntil: payloadSlice.loadUint(32),
        autoRenewCooldown: ONE_YEAR - ONE_DAY,
        autoRenewIterations: 0
    };
    if (payloadSlice.remainingBitsCount() > 0) {
        payload.autoRenewCooldown = payloadSlice.loadUint(32);
        payload.autoRenewIterations = payloadSlice.loadUint(8);
    }
    var deployInfo: DeployInfoForJetton;
    if (payload.isWeb3) {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
        if (args.commonArgs.commissionDiscount != 0) {
            args.commonArgs.commissionDiscount = COMMISSION_DIVIDER;
        }
    } else {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
    }
    
    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert(payload.validUntil >= blockchain.now() + deployInfo.minDuration &&
           (payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY || payload.autoRenewIterations > 0)) throw(EXC_INCORRECT_VALID_UNTIL);
    assert((payload.autoRenewCooldown >= ONE_DAY) && (payload.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_VALID_UNTIL);

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);
    val autoRenewReserve: coins = TONS_AUTORENEW_LOCK_PER_ITER * payload.autoRenewIterations;
    val autoRenewPrepay: coins = TONS_AUTORENEW_MARKETPLACE_FEE * payload.autoRenewIterations;

    val data = (Storage {
        jettonWalletAddress: createAddressNone(),
        sellerAddress: args.commonArgs.fromAddress,
        price: payload.price,
        state: STATE_UNINIT,
        commission: commission,
        createdAt: blockchain.now(),
        lastRenewalTime: blockchain.now(),
        validUntil: payload.validUntil,
        domainNameCell: args.domainNameCell,
        isTgUsername: false,
        hotUntil: 0,
        coloredUntil: 0,
        ds2: (StorageDs2 {
            domainAddress: args.domainAddress,
            jettonMinterAddress: payload.isWeb3 ? WEB3_ADDRESS : USDT_ADDRESS,
            buyerAddress: createAddressNone(),
            autoRenewCooldown: payload.autoRenewCooldown,
            autoRenewIterations: payload.autoRenewIterations,
        }).toCell(),
    }).toCell();
              
    val saleAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.commonArgs.code,
            data: data,
        }
    };
    val saleAddressBuilder = saleAddress.buildAddress();

    // Transfer NFT to the sale contract
    createMessage({
        bounce: false,
        value: TONS_NFT_TRANSFER,
        dest: args.domainAddress,
        body: NftTransferMessageBuilder<CommentMessage> {
            queryId: 0,
            toAddress: saleAddressBuilder,
            responseAddress: createAddressNone(),
            forwardTonAmount: 0,
            forwardPayload: CommentMessage { comment: "Sale on webdom.market" }
        }
    }).send(SEND_MODE_REGULAR);

    // Deploy sale contract
    val contractCodes = lazy args.commonArgs.contractCodes.load();
    val msg = createMessage<cell>({
        bounce: false,
        value: TONS_DEPLOY_JETTON_SIMPLE_SALE + autoRenewReserve + autoRenewPrepay,
        dest: saleAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    payload.isWeb3 ?
                        calculateWeb3WalletAddress(saleAddressBuilder, contractCodes.web3WalletCode) : 
                        calculateUsdtWalletAddress(saleAddressBuilder, contractCodes.usdtWalletCode))
                .endCell()
    }); 

    val requiredGas: coins = TONS_NFT_TRANSFER
                             + TONS_DEPLOY_JETTON_SIMPLE_SALE
                             + autoRenewReserve
                             + autoRenewPrepay  // не учитывается в collected fees но в целом это не критично
                             + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
    
    return requiredGas;
} 

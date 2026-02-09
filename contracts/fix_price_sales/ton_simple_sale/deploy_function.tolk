import "../../imports/constants";
import "../../marketplace/types";
import "../../marketplace/constants";
import "../constants";
import "storage";
import "../../imports/messages";
import "constants";

struct TonSimpleSaleDeployInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct TonSimpleSaleDeployPayload {
    price: coins;
    validUntil: uint32;
    autoRenewCooldown: uint32;
    autoRenewIterations: uint8;
}

const TONS_DEPLOY_TON_SIMPLE_SALE = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");

fun deployTonSimpleSale(args: DeployWithNftTransferArgs): int {
    var deployInfo = TonSimpleSaleDeployInfo.fromSlice(args.commonArgs.deployInfoSlice);
    var payloadSlice = args.commonArgs.payloadSlice;
    var payload = TonSimpleSaleDeployPayload {
        price: payloadSlice.loadCoins(),
        validUntil: payloadSlice.loadUint(32),
        autoRenewCooldown: ONE_YEAR - ONE_DAY,
        autoRenewIterations: 0
    };
    if (payloadSlice.remainingBitsCount() > 0) {
        payload.autoRenewCooldown = payloadSlice.loadUint(32);
        payload.autoRenewIterations = payloadSlice.loadUint(8);
    }
    
    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    // todo для тг юзерок разрешать validUntil большой
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
        domainAddress: args.domainAddress,
        sellerAddress: args.commonArgs.fromAddress,
        price: payload.price,
        state: STATE_UNINIT,
        commission: commission,
        createdAt: blockchain.now(),
        lastRenewalTime: blockchain.now(),
        validUntil: payload.validUntil,
        buyerAddressCell: null,
        domainNameCell: args.domainNameCell,
        isTgUsername: false,
        hotUntil: 0,
        coloredUntil: 0,
        autoRenewData: (AutoRenewData {
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
    val msg = createMessage<FillUpBalanceMessage>({
        bounce: false,
        value: TONS_DEPLOY_TON_SIMPLE_SALE + autoRenewReserve + autoRenewPrepay,
        dest: saleAddress,
        body: FillUpBalanceMessage { queryId: args.commonArgs.queryId }
    });

    val requiredGas: coins = TONS_DEPLOY_TON_SIMPLE_SALE
                             + autoRenewReserve
                             + autoRenewPrepay  // не учитывается в collected fees но в целом это не критично
                             + TONS_NFT_TRANSFER
                             + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
    
    return requiredGas;
} 

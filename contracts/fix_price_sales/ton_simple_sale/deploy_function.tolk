import "../../imports/constants";
import "../../imports/gas";
import "../../imports/utils";
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

// Sale-contract funding at deploy: enough to transfer the domain out later (nftTransferFee) + the
// sale's own one-year storage rent (computed) + the activation handler's compute (computed). The
// DOMAIN's own year of storage is funded separately, in the deposit transfer below (domainRefillFee).
@inline
fun deployTonSimpleSaleValue(): coins {
    return nftTransferFee() + saleStorageReserve(ONE_YEAR) + gasFee(GAS_SALE_DEPLOY);
}

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
    
    val isTgUsername: bool = checkTgUsername(args.domainNameCell);
    assert(payload.validUntil >= blockchain.now() + deployInfo.minDuration) throw EXC_INCORRECT_VALID_UNTIL;
    if (!isTgUsername) {
        val maxValidUntil = blockchain.now() + payload.autoRenewIterations * payload.autoRenewCooldown + ONE_YEAR - ONE_DAY;
        assert(payload.validUntil <= maxValidUntil) throw EXC_INCORRECT_VALID_UNTIL;
    }
    assert((payload.autoRenewCooldown >= ONE_DAY) && (payload.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_VALID_UNTIL);

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);
    val autoRenewReserve: coins = autoRenewLockPerIter(payload.autoRenewCooldown) * payload.autoRenewIterations;
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
        isTgUsername: isTgUsername,
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

    // Transfer NFT to the sale contract. responseAddress is addr_none and forwardTonAmount is 0, so
    // the domain item RETAINS the whole value (it sends nothing back). We send domainRefillFee() =
    // transfer + one year of the item's storage, so the domain holds ~1 TON + a year of rent and can
    // never drain below its min_tons_for_storage reserve for the life of the sale.
    createMessage({
        bounce: false,
        value: domainRefillFee(),
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
        value: deployTonSimpleSaleValue() + autoRenewReserve + autoRenewPrepay,
        dest: saleAddress,
        body: FillUpBalanceMessage { queryId: args.commonArgs.queryId }
    });

    val requiredGas: coins = deployTonSimpleSaleValue()
                             + autoRenewReserve
                             + autoRenewPrepay  // не учитывается в collected fees но в целом это не критично
                             + domainRefillFee()  // the domain deposit value (transfer + 1yr domain storage)
                             + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
    
    return requiredGas;
} 

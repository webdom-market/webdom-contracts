import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../imports/dns";
import "../../marketplace/types";
import "../../marketplace/constants";
import "../../imports/types";
import "storage";
import "../../imports/messages";
import "../constants";
import "constants";
import "@stdlib/tvm-dicts"

struct TonMultipleSaleDeployInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct TonMultipleSaleDeployPayload {
    domainsAddresses: dict;  // address -> bool
    price: coins;
    validUntil: uint32;
    autoRenewCooldown: uint32;
    autoRenewIterations: uint8;
}

fun deployTonMultipleSale(args: SimpleDeployArgs): int {
    var deployInfo = lazy TonMultipleSaleDeployInfo.fromSlice(args.deployInfoSlice);
    var payloadSlice = args.payloadSlice;
    var payload = TonMultipleSaleDeployPayload {
        domainsAddresses: payloadSlice.loadDict(),
        price: payloadSlice.loadCoins(),
        validUntil: payloadSlice.loadUint(32),
        autoRenewCooldown: ONE_YEAR - ONE_DAY,
        autoRenewIterations: 0
    };
    if (payloadSlice.remainingBitsCount() > 0) {
        payload.autoRenewCooldown = payloadSlice.loadUint(32);
        payload.autoRenewIterations = payloadSlice.loadUint(8);
    }
    
    assert(payload.price >= deployInfo.minPrice) throw EXC_PRICE_TOO_LOW;
    assert((payload.validUntil >= blockchain.now() + deployInfo.minDuration) &&
           (payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY || payload.autoRenewIterations > 0)) throw EXC_INCORRECT_VALID_UNTIL;
    assert((payload.autoRenewCooldown >= ONE_DAY) && (payload.autoRenewCooldown <= ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;

    var commission = mulDivFloor(
        min(mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER), deployInfo.maxCommission),
        COMMISSION_DIVIDER - args.commissionDiscount,
        COMMISSION_DIVIDER
    );

    var domainsTotal: uint8 = 0;
    var (domainAddress, received, found) = payload.domainsAddresses.sDictGetFirst(267);
    while (found) {
        domainsTotal += 1;
        assert(received!.bitsEqual(BIT_FALSE_SLICE())) throw EXC_INCORRECT_DOMAIN;
        (domainAddress, received, found) = payload.domainsAddresses.sDictGetNext(267, domainAddress!);
    }
    assert(domainsTotal > 0) throw EXC_EMPTY_DICT;
    assert(domainsTotal < 128) throw EXC_DICT_OVERFLOW;

    val autoRenewReserve: coins = getAutoRenewLockPerIter(domainsTotal, payload.autoRenewCooldown) * payload.autoRenewIterations;
    val autoRenewPrepay: coins = TONS_AUTORENEW_MARKETPLACE_FEE * payload.autoRenewIterations;

    var data = (Storage {
        sellerAddress: args.fromAddress,
        domainsDict: payload.domainsAddresses,
        domainsTotal: domainsTotal,
        domainsReceived: 0,
        price: payload.price,
        commission: commission,
        state: STATE_UNINIT,
        createdAt: blockchain.now(),
        lastRenewalTime: blockchain.now(),
        validUntil: payload.validUntil,

        buyerAddress: createAddressNone(),
        hotUntil: 0,
        coloredUntil: 0,
        autoRenewData: (AutoRenewData {
            autoRenewCooldown: payload.autoRenewCooldown,
            autoRenewIterations: payload.autoRenewIterations,
        }).toCell(),
    }).toCell();

    val saleAddress = AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    };

    // Pre-fund the sale's own one year of storage rent (price-tracked, scales with domain count).
    // Unused funds are returned to the seller right after sale activation (getTonsToReserve reconciles).
    val msg = createMessage({
        bounce: false,
        value: saleStorageReserve(ONE_YEAR, domainsTotal) + autoRenewReserve + autoRenewPrepay,
        dest: saleAddress,
        body: FillUpBalanceMessage { queryId: args.queryId }
    });

    return saleStorageReserve(ONE_YEAR, domainsTotal)
           + autoRenewReserve
           + autoRenewPrepay  // Marketplace prepay is not included into collected deploy fees intentionally
           + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
} 

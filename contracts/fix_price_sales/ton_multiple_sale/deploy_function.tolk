import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../imports/dns";
import "../../marketplace/deploy_contracts";
import "../../imports/types";
import "storage";
import "../../imports/messages";
import "../constants";
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
}

const TONS_DEPLOY_TON_MULTIPLE_SALE: coins = ton("0.05");

@method_id(106)
fun deployTonMultipleSale(args: SimpleDeployArgs): int {
    var deployInfo = lazy TonMultipleSaleDeployInfo.fromSlice(args.deployInfoSlice);
    var payload = lazy TonMultipleSaleDeployPayload.fromSlice(args.payloadSlice);
    
    assert(payload.price >= deployInfo.minPrice) throw EXC_PRICE_TOO_LOW;
    assert((payload.validUntil >= blockchain.now() + deployInfo.minDuration) && 
           (payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_VALID_UNTIL;

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
        (domainAddress, received, found) = payload.domainsAddresses.sDictGetNext(267, domainAddress);
    }
    assert(domainsTotal > 0) throw EXC_EMPTY_DICT;
    
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
        tonsToReserve: ton("0.035"),
        buyerAddress: createAddressNone(),
        hotUntil: 0,
        coloredUntil: 0
    }).toCell();

    val saleAddress = AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    };

    val msg = createMessage({
        bounce: false,
        value: TONS_DEPLOY_TON_MULTIPLE_SALE,
        dest: saleAddress,
        body: FillUpBalanceMessage { queryId: args.queryId }
    });

    return TONS_DEPLOY_TON_MULTIPLE_SALE + msg.sendAndEstimateFee();
} 
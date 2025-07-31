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

struct TonMultipleAuctionDeployInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minTimeIncrement: uint32;
}

struct TonMultipleAuctionDeployPayload {
    isDeferred: bool;
    startTime: uint32;
    endTime: uint32;
    domainsAddresses: dict;  // address -> bool
    minBidValue: coins;
    maxBidValue: coins;
    minBidIncrement: uint12;
    timeIncrement: uint32;
    tonsToEndAuction: coins;
}

const TONS_DEPLOY_TON_MULTIPLE_AUCTION: coins = ton("0.06");

@method_id(110)
fun deployTonMultipleAuction(args: SimpleDeployArgs): int {
    var payload = lazy TonMultipleAuctionDeployPayload.fromSlice(args.payloadSlice);
    var deployInfo = lazy TonMultipleAuctionDeployInfo.fromSlice(args.commonArgs.deployInfoSlice);
    
    payload.startTime = max(blockchain.now() + 30, payload.startTime);

    assert((payload.endTime >= payload.startTime + deployInfo.minTimeIncrement) && 
           (payload.endTime <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw EXC_INCORRECT_TIME_RANGE;
    assert((payload.minBidValue >= deployInfo.minPrice) && (payload.maxBidValue > payload.minBidValue)) throw EXC_PRICE_TOO_LOW;
    assert(payload.minBidIncrement > 1000) throw EXC_INCORRECT_BID_INCREMENT;
    assert(payload.timeIncrement >= deployInfo.minTimeIncrement) throw EXC_INCORRECT_TIME_INCREMENT;

    val commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);
    val maxCommission = mulDivFloor(deployInfo.maxCommission, COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);

    var domainsTotal: uint8 = 0;
    var (domainAddress, received, found) = payload.domainsAddresses.sDictGetFirst(267);
    while (found) {
        domainsTotal += 1;
        assert(received!.bitsEqual(BIT_FALSE_SLICE())) throw EXC_INCORRECT_DOMAIN;
        (domainAddress, received, found) = payload.domainsAddresses.sDictGetNext(267, domainAddress);
    }
    assert(domainsTotal > 0) throw EXC_EMPTY_DICT;

    var data = (Storage {
        state: STATE_UNINIT,
        isDeferred: payload.isDeferred,

        startTime: payload.startTime,
        endTime: payload.endTime,
        lastDomainRenewalTime: blockchain.now(),

        lastBidValue: 0,
        lastBidTime: 0,
        lastBidderAddress: createAddressNone(),

        domainsDict: payload.domainsAddresses,
        domainsTotal: domainsTotal,
        domainsReceived: 0,
        
        initialBalance: 0,

        hotUntil: 0,
        coloredUntil: 0,

        sellerAddress: args.commonArgs.fromAddress,

        minBidValue: payload.minBidValue,
        minBidIncrement: payload.minBidIncrement,
        timeIncrement: payload.timeIncrement,
        commissionFactor: commissionFactor,

        ds2: (StorageDs2 {
            maxBidValue: payload.maxBidValue,
            maxCommission: maxCommission,
            tonsToEndAuction: payload.tonsToEndAuction
        }).toCell()
    }).toCell();

    val auctionAddress = (AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    }).buildAddress();

    val msg = createMessage({
        bounce: false,
        value: TONS_DEPLOY_TON_MULTIPLE_AUCTION,
        dest: auctionAddress,
        body: FillUpBalanceMessage { queryId: args.commonArgs.queryId }
    });

    return TONS_DEPLOY_TON_MULTIPLE_AUCTION + msg.sendAndEstimateFee();
}
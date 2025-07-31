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

struct DeployInfoForJetton {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minTimeIncrement: uint32;
}

struct JettonMultipleAuctionDeployInfo {
    usdtInfo: DeployInfoForJetton;
    web3Info: Cell<DeployInfoForJetton>;
}

struct JettonMultipleAuctionDeployPayload {
    isWeb3: bool;
    isDeferred: bool;
    startTime: uint32;
    endTime: uint32;
    domainsAddresses: dict;  // address -> bool
    minBidValue: coins;
    maxBidValue: coins;
    minBidIncrement: uint12;
    timeIncrement: uint32;
}

const TONS_DEPLOY_JETTON_MULTIPLE_AUCTION: coins = ton("0.06");

@method_id(109)
fun deployJettonMultipleAuction(args: SimpleDeployArgs): int {
    var payload = lazy JettonMultipleAuctionDeployPayload.fromSlice(args.payloadSlice);
    var deployInfo: DeployInfoForJetton;
    if (payload.isWeb3) {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
        if (args.commonArgs.commissionDiscount != 0) {
            args.commonArgs.commissionDiscount = COMMISSION_DIVIDER;
        }
    } else {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
    }
    
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
        
        hotUntil: 0,
        coloredUntil: 0,

        sellerAddress: args.commonArgs.fromAddress,

        minBidValue: payload.minBidValue,
        maxBidValue: payload.maxBidValue,
        minBidIncrement: payload.minBidIncrement,
        timeIncrement: payload.timeIncrement,
        commissionFactor: commissionFactor,

        ds2: StorageDs2 {
            jettonWalletAddress: createAddressNone(),
            jettonMinterAddress: payload.isWeb3 ? WEB3_ADDRESS : USDT_ADDRESS,
            maxBidValue: payload.maxBidValue,
            maxCommission: deployInfo.maxCommission
        },
    }).toCell();

    val auctionAddress = (AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    }).buildAddress();

    val msg = createMessage({
        bounce: false,
        value: TONS_DEPLOY_JETTON_MULTIPLE_AUCTION,
        dest: auctionAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    payload.isWeb3 ?
                        calculateWeb3WalletAddress(auctionAddress) : 
                        calculateUsdtWalletAddress(auctionAddress))
                .endCell()
    });

    return TONS_DEPLOY_JETTON_MULTIPLE_AUCTION + msg.sendAndEstimateFee();
}
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

struct TonSimpleAuctionDeployInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minTimeIncrement: uint32;
}

struct TonSimpleAuctionDeployPayload {
    isDeferred: bool;
    startTime: uint32;
    endTime: uint32;
    minBidValue: coins;
    maxBidValue: coins;
    minBidIncrement: uint12;
    timeIncrement: uint32;
}

const TONS_DEPLOY_TON_SIMPLE_AUCTION = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");

fun deployTonSimpleAuction(args: DeployWithNftTransferArgs): int {
    var deployInfo = lazy TonSimpleAuctionDeployInfo.fromSlice(args.deployInfoSlice);
    var payload = lazy TonSimpleAuctionDeployPayload.fromSlice(args.payloadSlice);

    payload.startTime = max(blockchain.now() + 30, payload.startTime);

    assert((payload.endTime >= payload.startTime + deployInfo.minTimeIncrement) && (payload.endTime <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_TIME_RANGE);
    assert((payload.minBidValue >= deployInfo.minPrice) && (payload.maxBidValue > payload.minBidValue)) throw(EXC_PRICE_TOO_LOW);
    assert(payload.minBidIncrement > 1000) throw(EXC_INCORRECT_BID_INCREMENT);
    assert(payload.timeIncrement >= deployInfo.minTimeIncrement) throw(EXC_INCORRECT_TIME_INCREMENT);

    val commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER);
    val maxCommission = mulDivFloor(deployInfo.maxCommission, COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER);

    var data = (Storage {
        state: STATE_UNINIT,
        isDeferred: payload.isDeferred,
        domainAddress: args.domainAddress,
        sellerAddress: args.sellerAddress,
        maxBidValue: payload.maxBidValue,
        commissionFactor: commissionFactor,
        startTime: payload.startTime,
        lastDomainRenewalTime: blockchain.now(),
        endTime: payload.endTime,
        lastBidValue: 0,
        lastBidTime: 0,
        lastBidderAddress: 0,
        domainNameCell: 0,
        hotUntil: 0,
        coloredUntil: 0,
        minBidValue: payload.minBidValue,
        minBidIncrement: payload.minBidIncrement,
        timeIncrement: payload.timeIncrement,
        ds2: (StorageDs2 {
            maxBidValue: payload.maxBidValue,
            maxCommission: maxCommission,
            domainAddress: args.domainAddress,
            sellerAddress: args.sellerAddress,
        }).toCell(),
    }).toCell();

    val auctionAddress = (AutoDeployAddress {
        stateInit: {
            code: args.commonArgs.code,
            data: data,
        },
    }).buildAddress();

    val requiredGas = TONS_NFT_TRANSFER;
    createMessage({
        bounce: false,
        value: requiredGas,
        dest: args.domainAddress,
        body: NftTransferMessageBuilder<cell> {
            queryId: 0,
            toAddress: auctionAddress,
            responseAddress: createAddressNone(),
            forwardTonAmount: 0,
            forwardPayload: null
        }
    }).send(SEND_MODE_REGULAR);

    val msg = createMessage<FillUpBalanceMessage>({
        bounce: false,
        value: TONS_DEPLOY_TON_SIMPLE_AUCTION,
        dest: auctionAddress,
        body: FillUpBalanceMessage { queryId: args.commonArgs.queryId }
    });

    return TONS_DEPLOY_TON_SIMPLE_AUCTION + TONS_NFT_TRANSFER + msg.sendAndEstimateFee();
}
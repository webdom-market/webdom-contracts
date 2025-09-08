import "../../imports/utils"
import "../../imports/constants"
import "../../imports/utils"
import "../../marketplace/types"
import "../../marketplace/constants"
import "../../imports/types"
import "storage"
import "../../imports/messages"


struct DeployInfoForJetton {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minTimeIncrement: uint32;
}

struct JettonSimpleAuctionDeployPayload {
    isWeb3: bool;
    isDeferred: bool;
    startTime: uint32;
    endTime: uint32;
    minBidValue: coins;
    maxBidValue: coins;
    minBidIncrement: uint12;
    timeIncrement: uint32;
}

const TONS_DEPLOY_JETTON_SIMPLE_AUCTION = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");


fun deployJettonSimpleAuction(args: DeployWithNftTransferArgs): int {
    var payload = lazy JettonSimpleAuctionDeployPayload.fromSlice(args.commonArgs.payloadSlice);
    var deployInfo: DeployInfoForJetton;
    
    if (payload.isWeb3) {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
        if (args.commonArgs.commissionDiscount != 0) {
            args.commonArgs.commissionDiscount = COMMISSION_DIVIDER;
        }
    }
    else {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
    }

    payload.startTime = max(blockchain.now() + 30, payload.startTime);

    assert((payload.endTime >= payload.startTime + payload.timeIncrement) && (payload.endTime <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_TIME_RANGE);
    assert((payload.minBidValue >= deployInfo.minPrice) && (payload.maxBidValue > payload.minBidValue)) throw(EXC_PRICE_TOO_LOW);
    assert(payload.minBidIncrement > 1000) throw(EXC_INCORRECT_BID_INCREMENT);
    assert(payload.timeIncrement >= deployInfo.minTimeIncrement) throw(EXC_INCORRECT_TIME_INCREMENT);

    val commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);
    val maxCommission = mulDivFloor(deployInfo.maxCommission, COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);

    var data = (Storage {
        state: STATE_UNINIT,
        isDeferred: payload.isDeferred,
        startTime: payload.startTime,
        endTime: payload.endTime,
        lastDomainRenewalTime: blockchain.now(),
        lastBidValue: 0,
        lastBidTime: 0,
        lastBidderAddress: createAddressNone(),
        domainNameCell: args.domainNameCell,
        hotUntil: 0,
        coloredUntil: 0,
        sellerAddress: args.commonArgs.fromAddress,
        minBidValue: payload.minBidValue as uint64,
        minBidIncrement: payload.minBidIncrement,
        timeIncrement: payload.timeIncrement,
        commissionFactor: commissionFactor,
        ds2: (StorageDs2 {
            domainAddress: args.domainAddress,
            jettonWalletAddress: createAddressNone(),
            jettonMinterAddress: payload.isWeb3 ? WEB3_ADDRESS : USDT_ADDRESS,
            maxBidValue: payload.maxBidValue,
            maxCommission: maxCommission
        }).toCell(),
    }).toCell();

    val auctionAddress = (AutoDeployAddress {
        stateInit: {
            code: args.commonArgs.code,
            data: data,
        },
    });
    val auctionAddressBuilder = auctionAddress.buildAddress();

    createMessage({
        bounce: false,
        value: TONS_NFT_TRANSFER,
        dest: args.domainAddress,
        body: NftTransferMessageBuilder<CommentMessage> {
            queryId: 0,
            toAddress: auctionAddressBuilder,
            responseAddress: createAddressNone(),
            forwardTonAmount: 0,
            forwardPayload: CommentMessage { comment: "Auction on webdom.market" }
        }
    }).send(SEND_MODE_REGULAR);

    val contractCodes = lazy args.commonArgs.contractCodes.load();
    val msg = createMessage<cell>({
        bounce: false,
        value: TONS_DEPLOY_JETTON_SIMPLE_AUCTION,
        dest: auctionAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    payload.isWeb3 ?
                    calculateWeb3WalletAddress(auctionAddressBuilder, contractCodes.web3WalletCode) :
                    calculateUsdtWalletAddress(auctionAddressBuilder, contractCodes.usdtWalletCode)
                )
                .endCell()
    });

    return TONS_DEPLOY_JETTON_SIMPLE_AUCTION + TONS_NFT_TRANSFER + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
} 
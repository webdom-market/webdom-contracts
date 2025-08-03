import "../imports/utils";
import "../imports/constants";
import "../marketplace/types";
import "../marketplace/constants";
import "storage";
import "../imports/messages";
import "@stdlib/tvm-dicts"
import "../imports/constants"
import "../marketplace/constants"
import "constants";
import "../marketplace/types"
import "../imports/messages"


struct DomainSwapDeployInfo {
    completionCommission: coins;
    minDuration: uint32;
}

struct DomainSwapDeployPayload {
    leftDomainsList: dict;
    leftPaymentTotal: coins;
    rightParticipantAddress: address;
    rightDomainsList: dict;
    rightPaymentTotal: coins;
    validUntil: uint32;
    needsAlert: bool;
}

const TONS_DEPLOY_DOMAIN_SWAP: coins = ton("0.04");


fun deployDomainSwap(args: SimpleDeployArgs): int {
    var payload = lazy DomainSwapDeployPayload.fromSlice(args.payloadSlice);
    var deployInfo = lazy DomainSwapDeployInfo.fromSlice(args.deployInfoSlice);
    
    assert(payload.validUntil >= blockchain.now() + deployInfo.minDuration && payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY) throw EXC_INCORRECT_VALID_UNTIL;

    var leftDomainsTotal: uint8 = 0;
    var (domainAddress, received, found) = payload.leftDomainsList.sDictGetFirst(267);
    while (found) {
        leftDomainsTotal += 1;
        assert(received!.bitsEqual(BIT_FALSE_SLICE())) throw EXC_INCORRECT_DOMAIN;
        (domainAddress, received, found) = payload.leftDomainsList.sDictGetNext(267, domainAddress!);
    }

    var rightDomainsTotal: uint8 = 0;
    (domainAddress, received, found) = payload.rightDomainsList.sDictGetFirst(267);
    while (found) {
        rightDomainsTotal += 1;
        assert(received!.bitsEqual(BIT_FALSE_SLICE())) throw EXC_INCORRECT_DOMAIN;
        (domainAddress, received, found) = payload.rightDomainsList.sDictGetNext(267, domainAddress!);
    }

    assert(leftDomainsTotal + rightDomainsTotal > 0) throw EXC_EMPTY_DICT;
    deployInfo.completionCommission = mulDivFloor(deployInfo.completionCommission, COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER);

    var data = (Storage {
        leftParticipantAddress: args.fromAddress,
        leftInfo: (OneSideInfo {
            domainsTotal: leftDomainsTotal,
            domainsReceived: 0,
            domainsDict: payload.leftDomainsList,
            paymentTotal: payload.leftPaymentTotal,
            paymentReceived: 0,
        }).toCell(),

        rightParticipantAddress: payload.rightParticipantAddress,
        rightInfo: (OneSideInfo {
            domainsTotal: rightDomainsTotal,
            domainsReceived: 0,
            domainsDict: payload.rightDomainsList,
            paymentTotal: payload.rightPaymentTotal,
            paymentReceived: 0,
        }).toCell(),

        state: STATE_CANCELLED,
        createdAt: blockchain.now(),
        validUntil: payload.validUntil,
        lastActionTime: 0,
        completionCommission: deployInfo.completionCommission,
        needsAlert: payload.needsAlert,
        cancelledByLeft: false,
    }).toCell();

    val domainSwapAddress = (AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    });

    val msgValue = TONS_DEPLOY_DOMAIN_SWAP + (payload.needsAlert ? TONS_OFFER_NOTIFICATION : (0 as coins)) + deployInfo.completionCommission;
    val msg = createMessage({
        bounce: false,
        value: msgValue,
        dest: domainSwapAddress,
        body: FillUpBalanceMessage { queryId: args.queryId }
    });

    return msgValue + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
}
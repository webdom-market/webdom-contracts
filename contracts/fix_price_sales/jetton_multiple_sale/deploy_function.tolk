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
    minDuration: uint32;
}

struct JettonMultipleSaleDeployInfo {
    usdtInfo: DeployInfoForJetton;
    web3Info: Cell<DeployInfoForJetton>;
}

struct JettonMultipleSaleDeployPayload {
    isWeb3: bool;
    domainsAddresses: dict;  // address -> bool
    price: coins;
    validUntil: uint32;
}

const TONS_DEPLOY_JETTON_MULTIPLE_SALE: coins = ton("0.05");


fun deployJettonMultipleSale(args: SimpleDeployArgs): int {
    var payload = lazy JettonMultipleSaleDeployPayload.fromSlice(args.payloadSlice);
    var deployInfo: DeployInfoForJetton;
    if (payload.isWeb3) {
        deployInfo = DeployInfoForJetton.fromSlice(args.deployInfoSlice.loadRef().beginParse());
        if (args.commissionDiscount != 0) {
            args.commissionDiscount = COMMISSION_DIVIDER;
        }
    } else {
        deployInfo = DeployInfoForJetton.fromSlice(args.deployInfoSlice, { assertEndAfterReading: false });
    }
    
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
        jettonWalletAddress: createAddressNone(),
        hotUntil: 0,
        coloredUntil: 0,
        buyerAddressCell: createAddressNone().toCell(),
        jettonMinterAddressCell: payload.isWeb3 ? WEB3_ADDRESS.toCell() : USDT_ADDRESS.toCell(),
    }).toCell();

    val saleAddress = (AutoDeployAddress {
        stateInit: {
            code: args.code,
            data: data,
        },
    }).buildAddress();

    val contractCodes = lazy args.contractCodes.load();
    val msg = createMessage({
        bounce: false,
        value: TONS_DEPLOY_JETTON_MULTIPLE_SALE,
        dest: saleAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    payload.isWeb3 ?
                        calculateWeb3WalletAddress(saleAddress, contractCodes.web3WalletCode) : 
                        calculateUsdtWalletAddress(saleAddress, contractCodes.usdtWalletCode))
                .endCell()
    }); 

    return TONS_DEPLOY_JETTON_MULTIPLE_SALE + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
} 
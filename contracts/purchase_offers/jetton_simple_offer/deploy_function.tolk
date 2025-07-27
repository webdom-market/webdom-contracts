import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../imports/dns";
import "../../marketplace/deploy_contracts";
import "../../imports/types";
import "storage";
import "../../imports/messages"
import "../constants"
import "../ton_simple_offer/deploy_function"


struct DeployInfoForJetton {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct JettonSimpleOfferDeployInfo {
    usdtInfo: DeployInfoForJetton;
    web3Info: Cell<DeployInfoForJetton>;
}

struct JettonSimpleOfferDeployPayload {
    isTgUsername: bool;
    price: coins;
    validUntil: uint32;
    sellerAddress: address;
    notifySeller: bool;
    domainNameCell: Cell<SerializableSlice>;
}

const TONS_DEPLOY_JETTON_OFFER = TONS_JETTON_SIMPLE_OFFER_RESERVE + ton("0.015"); // 0.185

@method_id(102)
fun deployTonMultipleOffer(args: DeployWithJettonTransferArgs): int {
    var deployInfo: DeployInfoForJetton;
    var jettonMinterAddress: address;
    var jettonPostfix: slice;
    var oneJetton: int;

    if (args.isWeb3) {
        jettonMinterAddress = WEB3_ADDRESS;
        jettonPostfix = " WEB3 for ";
        oneJetton = 1000;
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
    } else {
        jettonMinterAddress = USDT_ADDRESS;
        jettonPostfix = " USDT for ";
        oneJetton = 1000000;
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
    }

    var payload = JettonSimpleOfferDeployPayload.fromSlice(args.payloadSlice);
    if (payload.isTgUsername) {
        domainAddressBuilder = tgUsernameToAddress(payload.domainNameCell.load().removeLastBits(5 * 8));
    } else {
        domainAddressBuilder = domainNameToAddress(payload.domainNameCell.load().removeLastBits(4 * 8));
    }

    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert(payload.validUntil >= now() + deployInfo.minDuration) throw(EXC_INCORRECT_TIME_RANGE);

    var requiredGas = TONS_DEPLOY_TON_OFFER + TONS_JETTON_TRANSFER;
    if (payload.notifySeller) {
        assert(payload.sellerAddress != createAddressNone()) throw(EXC_INCORRECT_SELLER_ADDRESS);
        val msg = createMessage<cell>({
            bounce: false,
            value: 0,
            dest: payload.sellerAddress,
            body: beginCell()
                     .storeUint(0, 32)
                     .storeSlice("New offer on webdom.market! ")
                     .storeStrFloat(payload.price, oneJetton)
                     .storeSlice(jettonPostfix)
                     .storeRef(payload.domainNameCell)
                .endCell()
        })
        requiredGas += deployMsg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_OFFER_NOTIFICATION;
    }

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER);
    
    val data = beginCell()
            .storeUint(STATE_UNINIT, 2)
            .storeCoins(payload.price)
            .storeCoins(commission)
            .storeUint(payload.validUntil, 32)
            .storeMaybeRef(payload.sellerAddress == createAddressNone() ? null : payload.sellerAddress.toCell())
            .storeUint(0, 5)  //
            .storeUint(now(), 32)
            .storeRef(
                beginCell()
                    .storeBuilder(domainAddressBuilder)
                    .storeAddress(args.fromAddress)
                    .storeAddress(jettonMinterAddress)
                    .storeRef(payload.domainNameCell)
                    .storeRef(args.publicKey.toCell())
                .endCell()
            )
        .endCell();

    val offerAddress = (AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    }).buildAddress();

    var offerJettonWalletAddress: address;
    if (args.isWeb3) {
        offerJettonWalletAddress = calculateWeb3WalletAddress(offerAddress);
    } else {
        offerJettonWalletAddress = calculateUsdtWalletAddress(offerAddress);
    }

    val deployMsg = createMessage<DeployMessage>({
        bounce: false,
        value: TONS_DEPLOY_JETTON_OFFER,
        dest: offerAddress,
        body: DeployMessage {queryId: args.queryId, jettonWalletAddress: offerJettonWalletAddress }
    });
    requiredGas += deployMsg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_DEPLOY_JETTON_OFFER + TONS_JETTON_TRANSFER;
    
    createMessage<SendJettonsMessage<cell>>({
        bounce: false,
        value: TONS_JETTON_TRANSFER,
        dest: args.jettonWalletAddress,
        body: SendJettonsMessageBuilder<cell> {
            queryId: args.queryId,
            jettonAmount: payload.price,
            toAddress: offerAddress,
            responseAddress: createAddressNone(),
            forwardPayload: null,
            forwardTonAmount: 0,
        }
    }).send(SEND_MODE_REGULAR);

    return requiredGas;
}
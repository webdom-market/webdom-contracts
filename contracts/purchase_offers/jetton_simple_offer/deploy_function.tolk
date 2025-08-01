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
import "../../imports/dns"

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


fun deployJettonSimpleOffer(args: DeployWithJettonTransferArgs): int {
    var deployInfo: DeployInfoForJetton;
    var jettonMinterAddress: address;
    var jettonPostfix: slice;
    var oneJetton: int;

    if (args.isWeb3) {
        jettonMinterAddress = WEB3_ADDRESS;
        jettonPostfix = " WEB3 for ";
        oneJetton = 1000;
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
        if (args.commonArgs.commissionDiscount != 0) {
            args.commonArgs.commissionDiscount = COMMISSION_DIVIDER;
        }
    } else {
        jettonMinterAddress = USDT_ADDRESS;
        jettonPostfix = " USDT for ";
        oneJetton = 1000000;
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
    }

    var payload = JettonSimpleOfferDeployPayload.fromSlice(args.commonArgs.payloadSlice);
    var contractCodes = lazy args.commonArgs.contractCodes.load();
    var domainAddressBuilder: builder;
    if (payload.isTgUsername) {
        domainAddressBuilder = tgUsernameToAddress(payload.domainNameCell.load().removeLastBits(5 * 8), contractCodes.tgUsernameCode);
    } else {
        domainAddressBuilder = domainNameToAddress(payload.domainNameCell.load().removeLastBits(4 * 8), contractCodes.domainCode);
    }

    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert(payload.validUntil >= blockchain.now() + deployInfo.minDuration) throw(EXC_INCORRECT_TIME_RANGE);

    var requiredGas = TONS_DEPLOY_JETTON_OFFER + TONS_JETTON_TRANSFER;
    if (payload.notifySeller) {
        assert(payload.sellerAddress != createAddressNone()) throw(EXC_INCORRECT_SELLER_ADDRESS);
        val deployMsg = createMessage<cell>({
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
        });
        requiredGas += deployMsg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_OFFER_NOTIFICATION;
    }

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);
    
    val data = beginCell()
            .storeUint(STATE_UNINIT, 2)
            .storeCoins(payload.price)
            .storeCoins(commission)
            .storeUint(payload.validUntil, 32)
            .storeMaybeRef(payload.sellerAddress == createAddressNone() ? null : payload.sellerAddress.toCell())
            .storeUint(0, 5)  //
            .storeUint(blockchain.now(), 32)
            .storeRef(
                beginCell()
                    .storeBuilder(domainAddressBuilder)
                    .storeAddress(args.commonArgs.fromAddress)
                    .storeAddress(jettonMinterAddress)
                    .storeRef(payload.domainNameCell)
                    .storeRef(args.commonArgs.publicKey.toCell())
                .endCell()
            )
        .endCell();

    val offerAddress = (AutoDeployAddress {
        stateInit: ContractState {
            code: args.commonArgs.code,
            data: data,
        }
    }).buildAddress();

    val deployMsg = createMessage<cell>({
        bounce: false,
        value: TONS_DEPLOY_JETTON_OFFER,
        dest: offerAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    args.isWeb3 ?
                        calculateWeb3WalletAddress(offerAddress, contractCodes.web3WalletCode) : 
                        calculateUsdtWalletAddress(offerAddress, contractCodes.usdtWalletCode))
                .endCell()
    });
    requiredGas += deployMsg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_DEPLOY_JETTON_OFFER + TONS_JETTON_TRANSFER;
    
    createMessage({
        bounce: false,
        value: TONS_JETTON_TRANSFER,
        dest: args.jettonWalletAddress,
        body: SendJettonsMessageBuilder<cell> {
            queryId: args.commonArgs.queryId,
            jettonAmount: payload.price,
            toAddress: offerAddress,
            responseAddress: createAddressNone(),
            forwardPayload: null,
            forwardTonAmount: 0,
        }
    }).send(SEND_MODE_REGULAR);

    return requiredGas;
}
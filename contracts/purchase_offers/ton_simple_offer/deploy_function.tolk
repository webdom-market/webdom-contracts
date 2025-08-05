import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../imports/dns";
import "../../marketplace/types";
import "../../marketplace/constants";
import "../../imports/types";
import "storage";
import "../../imports/messages"
import "../constants"

struct TonSimpleOfferDeploInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct TonSimpleOfferDeployPayload {
    price: coins;
    validUntil: uint32;
    sellerAddress: address;
    notifySeller: bool;
    domainNameCell: Cell<SerializableSlice>;
}


const TONS_DEPLOY_TON_OFFER = TONS_TON_SIMPLE_OFFER_RESERVE + ton("0.005");


fun deployTonSimpleOffer(args: SimpleDeployArgs): int {
    var deployInfo = TonSimpleOfferDeploInfo.fromSlice(args.deployInfoSlice);
    var payload = TonSimpleOfferDeployPayload.fromSlice(args.payloadSlice);

    var contractCodes = lazy args.contractCodes.load();
    var domainNameSlice = payload.domainNameCell.load();
    val isTgUsername = domainNameSlice.getLastBits(5 * 8).bitsEqual(".t.me");
    val domainAddressBuilder: builder = domainNameToAddress(domainNameSlice.removeLastBits(isTgUsername ? 5 * 8 : 4 * 8), contractCodes.domainCode);

    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert(payload.validUntil >= blockchain.now() + deployInfo.minDuration) throw(EXC_INCORRECT_VALID_UNTIL);

    var requiredGas = 0;
    if (payload.notifySeller) {
        assert(payload.sellerAddress != createAddressNone()) throw(EXC_INCORRECT_SELLER_ADDRESS);
        val msg = createMessage<cell>({
            bounce: false,
            value: TONS_OFFER_NOTIFICATION,
            dest: payload.sellerAddress,
            body: beginCell()
                     .storeUint(0, 32)
                     .storeSlice("New offer on webdom.market! ")
                     .storeStrFloat(payload.price, ton("1"))
                     .storeSlice(" TON for ")
                     .storeRef(payload.domainNameCell)
                .endCell()
        });
        requiredGas += msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_OFFER_NOTIFICATION;
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
                .storeUint(blockchain.now(), 32)
                .storeBuilder(domainAddressBuilder)
                .storeAddress(args.fromAddress)
                .storeRef(payload.domainNameCell)
                .storeMaybeRef(args.publicKey.toCell())
            .endCell();

    val offerAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    };

    val msg = createMessage<FillUpBalanceMessage>({
        bounce: false,
        value: payload.price + commission + TONS_DEPLOY_TON_OFFER,  // газ за исполнение оффера оплачивает его создатель
        dest: offerAddress,
        body: FillUpBalanceMessage {queryId: args.queryId}
    });
    requiredGas += (msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY)
                    + commission + payload.price + TONS_DEPLOY_TON_OFFER);

    return requiredGas;
}
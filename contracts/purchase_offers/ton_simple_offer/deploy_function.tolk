import "../../imports/utils";
import "../../imports/constants";
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


const TONS_DEPLOY_TON_OFFER: coins = TONS_TON_SIMPLE_OFFER_RESERVE + ton("0.005");


fun deployTonSimpleOffer(args: SimpleDeployArgs): int {
    var deployInfo = TonSimpleOfferDeploInfo.fromSlice(args.deployInfoSlice);
    var payload = TonSimpleOfferDeployPayload.fromSlice(args.payloadSlice);

    var contractCodes: ContractCodes = lazy args.contractCodes.load();
    var domainNameSlice: SerializableSlice = payload.domainNameCell.load();
    val isTgUsername: bool = domainNameSlice.getLastBits(5 * 8).bitsEqual(".t.me");
    val domainAddressBuilder: builder = domainNameToAddress(domainNameSlice.removeLastBits(isTgUsername ? 5 * 8 : 4 * 8), contractCodes.domainCode);

    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);   // check that price is greater than the minimum price
    assert(
        payload.validUntil >= blockchain.now() + deployInfo.minDuration &&
        payload.validUntil <= blockchain.now() + ONE_DAY * 30
    ) throw(EXC_INCORRECT_VALID_UNTIL);  // check that valid until is greater than the minimum duration and less than 30 days from now

    var requiredGas: coins = 0;

    if (payload.notifySeller) {  // onchain notification of the NFT owner
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

    val commissionDiscountFactor = COMMISSION_DIVIDER - args.commissionDiscount;
    val commissionFactor = mulDivFloor(deployInfo.commissionFactor, commissionDiscountFactor, COMMISSION_DIVIDER);
    val commission: int = min(
        mulDivFloor(payload.price, commissionFactor, COMMISSION_DIVIDER),
        mulDivFloor(deployInfo.maxCommission, commissionDiscountFactor, COMMISSION_DIVIDER)
    );  // commission is the minimum of {commission rate * price} and {max commission including discount}
   
    // we don't use Storage.toCell() here because we don't want to convert the domainAddress from `builder` to `slice`
    val data: cell = beginCell()
                .storeUint(STATE_UNINIT, 2)
                .storeCoins(payload.price)
                .storeCoins(commission)
                .storeUint(payload.validUntil, 32)
                .storeMaybeRef(payload.sellerAddress == createAddressNone() ? null : payload.sellerAddress.toCell())
                .storeUint(0, 5)  // cancelledBySeller -- false, sellerPrice -- 0
                .storeUint(blockchain.now(), 32)  // createdAt
                .storeBuilder(domainAddressBuilder)
                .storeAddress(args.fromAddress)  // buyerAddress
                .storeRef(payload.domainNameCell)
                .storeMaybeRef(args.publicKey.toCell())
            .endCell();

    val offerAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    };

    val msgValue: coins = payload.price + commission + TONS_DEPLOY_TON_OFFER;  // offer creator pays all gas fees for the offer execution
    val msg = createMessage<FillUpBalanceMessage>({
        bounce: false,
        value: msgValue,
        dest: offerAddress,
        body: FillUpBalanceMessage {queryId: args.queryId}
    });
    requiredGas += msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + msgValue;

    return requiredGas;
}
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

struct TonSimpleSaleDeployInfo {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct TonSimpleSaleDeployPayload {
    price: coins;
    validUntil: uint32;
}

const TONS_DEPLOY_TON_SIMPLE_SALE = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");


@method_id(104)
fun deployTonSimpleSale(args: DeployWithNftTransferArgs): int {
    var deployInfo = TonSimpleSaleDeployInfo.fromSlice(args.deployInfoSlice);
    var payload = TonSimpleSaleDeployPayload.fromSlice(args.payloadSlice);
    
    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert((payload.validUntil >= blockchain.now() + deployInfo.minDuration) && 
           (payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_VALID_UNTIL);

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER);

    val data = (Storage {
        domainAddress: args.domainAddress,
        sellerAddress: args.fromAddress,
        price: payload.price,
        state: STATE_UNINIT,
        commission: commission,
        createdAt: blockchain.now(),
        lastRenewalTime: blockchain.now(),
        validUntil: payload.validUntil,
        buyerAddressCell: null,
        domainNameCell: args.domainNameCell,
        hotUntil: 0,
        coloredUntil: 0,
    }).toCell();
              
    val saleAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    }.buildAddress();

    // Transfer NFT to the sale contract
    var requiredGas = TONS_NFT_TRANSFER;
    createMessage({
        bounce: false,
        value: requiredGas,
        dest: domainAddress,
        body: NftTransferMessageBuilder<cell> {
            queryId: 0,
            toAddress: saleAddress,
            responseAddress: createAddressNone(),
            forwardTonAmount: 0,
            forwardPayload: null
        }
    }).send(SEND_MODE_REGULAR);

    // Deploy sale contract
    val msg = createMessage<FillUpBalanceMessage>({
        bounce: false,
        value: TONS_DEPLOY_TON_SIMPLE_SALE,
        dest: saleAddress,
        body: FillUpBalanceMessage { queryId: args.queryId }
    });
    requiredGas += (msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_DEPLOY_TON_SIMPLE_SALE);

    return requiredGas;
} 
import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../imports/dns";
import "../../marketplace/types";
import "../../marketplace/constants";
import "../../imports/types";
import "storage";
import "../../imports/messages";
import "../constants";


struct DeployInfoForJetton {
    minPrice: coins;
    commissionFactor: uint16;
    maxCommission: coins;
    minDuration: uint32;
}

struct JettonSimpleSaleDeployInfo {
    usdtInfo: DeployInfoForJetton;
    web3Info: Cell<DeployInfoForJetton>;
}

struct JettonSimpleSaleDeployPayload {
    isWeb3: bool;
    price: coins;
    validUntil: uint32;
}

const TONS_DEPLOY_JETTON_SIMPLE_SALE = TONS_NFT_TRANSFER + TONS_MIN_RESERVE * 2 + ton("0.005");

fun deployJettonSimpleSale(args: DeployWithNftTransferArgs): int {
    var payload = JettonSimpleSaleDeployPayload.fromSlice(args.commonArgs.payloadSlice);
    var deployInfo: DeployInfoForJetton;
    if (payload.isWeb3) {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice.loadRef().beginParse());
        if (args.commonArgs.commissionDiscount != 0) {
            args.commonArgs.commissionDiscount = COMMISSION_DIVIDER;
        }
    } else {
        deployInfo = DeployInfoForJetton.fromSlice(args.commonArgs.deployInfoSlice, { assertEndAfterReading: false });
    }
    
    assert(payload.price >= deployInfo.minPrice) throw(EXC_PRICE_TOO_LOW);
    assert((payload.validUntil >= blockchain.now() + deployInfo.minDuration) && 
           (payload.validUntil <= blockchain.now() + ONE_YEAR - ONE_DAY)) throw(EXC_INCORRECT_VALID_UNTIL);

    val commission: int = mulDivFloor(min(
        mulDivFloor(payload.price, deployInfo.commissionFactor, COMMISSION_DIVIDER),
        deployInfo.maxCommission
    ), COMMISSION_DIVIDER - args.commonArgs.commissionDiscount, COMMISSION_DIVIDER);

    val data = (Storage {
        jettonWalletAddress: createAddressNone(),
        sellerAddress: args.commonArgs.fromAddress,
        price: payload.price,
        state: STATE_UNINIT,
        commission: commission,
        createdAt: blockchain.now(),
        lastRenewalTime: blockchain.now(),
        validUntil: payload.validUntil,
        domainNameCell: args.domainNameCell,
        hotUntil: 0,
        coloredUntil: 0, 
        ds2: (StorageDs2 {
            domainAddress: args.domainAddress,
            jettonMinterAddress: payload.isWeb3 ? WEB3_ADDRESS : USDT_ADDRESS,
            buyerAddress: createAddressNone(),
        }).toCell()
    }).toCell();
              
    val saleAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.commonArgs.code,
            data: data,
        }
    };
    val saleAddressBuilder = saleAddress.buildAddress();

    // Transfer NFT to the sale contract
    createMessage({
        bounce: false,
        value: TONS_NFT_TRANSFER,
        dest: args.domainAddress,
        body: NftTransferMessageBuilder<cell> {
            queryId: 0,
            toAddress: saleAddressBuilder,
            responseAddress: createAddressNone(),
            forwardTonAmount: 0,
            forwardPayload: null
        }
    }).send(SEND_MODE_REGULAR);

    // Deploy sale contract
    val contractCodes = lazy args.commonArgs.contractCodes.load();
    val msg = createMessage<cell>({
        bounce: false,
        value: TONS_DEPLOY_JETTON_SIMPLE_SALE,
        dest: saleAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.commonArgs.queryId, 64)
                .storeBuilder(
                    payload.isWeb3 ?
                        calculateWeb3WalletAddress(saleAddressBuilder, contractCodes.web3WalletCode) : 
                        calculateUsdtWalletAddress(saleAddressBuilder, contractCodes.usdtWalletCode))
                .endCell()
    }); 

    return TONS_NFT_TRANSFER + TONS_DEPLOY_JETTON_SIMPLE_SALE + msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
} 
import "../../imports/utils";
import "../../imports/constants";
import "../../marketplace/types";


struct MultipleOfferDeployInfo {
    commissionFactor: uint16;
    web3CommissionFactor: uint16;
}

struct MultipleOfferDeployPayload {
    merkleRoot: uint256;
}

const TONS_DEPLOY_MULTIPLE_OFFER = ton("0.05");

fun deployMultipleOffer(args: SimpleDeployArgs): int {
    var deployInfo = MultipleOfferDeployInfo.fromSlice(args.deployInfoSlice);
    if (args.commissionDiscount) {
        deployInfo.web3CommissionFactor = 0;
        deployInfo.commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER); 
    }

    val data: cell = beginCell()
                            .storeAddress(args.fromAddress)
                            .storeUint(0, 256)
                            .storeRef(args.publicKey.toCell())
                            .storeUint(0, 36)
                        .endCell();
    val offerAddress = AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    };

    val contractCodes: ContractCodes = lazy args.contractCodes.load();
    val web3OfferAddress: builder = calculateWeb3WalletAddress(offerAddress.buildAddress(), contractCodes.web3WalletCode);
    
    val msg = createMessage<cell>({
        bounce: false,
        value: TONS_DEPLOY_MULTIPLE_OFFER,
        dest: offerAddress,
        body: beginCell()
                .storeUint(OP_FILL_UP_BALANCE, 32)
                .storeUint(args.queryId, 64)
                .storeSlice(args.payloadSlice)
                .storeUint(deployInfo.commissionFactor, 16)
                .storeUint(deployInfo.web3CommissionFactor, 16)
                .storeBuilder(web3OfferAddress)
            .endCell()
    });
    val requiredGas: int = msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + TONS_DEPLOY_MULTIPLE_OFFER;  // return deploy price
    
    return requiredGas;
}

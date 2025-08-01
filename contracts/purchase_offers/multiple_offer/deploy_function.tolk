import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";
import "../../marketplace/deploy_contracts";


struct MultipleOfferDeployInfo {
    commissionFactor: uint16;
    web3CommissionFactor: uint16;
}

struct MultipleOfferDeployPayload {
    merkleRoot: uint256;
}


fun deployMultipleOffer(args: SimpleDeployArgs): int {
    var deployInfo = MultipleOfferDeployInfo.fromSlice(args.deployInfoSlice);
    if (args.commissionDiscount) {
        deployInfo.web3CommissionFactor = 0;
        deployInfo.commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - args.commissionDiscount, COMMISSION_DIVIDER); 
    }
    val data = beginCell()
                            .storeAddress(args.fromAddress)
                            .storeUint(0, 256)
                            .storeRef(args.publicKey.toCell())
                            .storeUint(0, 36)
                        .endCell();
    val offerAddress = (AutoDeployAddress {
        stateInit: ContractState {
            code: args.code,
            data: data,
        }
    }).buildAddress();

    val contractCodes = lazy args.contractCodes.load();
    val web3OfferAddress = calculateWeb3WalletAddress(offerAddress, contractCodes.web3WalletCode);
    
    val msg = createMessage<cell>({
        bounce: false,
        value: ton("0.05"),
        dest: offerAddress,
        body: beginCell()
                .storeUint(args.queryId, 64)
                .storeSlice(args.payloadSlice)
                .storeUint(deployInfo.commissionFactor, 16)
                .storeUint(deployInfo.web3CommissionFactor, 16)
                .storeBuilder(web3OfferAddress)
            .endCell()
    });
    return msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + ton("0.05");  // return msg sending price
}

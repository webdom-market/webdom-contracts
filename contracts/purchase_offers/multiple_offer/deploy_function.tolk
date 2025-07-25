import "@stdlib/tvm-lowlevel";
import "../../imports/utils";
import "../../imports/constants";
import "messages";

struct MultipleOfferDeployInfo {
    commissionFactor: uint16;
    web3CommissionFactor: uint16;
}

struct MultipleOfferDeployPayload {
    merkleRoot: uint256;
}

@method_id(101)
fun deployMultipleOffer(
    fromAddress: address,
    payloadSlice: slice,
    deployInfoSlice: slice,
    code: cell,
    commissionDiscount: uint16,
    queryId: uint64,
    publicKey: uint256,
): int {
    var deployInfo = MultipleOfferDeployInfo.fromSlice(deployInfoSlice);
    if (commissionDiscount) {
        deployInfo.web3CommissionFactor = 0;
        deployInfo.commissionFactor = mulDivFloor(deployInfo.commissionFactor, COMMISSION_DIVIDER - commissionDiscount, COMMISSION_DIVIDER); 
    }
    val data = beginCell()
                            .storeAddress(fromAddress)
                            .storeUint(0, 256)
                            .storeRef(publicKey.toCell())
                            .storeUint(0, 36)
                        .endCell();
    val offerAddress = (AutoDeployAddress {
        stateInit: ContractState {
            code: code,
            data: data,
        }
    }).buildAddress();
    val web3OfferAddress = calculateWeb3WalletAddress(offerAddress);
    
    val msg = createMessage<cell>({
        bounce: false,
        value: ton("0.05"),
        dest: offerAddress,
        body: beginCell()
                .storeUint(queryId, 64)
                .storeSlice(payloadSlice)
                .storeUint(deployInfo.commissionFactor, 16)
                .storeUint(deployInfo.web3CommissionFactor, 16)
                .storeBuilder(web3OfferAddress)
            .endCell()
    });
    return msg.sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY) + ton("0.05");  // return msg sending price
}

fun deployFunctionCell(): cell 
    asm """<{              	//  arg1 arg2
    // 60: debug.printString("test")
    x{74657374} PUSHSLICE   	
    STRDUMP DROP            	
    // 61: debug.print(arg1)
    SWAP                    	
    s0 DUMP DROP            	
    // 62: debug.print(arg2)
    s0 DUMP DROP            	
  }>c PUSHREF""";
 

struct testStruct {
    arg1: int;
    arg2: int;
}
struct testStruct2 {
    arg1: int;
}

fun execute(c: continuation, testStruct: testStruct): void 
    asm (testStruct c) "EXECUTE";

fun onInternalMessage(): void {
    var cont = transformSliceToContinuation(deployFunctionCell().beginParse());
    var testStruct = testStruct {
        arg1: 1,
        arg2: 2,
    };
    execute(cont, testStruct);
    // var testStruct2 = testStruct2 {
    //     arg1: 3,
    // };
    // execute(cont, testStruct2);
}

// get fun getDeployFunctionCell(): cell {
//     return deployFunctionCell();
// }

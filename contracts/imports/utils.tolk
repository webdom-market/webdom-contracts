import "constants.tolk";

fun beginParseExotic(c: cell): (slice, int)
    asm "XCTOS"

@pure
fun dict.sDictGetNext(self, keyLen: int, pivot: slice): (slice?, slice?, bool)
    asm(pivot self keyLen -> 1 0 2) "DICTGETNEXT" "NULLSWAPIFNOT2"

@pure
fun dict.sDictGetPrev(self, keyLen: int, pivot: slice): (slice?, slice?, bool)
    asm(pivot self keyLen -> 1 0 2) "DICTGETPREV" "NULLSWAPIFNOT2"



@inline
fun builder.storeNumber10(self, x: int): builder 
     asm """
  ZERO                                                        
  SWAP                                                        
  UNTIL:<{                                                   
    10 PUSHINT DIVMOD                                         
    48 ADDCONST                                               
    s3 s1 s3 XCHG3                                          
    INC                                                      
    s1 s0 XCPU                                                
    ISZERO
  }>
  DROP
  REPEAT:<{ 8 STU }>                                        
""";

@inline
fun builder.storeStrFloat(mutate self, number: int, tenPowDecimals: int): builder {
    var (intPart, decPart) = divMod(number, tenPowDecimals);
    self = self.storeNumber10(intPart);
    if (decPart == 0) {
        return self; 
    }

    // displayed decimals = max(min(jettonDecimals, 4 - log10(intPart)), 0)
    var maxDecPart: int = (intPart) ? (10000 / intPart) : 10000;
    var zeros: int = 0;
    var tmp: int = tenPowDecimals / (decPart + 1);
    while (tmp >= 10) {
        tmp /= 10;
        maxDecPart /= 10;
        zeros += 1;
    }
    if (maxDecPart == 0) {
        return self;
    }
    while (decPart > maxDecPart) {
        decPart /= 10;
    }
    if (decPart) {
        while (decPart % 10 == 0) {
            decPart /= 10;
        } 
        self = self.storeUint(46, 8);  // store "." (dot)
        repeat(zeros) { 
            self = self.storeUint(48, 8); 
        };
        return self.storeNumber10(decPart);
    }
    return self;
}

@inline
fun builder.storeStrJettons(mutate self, jetton_amount: int, one_jetton: int, symbol: slice): builder {
    return self.storeStrFloat(jetton_amount, one_jetton)
                .storeUint(32, 8)  // store " " (space)
                .storeSlice(symbol);
}

@inline
fun calculateWeb3WalletAddress(ownerAddress: builder): builder {
    var data: cell = beginCell()
                .storeCoins(0)
                .storeBuilder(ownerAddress)
                .storeAddress(WEB3_ADDRESS)
                .storeRef(WEB3_WALLET_CODE())
           .endCell();
    return (AutoDeployAddress {
        stateInit: ContractState {
            code: WEB3_WALLET_CODE(),
            data: data
        }
    }).buildAddress();
}

@inline
fun calculateUsdtWalletAddress(ownerAddress: address): builder {
    var data: cell = beginCell()
                    .storeUint(0, 4)
                    .storeCoins(0)
                    .storeAddress(ownerAddress)
                    .storeAddress(USDT_ADDRESS)
                .endCell();
    return (AutoDeployAddress {
        stateInit: ContractState {
            code: USDT_WALLET_CODE(),
            data: data
        }
    }).buildAddress();
}


@inline
fun forceSameWorkchain(addr: address) {
    var wc = addr.getWorkchain();
    assert (wc == WORKCHAIN) throw EXC_WRONG_CHAIN;
}
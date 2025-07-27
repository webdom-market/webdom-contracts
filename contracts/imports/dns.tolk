import "constants";

fun domainNameToAddress(domainName: slice): builder {
    var domainIndex = domainName.hash();
    var data = beginCell().storeUint(domainIndex, 256).storeSlice(TON_DNS_ADDRESS).endCell();

    return AutoDeployAddress {
        stateInit: ContractState {
            code: DOMAIN_CODE(),
            data: data,
        }
    }.buildAddress();
}


fun tgUsernameToAddress(tgUsername: slice): builder {
    var usernameIndex = tgUsername.bitsHash();
    var data = beginCell() 
                    .storeRef(
                        beginCell()
                            .storeUint(usernameIndex, 256)
                            .storeSlice(TG_USERNAMES_ADDRESS)
                        .endCell()
                    )
                    .storeInt(0, 1)
                .endCell();
    return AutoDeployAddress {
        stateInit: ContractState {
            code: TG_USERNAME_CODE(),
            data: data,
        }
    }.buildAddress();
}

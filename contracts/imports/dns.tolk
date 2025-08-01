import "constants";

@inline
fun domainNameToAddress(domainName: slice, domainCode: cell): builder {
    var domainIndex = domainName.hash();
    var data = beginCell().storeUint(domainIndex, 256).storeAddress(TON_DNS_ADDRESS).endCell();

    return AutoDeployAddress {
        stateInit: ContractState {
            code: domainCode,
            data: data,
        }
    }.buildAddress();
}


@inline
fun tgUsernameToAddress(tgUsername: slice, tgUsernameCode: cell): builder {
    var usernameIndex = tgUsername.bitsHash();
    var data = beginCell() 
                    .storeRef(
                        beginCell()
                            .storeUint(usernameIndex, 256)
                            .storeAddress(TG_USERNAMES_ADDRESS)
                        .endCell()
                    )
                    .storeInt(0, 1)
                .endCell();
    return AutoDeployAddress {
        stateInit: ContractState {
            code: tgUsernameCode,
            data: data,
        }
    }.buildAddress();
}

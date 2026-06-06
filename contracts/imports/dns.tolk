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


// Build a `dns_text#1eda` value cell for a domain's webdom listing page:
//   "https://webdom.market/domain/" ++ domainName   (domainName is the full name incl. TLD)
// Encoded as 1 or 2 text chunks (prefix is 29 bytes, a domain name fits a single cell), matching the
// chunked TL-B encoding used by webdom-front (createTextRecordCell):
//   text_chunk$_ len:(## 8) data:(bits (len*8)) next:(TextChunkRef n) ; dns_text#1eda chunks:(## 8) ...
@inline
fun buildDomainLinkRecord(domainName: slice): cell {
    val prefix: slice = "https://webdom.market/domain/".literalSlice();  // 29 bytes
    val totalBytes: int = 29 + domainName.remainingBitsCount() / 8;

    if (totalBytes <= 123) {  // fits in a single chunk (root cell holds 16 + 8 + 8 + 123*8 bits)
        return beginCell()
            .storeUint(0x1eda, 16)        // dns_text prefix
            .storeUint(1, 8)              // 1 chunk
            .storeUint(totalBytes, 8)     // chunk length in bytes
            .storeSlice(prefix)
            .storeSlice(domainName)
        .endCell();
    }

    // Two chunks: first 123 bytes inline (prefix + first 94 name bytes), the rest in a ref.
    var name: slice = domainName;
    val firstNamePart: slice = name.loadBits((123 - 29) * 8);
    return beginCell()
        .storeUint(0x1eda, 16)
        .storeUint(2, 8)                  // 2 chunks
        .storeUint(123, 8)               // first chunk: 123 bytes
        .storeSlice(prefix)
        .storeSlice(firstNamePart)
        .storeRef(
            beginCell()
                .storeUint(totalBytes - 123, 8)  // second chunk: remaining bytes
                .storeSlice(name)
            .endCell()
        )
    .endCell();
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

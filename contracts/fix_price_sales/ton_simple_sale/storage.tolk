import "../../imports/types"

struct Storage {
    domainAddress: address;
    sellerAddress: address;
    price: coins;
    state: uint2;
    commission: coins;
    createdAt: uint32;
    lastRenewalTime: uint32;
    validUntil: uint32;
    buyerAddressCell: Cell<address>?;
    domainNameCell: cell;
    hotUntil: uint32;
    coloredUntil: uint32;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
} 
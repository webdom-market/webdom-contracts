import "../../imports/types"


struct Storage {
    sellerAddress: address;
    domainsDict: dict;
    domainsTotal: uint8;
    domainsReceived: uint8;

    price: coins;
    commission: coins;

    state: uint2;
    createdAt: uint32;
    lastRenewalTime: uint32;
    validUntil: uint32;

    jettonWalletAddress: address;

    hotUntil: uint32;
    coloredUntil: uint32;

    buyerAddressCell: Cell<address>;
    jettonMinterAddressCell: Cell<address>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}
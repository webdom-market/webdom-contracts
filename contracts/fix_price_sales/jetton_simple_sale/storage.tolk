import "../../imports/types"

struct StorageDs2 {
    domainAddress: address;
    jettonMinterAddress: address;
    buyerAddress: address;
}

struct Storage {
    jettonWalletAddress: address;
    sellerAddress: address;
    price: coins;
    state: uint2;
    commission: coins;
    createdAt: uint32;
    lastRenewalTime: uint32;
    validUntil: uint32;
    domainNameCell: cell;
    hotUntil: uint32;
    coloredUntil: uint32;

    ds2: Cell<StorageDs2>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline 
fun Storage.save(self): void {
    contract.setData(self.toCell()) 
}
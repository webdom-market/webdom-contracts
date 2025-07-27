import "../../imports/types"

struct StorageDs2 {
    domainAddress: address;
    buyerAddress: address;
    jettonMinterAddress: address;
    domainName: Cell<SerializableSlice>;
    publicKeyCell: Cell<uint256>?;
}

struct Storage {
    state: uint2;
    price: coins;
    commission: coins;
    validUntil: uint32;
    sellerAddress: address;
    jettonWalletAddress: address;
    cancelledBySeller: bool;
    sellerPrice: coins;
    createdAt: uint32;

    ds2: Cell<StorageDs2>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}

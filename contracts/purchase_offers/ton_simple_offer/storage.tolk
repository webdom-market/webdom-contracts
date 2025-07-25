import "../../imports/types"

struct Storage {
    state: uint2;
    price: coins;
    commission: coins;
    validUntil: uint32;
    sellerAddress: Cell<address>?;
    cancelledBySeller: bool;
    sellerPrice: coins;

    createdAt: uint32;
    domainAddress: address;
    buyerAddress: address;
    domainName: Cell<SerializableSlice>;
    publicKeyCell: Cell<uint256>?;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}
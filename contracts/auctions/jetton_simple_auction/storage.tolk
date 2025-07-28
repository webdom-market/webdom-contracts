import "../../imports/types"

struct StorageDs2 {
    jettonWalletAddress: address;
    jettonMinterAddress: address;
    maxBidValue: coins;
    maxCommission: uint64;
    domainAddress: address;
}

struct Storage {
    state: uint2;
    isDeferred: bool;

    startTime: uint32;
    endTime: uint32;
    lastDomainRenewalTime: uint32;

    lastBidValue: coins;
    lastBidTime: uint32;
    lastBidderAddress: address;

    domainNameCell: cell

    hotUntil: uint32;
    coloredUntil: uint32;

    sellerAddress: address;

    minBidValue: uint64;
    minBidIncrement: uint16;
    timeIncrement: uint32;
    commissionFactor: uint16; 

    ds2: Cell<StorageDs2>;
}


fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData());
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell());
}
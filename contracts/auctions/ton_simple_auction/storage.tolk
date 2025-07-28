struct StorageDs2 {
    domainAddress: address;
    maxBidValue: coins;
    maxCommission: uint64;
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

    // const part
    sellerAddress: address;
    minBidValue: uint64;
    minBidIncrement: uint12;
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
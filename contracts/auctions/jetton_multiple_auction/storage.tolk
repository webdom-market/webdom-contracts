import "../../imports/types"

struct StorageDs2 {
    jettonWalletAddress: address;
    jettonMinterAddress: address;
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

    domainsDict: dict;
    domainsTotal: uint8;
    domainsReceived: uint8;

    hotUntil: uint32;
    coloredUntil: uint32;

    sellerAddress: address;

    minBidValue: uint64;
    minBidIncrement: uint12;
    timeIncrement: uint32;
    commissionFactor: uint16; 

    ds2: Cell<StorageDs2>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}
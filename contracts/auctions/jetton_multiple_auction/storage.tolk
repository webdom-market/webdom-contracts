struct StorageDs2 {
    jettonWalletAddress: address;  // Jetton wallet address
    jettonMinterAddress: address;  // Jetton minter address
    maxBidValue: coins;            // Maximum bid value
    maxCommission: uint64;         // Commission limit
}

struct Storage {
    state: uint2;                     // Auction state (UNINIT, ACTIVE, COMPLETED, CANCELLED)
    isDeferred: bool;                 // Whether auction is deferred

    startTime: uint32;                // Auction start timestamp
    endTime: uint32;                  // Auction end timestamp
    lastDomainRenewalTime: uint32;    // Last domain renewal timestamp

    lastBidValue: coins;              // Last bid value
    lastBidTime: uint32;              // Last bid time
    lastBidderAddress: address;       // Last bidder address

    domainsDict: dict;                // Dictionary of domains (address -> boolean received flag)
    domainsTotal: uint8;              // Total number of domains
    domainsReceived: uint8;           // Number of domains received

    hotUntil: uint32;                 // Hot promotion end timestamp
    coloredUntil: uint32;             // Colored promotion end timestamp

    sellerAddress: address;           // Seller address

    minBidValue: uint64;              // Minimum bid value
    minBidIncrement: uint12;          // Minimum bid increment
    timeIncrement: uint32;            // Time increment
    commissionFactor: uint16;         // Commission factor (commission = bid * commissionFactor / 10_000)

    ds2: Cell<StorageDs2>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}
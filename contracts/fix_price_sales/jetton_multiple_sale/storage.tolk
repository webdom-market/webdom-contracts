struct StorageDs2 {
    buyerAddress: address?;          // Address of the buyer (set when sale is completed)
    jettonMinterAddress: address;    // Address of the jetton minter contract
    autoRenewCooldown: uint32;       // Minimal delay between domain renewals
    autoRenewIterations: uint8;      // Remaining paid auto-renew iterations
}

struct Storage {
    sellerAddress: address;           // Address of the seller
    domainsDict: dict;                // Dictionary of domains (key: domain address, value: received boolean flag)
    domainsTotal: uint8;              // Total number of domains
    domainsReceived: uint8;           // Number of received domains

    price: coins;                     // Sale price
    commission: coins;                // Marketplace commission amount

    state: uint2;                     // Sale state
    createdAt: uint32;                // Sale creation timestamp
    lastRenewalTime: uint32;          // Last domain renewal timestamp
    validUntil: uint32;               // Sale expiration timestamp

    jettonWalletAddress: address?;    // Address of the jetton wallet

    hotUntil: uint32;                 // Hot promotion end timestamp
    coloredUntil: uint32;             // Colored promotion end timestamp

    ds2: Cell<StorageDs2>;            // Additional data (buyer, jetton minter, auto-renew params)
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}

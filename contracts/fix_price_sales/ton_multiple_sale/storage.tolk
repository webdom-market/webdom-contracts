struct AutoRenewData {
    autoRenewCooldown: uint32;   // Minimal delay between domain renewals
    autoRenewIterations: uint8;  // Remaining paid auto-renew iterations
}

struct Storage {  // 267 + 1 + 8 + 8 + 124 + 124 + 2 + 32 + 32 + 32 + 267 + 32 + 32 = 961 bits
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

    buyerAddress: address?;           // Address of the buyer (set when sale is completed)

    hotUntil: uint32;                 // Hot promotion end timestamp
    coloredUntil: uint32;             // Colored promotion end timestamp
    autoRenewData: Cell<AutoRenewData>;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
} 

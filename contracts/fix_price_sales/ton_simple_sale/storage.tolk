struct AutoRenewData {
    autoRenewCooldown: uint32;   // Minimal delay between domain renewals
    autoRenewIterations: uint8;  // Remaining paid auto-renew iterations
}

struct Storage {  // 267 + 267 + 124 + 2 + 124 + 32 + 32 + 32 + 1 + 1 + 32 + 32 = 946 bits
    domainAddress: address;           // Address of the domain being sold
    sellerAddress: address;           // Address of the domain seller
    price: coins;                     // Sale price in TON
    state: uint2;                     // Sale state (UNINIT, ACTIVE, COMPLETED, CANCELLED)
    commission: coins;                // Marketplace commission amount
    createdAt: uint32;                // Sale creation timestamp
    lastRenewalTime: uint32;          // Last domain renewal timestamp
    validUntil: uint32;               // Sale validity end timestamp
    buyerAddressCell: Cell<address>?; // Buyer address (set when sold)
    domainNameCell: cell;             // Domain name for notifications
    isTgUsername: bool;               // Whether the asset is a Telegram username (.t.me)
    
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

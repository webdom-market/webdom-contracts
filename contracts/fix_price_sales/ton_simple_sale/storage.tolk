import "../../imports/types"

struct Storage {
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
    hotUntil: uint32;                 // Hot promotion end timestamp
    coloredUntil: uint32;             // Colored promotion end timestamp
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
} 
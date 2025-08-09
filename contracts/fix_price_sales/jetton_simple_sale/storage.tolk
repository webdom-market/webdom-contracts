// Additional storage data (stored in separate cell for optimization)
struct StorageDs2 {
    domainAddress: address;       // Address of the domain being sold
    jettonMinterAddress: address; // Address of the jetton minter
    buyerAddress: address;        // Address of the buyer (set when sale is completed)
}

// Jetton Simple Sale contract storage structure
struct Storage {
    jettonWalletAddress: address; // Address of the jetton wallet
    sellerAddress: address;       // Address of the domain seller
    price: coins;                 // Sale price in jettons
    state: uint2;                 // Sale state (UNINIT, ACTIVE, COMPLETED, CANCELLED)
    commission: coins;            // Marketplace commission amount
    createdAt: uint32;            // Sale creation timestamp
    lastRenewalTime: uint32;      // Last domain renewal timestamp
    validUntil: uint32;           // Sale validity end timestamp
    domainNameCell: cell;         // Domain name for notifications
    hotUntil: uint32;             // Hot promotion end timestamp
    coloredUntil: uint32;         // Colored promotion end timestamp
    ds2: Cell<StorageDs2>;        // Additional storage data
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

@inline 
fun Storage.save(self): void {
    contract.setData(self.toCell()) 
}
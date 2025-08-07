tolk 1.0

// Multiple offer contract storage structure
struct Storage {
    ownerAddress: address;           // Owner who can update and withdraw from the offer
    merkleRoot: uint256;             // Merkle tree root for price verification
    soldNftsDict: dict;              // Dictionary of sold NFTs (address -> timestamp)
    jettonBalancesDict: dict;        // Dictionary of jetton balances (wallet -> amount)
    publicKeyCell: Cell<uint256>;    // Public key for signature verification
    commissionFactor: uint16;        // Commission factor for standard payments
    web3CommissionFactor: uint16;    // Special commission factor for WEB3 tokens
    web3WalletAddress: address;      // WEB3 jetton wallet address
}

// Load contract data from persistent storage
fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

// Save contract data to persistent storage
@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}

// Get jetton balance for specific wallet address
@inline
fun Storage.getJettonBalance(self, jettonWalletAddress: address): coins {
    var (jettonBalanceSlice, isFound) = self.jettonBalancesDict.sDictGet(267, jettonWalletAddress as slice);
    if (isFound) {
        return jettonBalanceSlice!.loadCoins();
    } else {
        return 0;
    }
}

// Set jetton balance for specific wallet address
@inline
fun Storage.setJettonBalance(mutate self, jettonWalletAddress: address, jettonBalance: coins): void {
    self.jettonBalancesDict.sDictSetBuilder(267, jettonWalletAddress as slice, beginCell().storeCoins(jettonBalance));
}

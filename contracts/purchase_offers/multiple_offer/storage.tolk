tolk 1.0

struct Storage {
    ownerAddress: address;
    merkleRoot: uint256;
    soldNftsDict: dict;
    jettonBalancesDict: dict;
    publicKeyCell: Cell<uint256>;
    commissionFactor: uint16;
    web3CommissionFactor: uint16;
    web3WalletAddress: address;
}

// load contract data from the persistent storage
fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

// save contract data into the persistent storage
@inline
fun Storage.save(self): void {
    contract.setData(self.toCell())
}

@inline
fun Storage.getJettonBalance(self, jettonWalletAddress: address): coins {
    var (jettonBalanceSlice, isFound) = self.jettonBalancesDict.sDictGet(267, jettonWalletAddress as slice);
    if (isFound) {
        return jettonBalanceSlice!.loadCoins();
    } else {
        return 0;
    }
}

@inline
fun Storage.setJettonBalance(mutate self, jettonWalletAddress: address, jettonBalance: coins): void {
    self.jettonBalancesDict.sDictSetBuilder(267, jettonWalletAddress as slice, beginCell().storeCoins(jettonBalance));
}

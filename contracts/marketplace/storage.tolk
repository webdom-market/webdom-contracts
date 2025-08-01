import "types"

struct MarketplaceStorageDs2 {
    web3WalletAddress: address;
    promotionPrices: dict;    // promotionPeriod -> makeHotPrice(uint64), makeColoredPrice(uint64)
    userSubscriptions: dict;  // userAddress -> subscriptionLevel(uint8), subscriptionEnd(uint32)
    subscriptionsInfo: dict;  // subscriptionLevel -> dict{subscriptionPeriod(uint32) -> subscriptionPrice(uint64)}
}

struct MarketplaceStorage {
    ownerAddress: address;
    publicKey: uint256;

    moveUpSalePrice: coins;
    currentTopSale: address;
    collectedFeesTon: uint64;
    collectedFeesDict: dict;  // walletAddress -> collectedFees(coins)

    deployInfos: dict;  // opCode -> DeployInfo
    contractCodes: Cell<ContractCodes>;
    ds2: Cell<MarketplaceStorageDs2>;
}

fun MarketplaceStorage.load(): MarketplaceStorage {
    return MarketplaceStorage.fromCell(contract.getData());
}

@inline
fun MarketplaceStorage.save(self): void {
    contract.setData(self.toCell());
} 

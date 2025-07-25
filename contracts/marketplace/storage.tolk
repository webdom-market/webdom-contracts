struct MarketplaceStorageDs2 {
    usdtWalletAddress: address;
    collectedFeesDict: dict;  // walletAddress -> collectedFees(coins)
    promotionPrices: dict;  // promotionPeriod -> makeHotPrice(uint64), makeColoredPrice(uint64)
    userSubscriptions: dict;  // userAddress -> subscriptionLevel(uint8), subscriptionEnd(uint32)
    subscriprtionsInfo dict;  // subscriptionLevel -> dict{ subscriptionPeriod}
}

struct MarketplaceStorage {
    ownerAddress: address;
    publicKey: uint256;
    deployInfos: dict;
    moveUpSalePrice: coins;
    currentTopSale: address;
    ds2: Cell<MarketplaceStorageDs2>;
}
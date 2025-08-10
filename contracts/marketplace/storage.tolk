import "types"

struct MarketplaceStorageDs2 {
    web3WalletAddress: address;
    promotionPrices: dict;    // promotionPeriod -> makeHotPrice(uint64), makeColoredPrice(uint64)
    userSubscriptions: dict;  // userAddress -> subscriptionLevel(uint8), subscriptionEnd(uint32)
    subscriptionsInfo: dict;  // subscriptionLevel -> dict{subscriptionPeriod(uint32) -> subscriptionPrice(uint64)}
}

struct MarketplaceStorage {
    ownerAddress: address;                 // Address of the owner of the marketplace
    publicKey: uint256;                    // Public key is used for checking signed messages

    moveUpSalePrice: coins;                // Price of the moving sale to the top (in WEB3)
    currentTopSale: address;               // Address of the current top sale
    collectedFeesTon: uint64;              // Total amount of collected TON fees
    collectedFeesDict: dict;               // A dictionary with all collected jetton fees (jettonWalletAddress -> collectedFees(coins))

    deployInfos: dict;                     // A dictionary that contains information about all available deals (dealIdentificator (uint32) -> deployInfo)
    contractCodes: Cell<ContractCodes>;    // codes are used for calculating jetton wallets addresses and domains addresses
    ds2: Cell<MarketplaceStorageDs2>;
}

fun MarketplaceStorage.load(): MarketplaceStorage {
    return MarketplaceStorage.fromCell(contract.getData());
}

@inline
fun MarketplaceStorage.save(self): void {
    contract.setData(self.toCell());
} 

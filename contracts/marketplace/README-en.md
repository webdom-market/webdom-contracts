# Marketplace

Coordinator of deals (sales/auctions/offers/swaps) for .ton domains and Telegram usernames.

## Storage
See `contracts/marketplace/storage.tolk`:
- `ownerAddress: address`: owner
- `publicKey: uint256`: public key for discount signature verification
- `moveUpSalePrice: coins`: price to move a listing to the top in WEB3
- `currentTopSale: address`: address of the current “top” sale
- `collectedFeesTon: uint64`: accumulated marketplace fees in TON
- `collectedFeesDict: dict`: accumulated fees in jettons (jetton wallet address → amount)
- `deployInfos: dict<uint32, DeployInfo>`: description of all available deal types
- `contractCodes: Cell<ContractCodes>`: codes used to compute domain/wallet addresses
- `ds2: Cell<MarketplaceStorageDs2>`:
  - `web3WalletAddress: address`: marketplace WEB3 wallet address
  - `promotionPrices: dict<uint32, {hotPrice(uint64), coloredPrice(uint64)}>`: promotion prices
  - `userSubscriptions: dict<address, {level(uint8), endTime(uint32)}>`: user subscription info
  - `subscriptionsInfo: dict<uint8, dict<uint32, uint64>>`

## Incoming messages

### Deploying a new deal

The contract accepts three kinds of incoming messages and deploys new deals accordingly:
- SIMPLE: a regular internal TON transfer from a user with attached payload
- NFT_TRANSFER: `NftTransfer` from a domain/username
- JETTON_TRANSFER: `JettonsTransferNotification` from a jetton wallet

All available deal types, their codes and parameters are stored in the `deployInfos` dictionary. For each deal type the marketplace stores the deal contract code and a deploy-function code (continuation) that is executed inside Marketplace to perform the deployment. Some deals charge a fixed deploy fee (`deployFee`).

When requesting a deployment you pass the required deal settings and a special identifier that selects the type. Additionally, the request may include discount information for the marketplace commission. This information must be signed with the application backend’s private key.

### Accepting renewal fees for domains

All webdom contracts support renewing owned domains. A small fixed fee (no more than 0.1 TON) is charged on each renewal.

### Accepting fees from completed deals

Upon successful completion, deals send the marketplace commission (in TON or jettons). The marketplace records the received amounts in `collectedFeesTon` or `collectedFeesDict`.

### Subscription purchases

The marketplace supports purchasing and extending subscriptions that may grant various benefits in the application. Multiple levels and durations are supported.

### Updating information (admin functions)

Since `deployInfos` contains a large amount of data (it stores codes of all deal contracts), the marketplace supports partial updates of this dictionary and adding new items to it. There is also an admin function to assign subscriptions to users (useful for giveaways).

## Get methods
- `get_deploy_info(op: int) → (deployType, deployFee, dealCode, deployFunctionCode, specificInfo)` — returns a record from `deployInfos` by deal identifier
- `get_storage_data() → (...)` — a summary of all storage fields (see layout in `contract.tolk`)



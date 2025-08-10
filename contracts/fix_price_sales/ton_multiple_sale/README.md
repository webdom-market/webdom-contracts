# TON Multiple Sale Contract

Smart contract for selling multiple TON domains as a single bundle at a fixed price using TON as payment.

## Overview

The TON Multiple Sale contract allows a seller to list several domains together and sell them in one purchase using TON. The contract handles activation, receiving all domains, price changes, renewals, promotional features, automatic expiration, and safe cancellation. Buyers purchase by sending the required amount of TON to the contract. Seller pays for storage fees, buyer pays for gas fees.

## Sale Lifecycle

### 1. Creation and Activation
```
Marketplace → FillUpBalanceMessage → Contract
Seller → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract is deployed with specified parameters
- Marketplace activates the sale
- Seller transfers each domain to the contract
- After all domains are received, the contract reserves the required TON for storage and notifies the seller that the sale is active and ready

### 2. Price Management
```
Seller → ChangePriceMessage → Contract
```
- Seller can change the total bundle price and extend validity period
- Commission is recalculated proportionally
- Validity period must be within the domains’ expiration window

### 3. Domain Renewal
```
Seller → RenewDomainMessage → Contract
```
- Seller can renew all domains in the bundle and extend sale validity
- Renewal fee is sent to the Marketplace contract

### 4. Promotional Features
```
Seller → MakeHotMessage/MakeColoredMessage → Contract
```
- Seller can add "hot" or "colored" promotions
- Promotions have expiration timestamps

### 5. Purchase
```
Buyer → Send TON → Contract
```
- Contract verifies sale is active, not expired, all domains are received, and TON amount is sufficient
- Commission is sent to the marketplace
- All domains are transferred to the buyer
- Seller payout is sent in TON; any remaining TON on the contract is forwarded to the seller
- Excess TON is returned to the buyer
- Purchase via dedust swap is supported

### 6. Automatic Expiration
```
Anyone → External Cancel → Contract (if expired)
Domain Contract → DnsBalanceReleaseMessage → Contract (if any domain expires)
```
- Expired sales can be cancelled by anyone via an external message
- Domain expiration automatically cancels the sale
- All received domains are returned back to the seller

### 7. Manual Cancellation
```
Seller/Admin → Cancel Message → Contract
```
- Seller can cancel active sales
- Admin can cancel for moderation purposes
- All received domains are returned to the seller; remaining balance is sent to the seller


## Testing

```shell
npm run contracts:test -- TonMultipleSale
```



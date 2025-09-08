# Jetton Simple Sale Contract

Smart contract for selling TON domains at fixed prices using jettons (USDT or WEB3) as payment.

## Overview

The Jetton Simple Sale contract allows domain owners to sell their domains at fixed prices using jettons instead of TON. The contract handles the entire sale process including price changes, domain renewals, promotional features, and automatic cancellation of expired sales. Buyers can purchase domains by sending the required amount of jettons to the contract. Seller pays for storage fees, buyer pays for gas fees.

## Sale Lifecycle

### 1. Creation and Activation
```
Marketplace → DeployAndSetWalletMessage → Contract
```
- Contract is deployed with specified parameters
- Marketplace sets jetton wallet address and activates sale
- Excess TON is sent to seller
- State changes to ACTIVE

### 2. Price Management
```
Seller → ChangePriceMessage → Contract
```
- Seller can change price and extend validity period
- Commission is recalculated proportionally
- The seller receives a notification about the successful price change, showing the new price with proper jetton decimals applied.

### 3. Domain Renewal
```
Seller → RenewDomainMessage → Contract
```
- Seller can renew domain and extend sale validity
- Renewal fee is sent to Marketplace contract

### 4. Promotional Features
```
Seller → MakeHotMessage/MakeColoredMessage → Contract
```
- Seller can add "hot" or "colored" promotions
- Promotions have expiration timestamps

### 5. Purchase
```
Buyer → Send Jettons → Jetton Wallet → JettonsTransferNotificationMessage → Contract
```
- Contract verifies sale is active and jetton amount is sufficient
- Excess jettons are returned to buyer
- Commission is sent to marketplace in jettons
- Payment is sent to seller in jettons
- Domain is transferred to buyer

### 6. Automatic Expiration
```
Anyone → External Cancel → Contract (if expired)
Domain Contract → DnsBalanceReleaseMessage → Contract (if domain expired)
```
- Expired sales can be cancelled by anyone
- Domain expiration automatically cancels sale

### 7. Manual Cancellation
```
Seller/Admin → Cancel Message → Contract
```
- Seller can cancel active sales
- Admin can cancel for moderation purposes
- Domain is returned to seller


## Differences from the [Getgems contract](https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-fixprice-sale-v4r1.fc)
- Ability to set a sale validity period, after which the sale is automatically canceled (via an external message)
- Ability to renew a domain while it is on sale, and protection against purchasing an expired domain
- Ability to purchase NFT via dedust swap

## Legacy Compatibility

The contract implements legacy get method (`get_fix_price_data_v4()`) for compatibility with existing sparsers of getgems sales.

## Testing

```shell
npm run contracts:get_deploy_functions -- JettonSimpleSale && npm run contracts:test -- Jett_onSimpleSale
```

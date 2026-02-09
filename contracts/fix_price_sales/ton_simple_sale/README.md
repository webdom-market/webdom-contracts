# TON Simple Sale Contract

Smart contract for selling TON domains at fixed prices using TON as payment.

## Overview

The TON Simple Sale contract allows domain owners to sell their domains at fixed prices. The contract handles the entire sale process including price changes, manual renewals, optional prepaid auto-renew, promotional features, and automatic cancellation of expired sales. Buyers can purchase domains by sending the required amount of TON to the contract. Seller pays for storage fees, buyer pays for gas fees.

## Sale Lifecycle

### 1. Creation and Activation
```
Marketplace → FillUpBalanceMessage → Contract
```
- Contract is deployed with domain and sale parameters
- Deploy payload can optionally include `autoRenewCooldown` and `autoRenewIterations`
- `validUntil` above one year from deploy time is allowed only when `autoRenewIterations > 0`
- Marketplace activates the sale
- State changes to ACTIVE

### 2. Price Management
```
Seller → ChangePriceMessage → Contract
```
- Seller can change price and extend validity period
- Commission is recalculated proportionally
- Validity period must be within domain expiration period

### 3. Domain Renewal and Auto-Renew
```
Seller → RenewDomainMessage → Contract
Seller → SetAutoRenewParamsMessage → Contract
Anyone → External Trigger (OP_TRIGGER_AUTORENEW) → Contract
```
- Seller can renew domain and extend sale validity
- Renewal fee is sent to Marketplace contract
- Seller can configure auto-renew cooldown (`1 day ... 1 year - 1 day`) and increase prepaid auto-renew iterations
- Increasing iterations requires TON top-up for auto-renew reserve and marketplace prepay (`0.1 TON` per added iteration)
- External auto-renew consumes one prepaid iteration and renews the domain while the sale is active and cooldown has elapsed
- If balance is insufficient for the next auto-renew (or renewal is too late), the sale is cancelled
- For `.t.me` usernames, renew and auto-renew paths are disabled

### 4. Promotional Features
```
Seller → MakeHotMessage/MakeColoredMessage → Contract
```
- Seller can add "hot" or "colored" promotions
- Promotions have expiration timestamps
- Handled by shared promotion logic

### 5. Purchase
```
Buyer → Send TON → Contract
```
- Contract verifies sale is active and amount is sufficient
- Sends commission to marketplace
- Sends payment to seller
- Transfers domain to buyer

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

## Differences from the [Getgems contract](https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-fixprice-sale-v3r3.fc)
- Ability to set a sale validity period, after which the sale is automatically canceled (via an external message)
- Ability to renew a domain while it is on sale, and protection against purchasing an expired domain
- Ability to prepay and configure scheduled auto-renew while sale is active
- Ability to purchase NFT via dedust swap

## Legacy Compatibility

The contract implements legacy get methods (`get_sale_data()` and `get_fix_price_data()`) for compatibility with existing parsers of getgems sales.

## Testing

```shell
npm run contracts:get_deploy_functions -- TonSimpleSale && npm run contracts:test -- TonSimpleSale
```

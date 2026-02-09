# Jetton Multiple Sale Contract

Smart contract for selling multiple TON domains as a single bundle at a fixed price, using jettons (USDT or WEB3) as payment.

## Overview

The Jetton Multiple Sale contract allows a seller to list several domains together and sell them in one purchase using jettons instead of TON. The contract handles wallet setup, receiving all domains, price changes, manual renewals, optional prepaid auto-renew, promotional features, automatic expiration, and safe cancellation. Buyers purchase by sending the required amount of jettons to the contract. Seller pays for storage fees, buyer pays for gas fees.

## Sale Lifecycle

### 1. Creation and Activation
```
Marketplace → DeployAndSetWalletMessage → Contract
Seller → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract is deployed with specified parameters
- Deploy payload can optionally include `autoRenewCooldown` and `autoRenewIterations`
- `validUntil` above one year from deploy time is allowed only when `autoRenewIterations > 0`
- Marketplace sets jetton wallet address and activates sale
- Seller transfers each domain to the contract
- After all domains are received, the contract reserves the required TON for storage and notifies the seller that the sale is active and ready

### 2. Price Management
```
Seller → ChangePriceMessage → Contract
```
- Seller can change the total bundle price and extend validity period
- Commission is recalculated proportionally
- The seller receives a notification showing the new price with proper jetton decimals applied

### 3. Domain Renewal and Auto-Renew
```
Seller → RenewDomainMessage → Contract
Seller → SetAutoRenewParamsMessage → Contract
Anyone → External Trigger (OP_TRIGGER_AUTORENEW) → Contract
```
- Seller can renew all domains in the bundle and extend sale validity
- Renewal fee is sent to the Marketplace contract
- Seller can configure auto-renew cooldown (`1 day ... 1 year - 1 day`) and increase prepaid auto-renew iterations
- Increasing iterations requires TON top-up for auto-renew reserve (depends on bundle size) and marketplace prepay (`0.1 TON` per added iteration)
- External auto-renew consumes one prepaid iteration and renews all bundle domains while the sale is active and cooldown has elapsed
- Auto-renew trigger works only after all bundle domains are received by the sale contract
- If balance is insufficient for the next auto-renew (or renewal is too late), the sale is cancelled

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
- Contract verifies sale is active, not expired, all domains are received, and jetton amount is sufficient
- Excess jettons are returned to the buyer
- Commission is sent to the marketplace in jettons
- All domains are transferred to the buyer
- Seller payout is sent in jettons; unused TONs are forwarded as part of the transfer
- Purchase via dedust swap is supported through the forward payload

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
npm run contracts:get_deploy_functions -- JettonMultipleSale && npm run contracts:test -- Jett_onMultipleSale
```

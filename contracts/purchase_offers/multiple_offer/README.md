# Multiple Offer Contract

Smart contract for creating multiple purchase offers for TON domains using TON or jettons as payment.

## Overview

The Multiple Offer contract allows users to create a single offer that can purchase multiple different TON domains at different prices. Only the Merkle root is stored on the contract while all detailed data about domains and sale conditions is kept off-chain on the backend. The contract uses Merkle proofs to efficiently verify sale conditions for thousands of domains without storing them on-chain. Buyers can deposit TON and jettons into the contract, and domain owners can sell their domains if they provide a valid Merkle proof and there are enough funds.

## Offer Lifecycle

### 1. Creation
```
Marketplace → MultipleOfferDeployMessage → Contract
```
- Contract sets Merkle root for sale conditions
- Configures commission factors and $WEB3 jetton wallet address
- State changes to ACTIVE

### 2. Funding
```
Offer Creator → Send Jettons → Jetton Wallet → TopUpJettonBalanceMessage → Contract
```
- Offer creator deposits jettons to fund the offer
- Contract tracks balances in any jettons
- TON balance can be filled up via simple message with "fillup" comment

### 3. Domain Sale
```
Domain Owner → Transfer Domain → Domain Contract → SellNftMessage → Contract
```
- Domain owner transfers NFT with Merkle proof
- Contract verifies proof against stored Merkle root
- Extracts price and payment conditions from proof
- Executes sale if conditions are met

### 4. Sale Execution
```
Contract → Send Commission → Marketplace (in TON/jettons)
Contract → Send Payment → Seller (in TON/jettons)
Contract → Transfer Domain → Offer Creator
```

### 5. Updates
```
Offer Creator → SetNewDataMessage → Contract
```
- Offer owner can update Merkle root with new sale conditions
- Requires cryptographic signature for ensuring that the new Merkle Tree is stored on the backend 
- Cleans up old sold NFT records

### 6. Withdrawals
```
Offer Creator → WithdrawSomeTonMessage/WithdrawJettonMessage → Contract
```
- Owner can withdraw TON and jettons
- Partial withdrawals supported

### 7. Cancellation
```
Anyone → "cancel" comment → Contract
```
- Resets contract state
- Returns all funds to owner
- 
## Testing

```shell
python manage.py test MultipleOffer
```

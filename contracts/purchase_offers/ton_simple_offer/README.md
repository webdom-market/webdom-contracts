# TON Simple Offer Contract

Smart contract for creating purchase offers for TON domains using TON as a payment.

## Overview

The TON Simple Offer contract allows users to create purchase offers for specific TON domains. Buyers can deposit TON into the contract, and domain owners can either accept the offer or make counterproposals. The contract handles the entire negotiation process and ensures secure execution of the deal. Offer creator pays for all fees.

## Offer Lifecycle

### 1. Creation
```
Marketplace → FillUpBalanceMessage → Contract
```
- Contract reserves TON for offer execution
- State changes to ACTIVE

### 2. Seller Interaction
```
Domain Owner → Transfer Domain → Domain Contract → NftOwnershipAssignedMessage → Offer Contract
```

**Option A: Accept Offer**
- Empty forward payload
- Contract executes offer immediately

**Option B: Counterproposal**
- Forward payload contains `CounterProposePayload`
- Contract updates seller price
- Buyer gets notification

### 3. Negotiation
```
Seller → CounterProposeMessage → Contract
Buyer → ChangePriceMessage → Contract
```
- Parties can negotiate price
- Offer executes when buyer price ≥ seller price

### 4. Execution
```
Contract → Send Commission → Marketplace
Contract → Send Payment → Seller
Contract → Transfer Domain → Buyer
```

### 5. Cancellation
```
Buyer/Seller → CancelDealMessage → Contract
Anyone → External Cancel → Contract (if expired)
```

## Differences from the [Getgems](https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-offer-v1r3.fc#L320) contract

1. **In the Getgems contract:** the offer price is set without considering TON spent on compute fees and storage fees. Accordingly, if the offer creator performs many operations with it, the gas for them will ultimately be paid by the NFT seller. Additionally, theoretically the offer could become unexecutable if more than 0.065 TON gas is spent in total (in practice this is unlikely to happen).<br> 

   **In the webdom contract:** gas payment is taken into account, it's always paid by the buyer, and the seller receives exactly the proposed NFT price.

2. **In the Getgems contract:** the commission is calculated as a percentage of the funds sent to the offer contract. With a 5% commission, this means that for an offer with a price of exactly 1 TON, you need to send 1.05263 TON, and the result will still be an uneven number, which is not convenient enough.<br>

   **In the webdom contract:** the commission is taken separately, and in a similar case you need to send exactly 1.05 TON.

3. **In the Getgems contract:** canceling an offer using an external message is intended only after the offer's expiration time, while anyone can write anything in the message text that will be sent to the owner upon cancellation (thus, most Getgems offers currently (from 04.2025 to 08.2025) are being canceled with the comment ["send offers in jettons on webdom.market"](https://tonviewer.com/transaction/6fe45c937b9cd5d21a1fc5bfd2e56dbbdf16a834a7a1f504bfb1ba478ad99323)). Additionally, the offer recipient cannot cancel it through an internal transaction — only the offer owner or marketplace can do this.<br>

   **In the webdom contract:** the marketplace can send a signed external message to cancel an offer at any time (for example, if the NFT owner has changed). Additionally, the offer recipient (if specified during deployment) can reject the proposal through an internal message, receiving a small reward for this (currently 0.01 TON). Comments when canceling an offer can only be specified by the marketplace and the NFT owner.


## Legacy Compatibility

The contract implements legacy get methods (`get_offer_data()` and `get_offer_data_v2()`) for compatibility with existing parsers of getgems offers:

## Testing

```shell
npm run contracts:get_deploy_functions -- TonSimpleOffer && npm run contracts:test -- TonSimpleOffer
```
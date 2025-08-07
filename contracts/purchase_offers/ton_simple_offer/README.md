# TON Simple Offer Contract

Smart contract for creating purchase offers for TON domains using TON as a payment.

## Overview

The TON Simple Offer contract allows users to create purchase offers for specific TON domains. Buyers can deposit TON into the contract, and domain owners can either accept the offer or make counterproposals. The contract handles the entire negotiation process and ensures secure execution of the deal.

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

## Legacy Compatibility

The contract implements legacy get methods (`get_offer_data()` and `get_offer_data_v2()`) for compatibility with existing parsers of getgems offers:

## Testing

```shell
python manage.py test TonSimpleOffer
```
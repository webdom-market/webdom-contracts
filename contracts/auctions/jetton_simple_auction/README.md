# Jetton Simple Auction Contract

Smart contract for auctioning a single TON domain with bids paid in jettons (USDT or WEB3).

## Overview

The Jetton Simple Auction is an English-style auction for a domain where bidders pay in jettons. The marketplace deploys and sets a jetton wallet; bidders send jettons to place bids. The contract extends the auction near the end, refunds the previous leader in jettons, can renew the domain when needed, and finalizes by transferring the domain to the winner, paying marketplace commission and seller payout.
The contract supports a deferred auction start: in this mode, the countdown begins only after the first bid is placed.
Successful completion of the auction is guaranteed if there are bids, and all blockchain fees for this action are fully paid by the last bidder.

## Auction Lifecycle

### 1. Activation
```
Marketplace → DeployAndSetWalletMessage → Contract
```
- Contract is deployed with parameters (start/end time, min bid, increments, etc.)
- Marketplace sets the jetton wallet and activates the auction (state → ACTIVE)

### 2. Bidding
```
Bidder → Send Jettons → Jetton Wallet → JettonsTransferNotificationMessage → Contract
```
- Checks auction is active and inside the time window (deferred start supported)
- Enforces minimal next bid: max(lastBid, minBid, lastBid * percentIncrement)
- Extends end time if close to finish (anti-snipe)
- Returns previous bidder’s jettons; if it was the first bid, returns seller’s initial TON reserve
- If the bid amount is greater than or equal to the maximum, the auction is immediately finalized
- Supports DeDust swap payouts via forward payload (extract real sender)

### 3. Promotions
```
Seller → MakeHotMessage/MakeColoredMessage → Contract
```
- Seller can add "hot" or "colored" promotions
- Promotions have expiration timestamps
- Handled by shared promotion logic
  
### 4. Finalization
```
Anyone → External (after end) → Contract
Seller/LastBidder → Internal (after end) → Contract
```
- If auction ended and there is a winner: sends jetton commission to marketplace, sends jetton payout to seller, transfers domain to the winner
- If no bids: returns domain to the seller and cancels the auction

### 5. Cancellation/Stop
```
Seller → Cancel/Stop → Contract
```
- Before first bid: seller can cancel
- After end: seller or last bidder can finalize by internal message, and anyone can trigger auction end by sending an external message.

## Differences from the [Getgems contract](https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-auction-v4r1.func)
- Support for "deferred start" auctions (the auction begins only after the first bid is placed).
- Improved gas management: funds required for auction finalization are reserved with each bid. All unused for gas payments TON are returned to the senders. 
- Protection against domain expiration.

## Legacy Compatibility

Implements legacy get methods (`get_auction_data_v4()`) for compatibility with existing parsers of Getgems contracts.

## Testing

```shell
npm run contracts:get_deploy_functions -- JettonSimpleAuction && npm run contracts:test -- Jett_onSimpleAuction
```

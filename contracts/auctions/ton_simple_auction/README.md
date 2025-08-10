# TON Simple Auction Contract

Smart contract for auctioning a single TON domain with bids paid in TON.

## Overview

The TON Simple Auction is an English-style auction for a domain. The marketplace activates the auction; bidders place TON bids. The contract extends the auction near the end, refunds the previous leader, can renew the domain when needed, and finalizes by transferring the domain to the winner, paying marketplace commission and seller payout.
The contract supports a deferred auction start: in this mode, the countdown begins only after the first bid is placed.
Successful completion of the auction is guaranteed if there are bids, and all blockchain fees for this action are fully paid by the last bidder.

## Auction Lifecycle

### 1. Activation
```
Marketplace → FillUpBalanceMessage → Contract
```
- Contract is deployed with parameters (start/end time, min bid, increments, etc.)
- Marketplace activates the auction (state → ACTIVE)

### 2. Bidding
```
Bidder → Send TON → Contract
```
- Checks auction is active and inside the time window (deferred start supported)
- Computes net bid (reserving TON for finalization, notifications, storage)
- Enforces minimal next bid: max(lastBid + absoluteIncrement, minBid, lastBid * percentIncrement)
- Extends end time if close to finish (anti-snipe)
- Refunds previous bidder; if it was the first bid, returns the seller’s initial reserve
- May renew the domain if it hasn’t been renewed for ~a year
- If the bid amount is greater than or equal to the maximum, the auction is immediately finalized
- Bids via Dedust swaps are supported

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
- If auction ended and there is a winner: pays marketplace commission, send seller payout, transfers domain to the winner
- If no bids: returns domain to the seller and cancels auction

### 5. Cancellation/Stop
```
Seller → Cancel/Stop → Contract
```
- Before first bid: seller can cancel
- After end: seller or last bidder can finalize by internal message, and anyone can trigger auction end by sending an external message.


## Differences from the [Getgems contract](https://github.com/getgems-io/nft-contracts/blob/main/packages/contracts/sources/nft-auction-v3r3/nft-auction-v3r3.func)
- Support for "deferred start" auctions (the auction begins only after the first bid is placed).
- Improved gas management: funds required for auction finalization are reserved with each bid. All unused for gas payments TON are returned to the senders. 
- Protection against domain expiration.


## Legacy Compatibility

Implements legacy get methods (`get_auction_data()` and `get_sale_data()`) for compatibility with existing parsers of Getgems contracts

## Testing

```shell
python manage.py test TonSimpleAuction
```

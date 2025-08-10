# TON Multiple Auction Contract

Smart contract for auctioning multiple TON domains as a single bundle with bids paid in TON.

## Overview

The TON Multiple Auction is an English-style auction for a bundle of domains. The marketplace activates the auction; the seller transfers all domains to the contract; bidders place TON bids. The contract extends the auction near the end (anti-snipe), refunds the previous leader, and finalizes by transferring all domains to the winner and paying the seller.

- Supports deferred start: countdown begins only after the first bid is placed.
- Activation after all domains are received and TON reserve is set.
- Successful completion is guaranteed if there are bids. All blockchain fees for finalization are paid by the last bidder.
- Auction participants are protected from purchasing expired domains.
  
## Auction Lifecycle

### 1. Activation and Receiving Assets
```
Marketplace → FillUpBalanceMessage → Contract
Seller → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract is deployed with parameters (start/end time, min bid, increments, etc.)
- Marketplace activates the auction (state → ACTIVE)
- Seller transfers each domain NFT to the contract
- After all domains are received, the contract reserves required TON and notifies the seller that the auction is ready

### 2. Bidding
```
Bidder → Send TON → Contract
```
- Checks auction is active, within the time window (with deferred start support), and all domains have been received
- Computes net bid (reserving TON for notifications, storage, and safe finalization)
- Enforces minimal next bid: max(lastBid + absoluteIncrement, minBid, lastBid * percentIncrement)
- Extends end time if close to finish (anti-snipe), bounded by domain expiration window
- Refunds previous bidder; if it was the first bid, returns the seller’s initial reserve
- If bid amount is greater than or equal to the maximum, the auction is immediately finalized
- Bids via DeDust swaps are supported and handled via special payload

### 3. Promotions
```
Seller → MakeHotMessage / MakeColoredMessage → Contract
```
- Seller can add "hot" or "colored" promotions
- Promotions have expiration timestamps

### 4. Renewal (optional)
```
Anyone → RenewDomainMessage → Contract
```
- Anyone can renew all domains during the auction period
- Renewal fee is sent to the marketplace

### 5. Finalization
```
Anyone → External (after end) → Contract
Seller/LastBidder → Internal (after end) → Contract
```
- If auction ended and there is a winner: pays marketplace commission, sends seller payout, transfers all domains to the winner
- If no bids: returns all received domains to the seller and cancels the auction

### 6. Cancellation/Stop
```
Seller → Cancel/Stop → Contract
```
- Before the first bid: seller can cancel
- After end: seller or last bidder can finalize by internal message, and anyone can trigger auction end by external message


## Testing

```shell
python manage.py test TonMultipleAuction
```

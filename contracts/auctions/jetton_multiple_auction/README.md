# Jetton Multiple Auction Contract

Smart contract for auctioning multiple TON domains as a single bundle with bids paid in jettons (USDT or WEB3).

## Overview

The Jetton Multiple Auction is an English-style auction for a bundle of domains. The marketplace deploys and sets a jetton wallet; the seller transfers all domains to the contract; bidders place bids by sending jettons. The contract uses anti‑snipe time extension, refunds the previous leader in jettons, and finalizes by transferring all domains to the winner and paying the seller in jettons.

- Supports deferred start: countdown begins only after the first bid is placed.
- Auction becomes fully ready after all domains are received and a minimal TON reserve is set.
- Successful completion is guaranteed if there are bids. All blockchain fees for finalization are paid by the last bidder.
- Auction participants are protected from purchasing expired domains.

## Auction Lifecycle

### 1. Activation and Receiving Assets
```
Marketplace → DeployAndSetWalletMessage → Contract
Seller → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract is deployed with parameters (start/end time, min bid, increments, etc.)
- Marketplace sets the jetton wallet and activates the auction (state → ACTIVE)
- Seller transfers each domain NFT to the contract
- After all domains are received, the contract reserves required TON and notifies the seller that the auction is ready

### 2. Bidding
```
Bidder → Send Jettons → Jetton Wallet → JettonsTransferNotificationMessage → Contract
```
- Ensures auction is active, within time window (with deferred start support), and all domains have been received
- Minimal next bid is enforced: max(lastBid, minBid, lastBid * percentIncrement)
- Extends end time if close to finish (anti‑snipe), bounded by domain expiration window
- Returns the previous bidder’s jettons; if it was the first bid, returns the seller’s initial TON reserve
- Supports DeDust swap payouts via forward payload (real sender is extracted)
- If the bid is greater than or equal to the maximum, the auction is immediately finalized

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
- If auction ended and there is a winner: sends jetton commission to marketplace, sends jetton payout to seller, transfers all domains to the winner
- If no bids: returns all received domains to the seller and cancels the auction

### 6. Cancellation/Stop
```
Seller → Cancel/Stop → Contract
```
- Before the first bid: seller can cancel
- After end: seller or last bidder can finalize by internal message, and anyone can trigger auction end by external message

## Testing

```shell
npm run contracts:get_deploy_functions -- JettonMultipleAuction && npm run contracts:test -- Jett_onMultipleAuction
```

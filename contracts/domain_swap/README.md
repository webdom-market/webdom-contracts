# Domain Swap Contract

Smart contract for trustless two-sided swapping of NFTs with optional TON top-up payments from both sides.

## Overview

The Domain Swap contract coordinates an exchange between two participants (left and right). Each side must:
- Transfer all agreed domain NFTs to the contract
- Provide the required TON payment (if any)

Once the left side fully delivers, the deal switches to waiting for the right side. When the right side also fully delivers, the swap completes atomically: each participant receives the other side’s assets and final payments are settled. Marketplace receives fixed fee only for completed swaps.

## Swap Lifecycle

### 1. Activation
```
Marketplace → FillUpBalanceMessage → Contract
```
- Marketplace activates the contract (set state from CANCELLED to WAITING_FOR_LEFT)

### 2. Left Side Delivery
```
Left → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract verifies the swap is active and not expired
- The domain address must be present in the expected left-side list
- Attached TON (minus blockchain fee) is counted toward left’s payment
- When all left domains are received and payment is fully covered, the contract completes the left part and switches to WAITING_FOR_RIGHT

### 3. Right Side Delivery
```
Right → NftTransfer (per domain) → Contract → NftOwnershipAssignedMessage
```
- Contract verifies the swap is now waiting for the right side
- The domain address must be present in the expected right-side list
- Attached TON (minus a small processing fee) is counted toward right’s payment
- When all right domains are received and payment is fully covered, the contract completes the deal atomically and finalizes

### 4. Additional Payments
```
Left/Right → Internal (op = 0) → Contract
```
- Either side can top up the required payment via an internal message, if it wasn't fully covered during transferring domains stage
- When the required amount is fully covered and all domains from that side were received, the contract proceeds (left side completion or full deal completion)

### 5. Validity Extension
```
Left → ChangeValidUntilMessage → Contract
```
- Left participant can extend `validUntil`
- Constraints: at least +5 minutes from now and less than one year from creation

### 6. Cancellation
```
Left/Right → Internal (op = OP_CANCEL_DEAL) → Contract
```
- Left can cancel if the right has not joined yet, or if the right was inactive for more than 1 hour, or if the deal has expired
- Right can cancel at any time; a small TON reward is added for the right when canceling
- On cancellation, all domains are returned to their respective owners, and a notification is sent

### 7. Expiration
```
Anyone → External (op = OP_CANCEL_DEAL, after `validUntil`) → Contract
```
- When expired, anyone can trigger cancellation via an external message
- All domains are returned to their owners and the deal is closed

## Testing

```shell
npm run contracts:get_deploy_functions -- DomainSwap && npm run contracts:test -- DomainSwap
```

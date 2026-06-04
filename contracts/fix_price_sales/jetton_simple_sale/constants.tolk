import "../../imports/constants"
import "../../imports/gas"

// Compute gas (gas units) for the jetton purchase handler (JettonsTransferNotification path), MEASURED
// in tests/JettonSimplePurchaseGas.spec.ts: ~14,340 gas normal, ~17,460 gas on the heavier
// dedust/excess branch (parses the forward payload, then emits a THIRD jetton send to return excess
// on top of the marketplace commission + seller payout + domain transfer). 25000 is ~1.4x that
// worst case — the same margin the TON sale's GAS_TON_SIMPLE_PURCHASE keeps over its measured worst.
const GAS_JETTON_SIMPLE_PURCHASE: int = 25000;
// Compute gas (gas units) for the unattended auto-renew trigger handler, mirroring the TON simple
// sale (tests/GasResearch*.spec.ts): external auto-renew trigger ~6,500 gas (worst case = cancel
// branch ~9,500). Margin kept generous for the unattended keeper-driven trigger (no retry path).
const GAS_AUTORENEW_TX_PER_ITER: int = 15000;
// Activation handler (DeployAndSetWallet: STATE_UNINIT -> STATE_ACTIVE); 10000 is ~2x the TON
// sale's measured ~4,770 gas (tests/DeployGas.spec.ts), the extra headroom covering the jetton
// handler's additional wallet-address field.
const GAS_SALE_DEPLOY: int = 10000;

// Contract size (code+data) for storage-rent computation. The jetton simple sale mirrors the TON
// one in shape/size, so it reuses the same bounds: 66 cells / 36,000 bits measured for TonSimpleSale
// (asserted in tests/GasSize.spec.ts), padded to 80c / 40,000b.
const SALE_STORAGE_CELLS: int = 80;
const SALE_STORAGE_BITS: int  = 40000;

@inline
fun saleStorageReserve(seconds: int): coins {
    return storageFee(seconds, SALE_STORAGE_BITS, SALE_STORAGE_CELLS);
}

// Value a buyer attaches beyond the price = the NFT transfer to the domain (compute+forward,
//   computed) + new-owner notification + the sale handler's own compute + its payout forward.
@inline
fun jettonSimplePurchaseFee(): coins {
    return nftTransferFee() + TONS_PURCHASE_NOTIFICATION
         + gasFee(GAS_JETTON_SIMPLE_PURCHASE)
         + TONS_JETTON_TRANSFER * 3 + TONS_NOTIFY_MARKETPLACE
}

// Per-iteration auto-renew lock = one year of the SALE's own storage + the domain renewal cost
//   (renewDomainFee: domain storage+compute+forward) + the trigger handler's own compute gas.
@inline
fun autoRenewLockPerIter(): coins {
    return saleStorageReserve(ONE_YEAR)
         + renewDomainFee()
         + gasFee(GAS_AUTORENEW_TX_PER_ITER);
}

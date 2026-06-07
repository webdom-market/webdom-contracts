import "../../imports/constants"
import "../../imports/gas"

// Jetton purchase handler compute (JettonsTransferNotification path, JettonSimplePurchaseGas.spec.ts):
// ~14,426 normal, ~17,540 on the dedust/excess branch (THIRD jetton send to return excess). 25000 is
// ~1.4x worst case — same margin as the TON sale's GAS_TON_SIMPLE_PURCHASE.
const GAS_JETTON_SIMPLE_PURCHASE: int = 25000;
// Unattended auto-renew trigger compute, mirroring the TON simple sale: ~6,500 gas (worst case = cancel
// branch ~9,500, CancelGas.spec.ts). Generous margin for the keeper trigger (no retry path).
const GAS_AUTORENEW_TX_PER_ITER: int = 15000;
// SetAutoRenewParams top-up handler's own compute — buffer above the newly-locked iterations so this
// tx's compute stays funded after reserveToncoinsOnBalance. MEASURED ~10,124 gas (0->2 iters,
// validUntil-derived branch); 15000 is ~1.5x, matching the TON simple sale's identical handler.
const GAS_AUTORENEW_TOPUP: int = 15000;
// Activation handler (DeployAndSetWallet: STATE_UNINIT -> STATE_ACTIVE); 8000 is ~2x the TON sale's
// measured ~4,287 gas (DeployGas.spec.ts), headroom for the jetton handler's extra wallet-address field.
const GAS_SALE_DEPLOY: int = 8000;

// Contract size (code+data) for storage rent. Mirrors the TON simple sale, reusing its bounds: measured
// 68c / 37,637b for TonSimpleSale (SaleGasSize.spec.ts), padded to 80c / 40,000b.
const SALE_STORAGE_CELLS: int = 80;
const SALE_STORAGE_BITS: int  = 40000;

@inline
fun saleStorageReserve(seconds: int): coins {
    return storageFee(seconds, SALE_STORAGE_BITS, SALE_STORAGE_CELLS);
}

// Value a buyer attaches beyond the price: NFT transfer to the domain + new-owner notification + the
// handler's own compute + 3 jetton sends (excess-return + commission + seller payout) + marketplace notify.
@inline
fun jettonSimplePurchaseFee(): coins {
    return nftTransferFee() + TONS_PURCHASE_NOTIFICATION
         + gasFee(GAS_JETTON_SIMPLE_PURCHASE)
         + TONS_JETTON_TRANSFER * 3 + TONS_NOTIFY_MARKETPLACE
}

// Per-iteration auto-renew lock = sale's own storage for ONE cooldown period (auto-renew extends
// validUntil by autoRenewCooldown per iteration, NOT a full year) + domain renewal cost (renewDomainFee)
// + the trigger handler's own compute. Mirrors the multiple sale's getAutoRenewLockPerIter (sans domainsTotal=1).
@inline
fun autoRenewLockPerIter(autoRenewCooldown: uint32): coins {
    return saleStorageReserve(autoRenewCooldown)
         + renewDomainFee()
         + gasFee(GAS_AUTORENEW_TX_PER_ITER);
}

import "../../imports/constants"
import "../../imports/gas"

// --- Compute-gas budgets (gas units), sized from measured consumption + safety margin ---
//   purchase ~12,500 ; set-auto-renew ~10,000 ; external trigger ~6,500 (worst case = cancel branch
//   ~9,500, CancelGas.spec.ts). Generous margin for the keeper trigger (no retry path).
const GAS_TON_SIMPLE_PURCHASE: int   = 20000;
const GAS_AUTORENEW_TX_PER_ITER: int = 15000;
const GAS_AUTORENEW_TOPUP: int       = 15000;
// Activation handler (FillUpBalance: STATE_UNINIT -> STATE_ACTIVE); 8000 is ~2x measured ~4,287 gas
// (DeployGas.spec.ts), margin for data growth and minor code changes.
const GAS_SALE_DEPLOY: int           = 8000;

// Contract size (code+data) for storage rent. Measured 68c / 37,637b for TonSimpleSale
// (SaleGasSize.spec.ts), padded to 80c / 40,000b for data growth and minor code changes.
const SALE_STORAGE_CELLS: int = 80;
const SALE_STORAGE_BITS: int  = 40000;

@inline
fun saleStorageReserve(seconds: int): coins {
    return storageFee(seconds, SALE_STORAGE_BITS, SALE_STORAGE_CELLS);
}

// Value a buyer attaches beyond the price: NFT transfer to the domain + new-owner notification + the
// handler's own compute + its payout forward.
@inline
fun tonSimplePurchaseFee(): coins {
    return nftTransferFee() + TONS_PURCHASE_NOTIFICATION
         + gasFee(GAS_TON_SIMPLE_PURCHASE)
         + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS);
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

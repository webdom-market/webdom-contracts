import "../../imports/constants"
import "../../imports/gas"

// External auto-renew trigger compute (TriggerGas.spec.ts): ~7,042 fixed + ~2,647/domain.
// Padded ~1.7x base / ~1.9x per-domain — generous, the keeper trigger has no retry path.
// (Per-domain renewal VALUE is priced separately as renewDomainFee below.)
const GAS_AUTORENEW_TRIGGER_BASE: int  = 12000;
const GAS_AUTORENEW_TX_PER_DOMAIN: int = 5000;
// SetAutoRenewParams top-up handler's own compute — buffer above the newly-locked iterations so this
// tx's compute stays funded after reserveToncoinsOnBalance. MEASURED ~11,085 gas (0->2 iters, 4-domain
// bundle; handler doesn't iterate the dict, so independent of domain count); 18000 is ~1.6x.
const GAS_AUTORENEW_TOPUP: int          = 18000;

// Multiple-sale contract size (code+data) for storage rent, padded. Measured (SaleGasSize.spec.ts):
// TON code 76c/47824b, base(0 domains) 77c/48418b, jetton code 78c/49003b; domains dict adds ~+2 cells
// / +261 bits per domain. Padded so the model dominates BOTH variants up to 50 domains.
const MULTI_SALE_BASE_CELLS: int       = 90;
const MULTI_SALE_BASE_BITS: int        = 50000;  // measured base ~48,418b, padded
const MULTI_SALE_PER_DOMAIN_CELLS: int = 3;
const MULTI_SALE_PER_DOMAIN_BITS: int  = 320;

// Sale's own storage rent for `seconds`, scaling with domain count. From measured size at live price:
// ~0.046 TON/yr at 1 domain rising to ~0.089 TON/yr at 50 (classic basechain price).
@inline
fun saleStorageReserve(seconds: int, domainsTotal: int): coins {
    return storageFee(
        seconds,
        MULTI_SALE_BASE_BITS  + MULTI_SALE_PER_DOMAIN_BITS  * domainsTotal,
        MULTI_SALE_BASE_CELLS + MULTI_SALE_PER_DOMAIN_CELLS * domainsTotal
    );
}

// External-cancel compute (CancelGas.spec.ts): ~6,581 fixed + ~3,612/domain (return loop builds one
// NFT-transfer per domain). Cancel carries NO incoming value, so the contract holds this compute on top
// of domainRefillFee()*N; the reserve budgets it so a drained sale returns EVERY domain. ~1.5x / ~1.4x.
const GAS_CANCEL_BASE: int       = 10000;
const GAS_CANCEL_PER_DOMAIN: int = 5000;

@inline
fun cancelGasBudget(domainsTotal: int): coins {
    return gasFee(GAS_CANCEL_BASE + GAS_CANCEL_PER_DOMAIN * domainsTotal);
}

// Per iteration: sale's own storage for ONE cooldown period (auto-renew extends validUntil by
// autoRenewCooldown per iteration, NOT a full year) + per-domain renewal value × all domains + the
// trigger's own compute (base + per-domain). Every term tracks live prices.
@inline
fun getAutoRenewLockPerIter(domainsTotal: uint8, autoRenewCooldown: uint32): coins {
    return saleStorageReserve(autoRenewCooldown, domainsTotal)
         + renewDomainFee() * domainsTotal
         + gasFee(GAS_AUTORENEW_TRIGGER_BASE + GAS_AUTORENEW_TX_PER_DOMAIN * domainsTotal);
}

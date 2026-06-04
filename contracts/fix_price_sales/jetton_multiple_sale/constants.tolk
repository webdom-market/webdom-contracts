import "../../imports/constants"
import "../../imports/gas"

// External auto-renew trigger compute, MEASURED in tests/TriggerGas.spec.ts: ~7,200 gas fixed
// (load storage, asserts, reserve calc) + ~2,560 gas per domain (one dict step + one renew message).
// Padded ~1.6x base / ~2x per-domain — generous since the keeper-driven trigger has no retry path.
// (The per-domain renewal VALUE it sends is priced separately as renewDomainFee below.)
const GAS_AUTORENEW_TRIGGER_BASE: int  = 12000;
const GAS_AUTORENEW_TX_PER_DOMAIN: int = 5000;

// Measured multiple-sale contract size (code + data) for storage-rent computation, with padding.
// Measured (tests/GasSize.spec.ts): TON code 76c/44190b, base(0 domains) 77c/44784b, jetton code
// 79c/46011b; the domains dict adds ~+2 cells / +261 bits per domain. We pad base to 90c/48000b and
// per-domain to 3c/320b so the model dominates BOTH variants at up to 50 domains. Asserted in GasSize.
const MULTI_SALE_BASE_CELLS: int       = 90;
const MULTI_SALE_BASE_BITS: int        = 50000;  // measured base ~48,160b after cancel-gas/cooldown additions; padded
const MULTI_SALE_PER_DOMAIN_CELLS: int = 3;
const MULTI_SALE_PER_DOMAIN_BITS: int  = 320;

// The sale contract's OWN storage rent for `seconds`, scaling with the number of domains it holds
// (the domains dict). Computed from the measured contract size (MULTI_SALE_BASE_* plus the per-domain
// growth) at the live storage price, so it tracks the real on-chain cost: ~0.046 TON/yr at 1 domain,
// rising to ~0.089 TON/yr at 50 domains (at the classic basechain storage price).
@inline
fun saleStorageReserve(seconds: int, domainsTotal: int): coins {
    return storageFee(
        seconds,
        MULTI_SALE_BASE_BITS  + MULTI_SALE_PER_DOMAIN_BITS  * domainsTotal,
        MULTI_SALE_BASE_CELLS + MULTI_SALE_PER_DOMAIN_CELLS * domainsTotal
    );
}

// External-cancel COMPUTE, MEASURED in tests/AuditCancelGas.spec.ts: ~6,400 gas fixed + ~3,610 gas
// per domain (the return loop builds one NFT-transfer per received domain). The cancel carries NO
// incoming value, so the contract must hold this compute itself ON TOP of domainRefillFee()*N. The
// reserve (getTonsToReserve) budgets it so a maximally storage-drained sale can still return EVERY
// domain instead of silently skipping one via SEND_MODE_IGNORE_ERRORS. Padded ~1.6x base / ~1.4x slope.
const GAS_CANCEL_BASE: int       = 10000;
const GAS_CANCEL_PER_DOMAIN: int = 5000;

@inline
fun cancelGasBudget(domainsTotal: int): coins {
    return gasFee(GAS_CANCEL_BASE + GAS_CANCEL_PER_DOMAIN * domainsTotal);
}

// Per iteration: the sale's own storage for ONE cooldown period (the sale only lives until validUntil,
// which auto-renew extends by `autoRenewCooldown` per iteration — NOT a full year per iteration) + the
// computed per-domain renewal value for every domain + the trigger's own compute (fixed base +
// per-domain). Every term tracks live prices.
@inline
fun getAutoRenewLockPerIter(domainsTotal: uint8, autoRenewCooldown: uint32): coins {
    return saleStorageReserve(autoRenewCooldown, domainsTotal)
         + renewDomainFee() * domainsTotal
         + gasFee(GAS_AUTORENEW_TRIGGER_BASE + GAS_AUTORENEW_TX_PER_DOMAIN * domainsTotal);
}

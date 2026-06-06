import "@stdlib/gas-payments"
import "constants"

/**
  Runtime fee helpers — compute each TON budget from CURRENT on-chain prices at call time, so the
  value attached to a message always matches the real cost as prices change.

  Three cost types, each from its own config param:
    - compute gas    -> calculateGasFee     (config 21)
    - message forward-> calculateForwardFee  (config 25)
    - storage rent   -> calculateStorageFee  (config 18)

  Inputs are MEASURED units (sized from GasResearch*.spec.ts). We pass a measured contract size
  rather than calling CDATASIZE at runtime (~7k gas/call): size is fixed per compiled contract
  (asserted in SaleGasSize.spec.ts), only price is dynamic.

  Excluded (no live price to track): the jetton wallet floor (TONS_JETTON_TRANSFER) and marketplace fees.
*/

/// Fee for `gasUnits` of compute gas at the current gas price.
@inline
fun gasFee(gasUnits: int): coins {
    return calculateGasFee(WORKCHAIN as int8, gasUnits);
}

/// Forward fee for one message of the given body size at the current forward price.
/// Pass a conservative single-cell size; lump_price dominates for small messages.
@inline
fun forwardFee(bits: int, cells: int): coins {
    return calculateForwardFee(WORKCHAIN as int8, bits, cells);
}

/// Storage rent to keep a contract of (bits, cells) alive for `seconds` at the current storage price.
@inline
fun storageFee(seconds: int, bits: int, cells: int): coins {
    return calculateStorageFee(WORKCHAIN as int8, seconds, bits, cells);
}


/* ---- Domain (TON DNS item / TG username) fee helpers ---- */
// Measured (TransferGas.spec.ts) at 50 DNS records, code+data, per item type:
//   TON DNS domain : 10,855 transfer gas ; 195 cells / 28,232 bits
//   TG username    :  9,526 transfer gas ; 199 cells / 33,359 bits
// The item keeps >= min_tons_for_storage (~1 TON) itself — its transfer handler throws 402 rather than
// drop below that reserve (domain.fc:92). So a plain transfer pays only compute + its two onward
// forwards; storage is funded by the item's own reserve and yearly by renewDomainFee (.ton only).
// A transfer that finds the item drained below its reserve must REFILL it — see domainRefillFee().
const DOMAIN_STORAGE_CELLS: int = 200;     // .ton domain, 50 records (195 measured), padded — for renew/refill
const DOMAIN_STORAGE_BITS: int  = 34000;   // >= 28,232
// Measured transfer_ownership compute is ~11k gas (domain) / ~9.5k (TG); ~1.5x margin.
const DOMAIN_TRANSFER_GAS: int  = 16000;
const DOMAIN_RENEW_GAS: int     = 8000;    // ~1.6x measured renew/fill-up compute (~4.8k)
const DOMAIN_MSG_BITS: int      = 1023;    // conservative single-cell message
const DOMAIN_MSG_CELLS: int     = 1;

/// Value for an NFT (domain / TG username) transfer: transfer compute + its two onward forwards
/// (ownership_assigned + excess). No storage — the item keeps its own ~1-TON reserve; tight
/// fixed-value paths top it up via domainRefillFee().
@inline
fun nftTransferFee(): coins {
    return gasFee(DOMAIN_TRANSFER_GAS) + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS) * 2;
}

/// One year of a domain item's storage rent at the live price. Keeps the item funded above its reserve:
/// the storage top-up in a renewal, and the refill buffer on fixed-value transfers.
@inline
fun domainStorageYear(): coins {
    return storageFee(ONE_YEAR, DOMAIN_STORAGE_BITS, DOMAIN_STORAGE_CELLS);
}

/// Value for moving a domain with a FIXED amount (no CARRY_ALL) that may have drained below its
/// reserve: transfer cost + one year of storage to refill it, so its 402 reserve check passes.
@inline
fun domainRefillFee(): coins {
    return nftTransferFee() + domainStorageYear();
}

/// Value for a domain renewal: one year of storage (≤50 records) + renew compute + one forward.
/// Renewal applies ONLY to .ton domains.
@inline
fun renewDomainFee(): coins {
    return domainStorageYear()
         + gasFee(DOMAIN_RENEW_GAS)
         + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS);
}

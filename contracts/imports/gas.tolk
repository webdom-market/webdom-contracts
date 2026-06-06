import "@stdlib/gas-payments"
import "constants"

/**
  Runtime fee helpers — compute each TON gas/storage/forward budget from the CURRENT on-chain
  prices at call time, so the value a contract attaches to a message always matches the real
  network cost even as those prices change.

  Three independent cost types, each read from its own network config param:
    - compute gas    -> calculateGasFee     (config 21)
    - message forward-> calculateForwardFee  (config 25)
    - storage rent   -> calculateStorageFee  (config 18)

  Inputs are MEASURED units (gas units; message bits/cells; contract bits/cells), sized from
  tests/fix_price_sales/GasResearch*.spec.ts. We pass a measured contract size rather than calling CDATASIZE at
  runtime: CDATASIZE walks every code+data cell (~66 here) and costs ~7k gas per call — wasteful
  on a hot/high-stakes path. The size is a fixed property of the compiled contract (asserted in
  tests/fix_price_sales/SaleGasSize.spec.ts); only the *price* is dynamic.

  Excluded (not a gas/storage/forward cost, so there is no live price to track): the jetton wallet
  floor (TONS_JETTON_TRANSFER) and marketplace business fees.
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
// Measured (tests/shared/TransferGas.spec.ts) at 50 DNS records, code+data, per item type:
//   TON DNS domain : 10,855 transfer gas ; 195 cells / 28,232 bits
//   TG username    :  9,526 transfer gas ; 199 cells / 33,359 bits
// The item ITSELF guarantees it always keeps >= min_tons_for_storage (~1 TON) — its transfer handler
// throws (402) rather than let the balance drop below that reserve (domain.fc:92). So a plain
// transfer only has to pay compute + the item's two onward forwards; it does NOT pre-fund storage.
// Storage is funded (a) once, by the item's own ~1-TON reserve, and (b) yearly, by renewDomainFee
// for .ton domains. A transfer that finds the item already drained below its reserve must REFILL it
// — see domainRefillFee(), used only on the tight REGULAR-mode multiple-auction/sale payouts.
const DOMAIN_STORAGE_CELLS: int = 200;     // .ton domain, 50 records (195 measured), padded — for renew/refill
const DOMAIN_STORAGE_BITS: int  = 34000;   // >= 28,232
// Measured transfer_ownership compute is ~11k gas (domain) / ~9.5k (TG); ~1.5x margin.
const DOMAIN_TRANSFER_GAS: int  = 16000;
const DOMAIN_RENEW_GAS: int     = 8000;    // ~1.6x measured renew/fill-up compute (~4.8k)
const DOMAIN_MSG_BITS: int      = 1023;    // conservative single-cell message
const DOMAIN_MSG_CELLS: int     = 1;

/// Value to attach to an NFT (domain / TG username) transfer: the item's transfer compute + its two
/// onward forwards (ownership_assigned + excess). NO storage — the item keeps its own ~1-TON reserve,
/// and contracts that move a domain either forward their whole balance to it (CARRY_ALL) or top it
/// up via domainRefillFee() on the tight fixed-value paths.
@inline
fun nftTransferFee(): coins {
    return gasFee(DOMAIN_TRANSFER_GAS) + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS) * 2;
}

/// One year of a (.ton domain) item's storage rent at the live price. Used to keep the item funded
/// above its reserve: as the storage top-up in a renewal, and as the refill buffer on fixed-value
/// transfers where the item can't be paid via CARRY_ALL.
@inline
fun domainStorageYear(): coins {
    return storageFee(ONE_YEAR, DOMAIN_STORAGE_BITS, DOMAIN_STORAGE_CELLS);
}

/// Value to attach where a domain is moved with a FIXED amount (no CARRY_ALL) and may have drained
/// below its reserve: transfer cost + one year of storage to refill it. Guarantees the item stays
/// funded for storage so its 402 reserve check passes.
@inline
fun domainRefillFee(): coins {
    return nftTransferFee() + domainStorageYear();
}

/// Value to attach to a domain renewal: one year of the item's storage (≤50 records) at the live
/// storage price + the renew compute + one forward. Renewal applies ONLY to .ton domains.
@inline
fun renewDomainFee(): coins {
    return domainStorageYear()
         + gasFee(DOMAIN_RENEW_GAS)
         + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS);
}

import "../../imports/constants"
import "../../imports/gas"

// --- Measured units (from tests/GasResearch*.spec.ts + tests/GasSize.spec.ts) ---
// Compute gas (gas units), sized from measured consumption + a safety margin:
//   purchase handler ~12,500 gas ; set-auto-renew ~10,000 ; external auto-renew trigger ~6,500 gas
//   (worst case = cancel branch ~9,500). Margin kept generous for the unattended keeper-driven
//   trigger (no retry path).
const GAS_TON_SIMPLE_PURCHASE: int   = 20000;
const GAS_AUTORENEW_TX_PER_ITER: int = 15000;
const GAS_AUTORENEW_TOPUP: int       = 15000;
// Activation handler (FillUpBalance: STATE_UNINIT -> STATE_ACTIVE); 10000 is ~2x the measured
// ~4,770 gas (tests/DeployGas.spec.ts), the margin covering data growth and minor code changes.
const GAS_SALE_DEPLOY: int           = 10000;

// Contract size (code+data) for storage-rent computation. Measured 66 cells / 36,000 bits for
// TonSimpleSale (asserted in tests/GasSize.spec.ts), padded to 80c / 40,000b for data growth and
// minor code changes.
const SALE_STORAGE_CELLS: int = 80;
const SALE_STORAGE_BITS: int  = 40000;

// Conservative size of a single-cell internal message, for forward-fee estimation.
const FWD_MSG_BITS: int  = 1023;
const FWD_MSG_CELLS: int = 1;

@inline
fun saleStorageReserve(seconds: int): coins {
    return storageFee(seconds, SALE_STORAGE_BITS, SALE_STORAGE_CELLS);
}

// Value a buyer attaches beyond the price = the NFT transfer to the domain (compute+forward,
//   computed) + new-owner notification + the sale handler's own compute + its payout forward.
@inline
fun tonSimplePurchaseFee(): coins {
    return nftTransferFee() + TONS_PURCHASE_NOTIFICATION
         + gasFee(GAS_TON_SIMPLE_PURCHASE)
         + forwardFee(FWD_MSG_BITS, FWD_MSG_CELLS);
}

// Per-iteration auto-renew lock = one year of the SALE's own storage + the domain renewal cost
//   (renewDomainFee: domain storage+compute+forward) + the trigger handler's own compute gas.
@inline
fun autoRenewLockPerIter(): coins {
    return saleStorageReserve(ONE_YEAR)
         + renewDomainFee()
         + gasFee(GAS_AUTORENEW_TX_PER_ITER);
}

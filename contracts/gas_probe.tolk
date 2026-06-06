import "imports/constants"
import "imports/gas"
import "fix_price_sales/constants"
import "fix_price_sales/ton_simple_sale/constants"
import "auctions/constants"
import "purchase_offers/constants"
import "domain_swap/constants"

// Read-only probe: exposes the migrated fee helpers (and the three fee PRIMITIVES) as get-methods
// so a test can read the EXACT on-chain value under whichever network price config the sandbox runs.
// (The multiple-sale composites are reconstructed in the test from the primitives to avoid the
//  saleStorageReserve name collision between the simple- and multiple-sale constant files.)

fun onInternalMessage(in: InMessage): void {}

// --- primitives (parameterized) ---
get fun gas(units: int): int { return gasFee(units); }
get fun fwd(bits: int, cells: int): int { return forwardFee(bits, cells); }
get fun storage_year(bits: int, cells: int): int { return storageFee(ONE_YEAR, bits, cells); }

// --- gas.tolk domain helpers ---
get fun nft_transfer_fee(): int { return nftTransferFee(); }
get fun domain_refill_fee(): int { return domainRefillFee(); }
get fun renew_domain_fee(): int { return renewDomainFee(); }

// --- fix_price_sales composites ---
get fun ton_simple_purchase(): int { return TONS_PURCHASE_PER_DOMAIN(); }

// --- simple sale ---
get fun ton_simple_purchase_fee(): int { return tonSimplePurchaseFee(); }
get fun auto_renew_lock_per_iter(): int { return autoRenewLockPerIter(ONE_YEAR - ONE_DAY); }

// --- auctions ---
get fun end_ton_auction(): int { return TONS_END_TON_AUCTION(); }
get fun end_jetton_auction(): int { return TONS_END_JETTON_AUCTION(); }

// --- offers ---
get fun ton_simple_offer_reserve(): int { return TONS_TON_SIMPLE_OFFER_RESERVE(); }
get fun jetton_simple_offer_reserve(): int { return TONS_JETTON_SIMPLE_OFFER_RESERVE(); }
get fun offer_execution_pad(): int { return offerExecutionPad(); }
get fun offer_change_price_gas(): int { return TONS_CHANGE_PRICE_GAS(); }
get fun offer_counterpropose_gas(): int { return TONS_COUNTERPROPOSE_GAS(); }

// --- domain swap ---
get fun add_domain(): int { return TONS_ADD_DOMAIN(); }
get fun add_payment(): int { return TONS_ADD_PAYMENT(); }
get fun swap_deploy(domainsTotal: int): int { return swapDeployValue(domainsTotal); }
get fun swap_storage_year(domainsTotal: int): int { return swapStorageReserve(ONE_YEAR, domainsTotal); }

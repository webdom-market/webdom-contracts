import "../imports/constants"
import "../imports/gas"

const EXC_NO_NEED_TO_PAY: int = 53;

const STATE_WAITING_FOR_LEFT: int = 0;
const STATE_WAITING_FOR_RIGHT: int = 1;

fun DOMAIN_SWAP_NOTIFICATION(): cell
    asm "B{b5ee9c7241010101002200004000000000446f6d61696e2073776170206f6e20776562646f6d2e6d61726b65748e908425} B>boc PUSHREF";  // Domain swap on webdom.market

fun CANCEL_NOTIFICATION_LEFT(): cell
    asm "B{b5ee9c7241010101002c00005400000000546865206f66666572207761732063616e63656c6c6564206279206974732063726561746f720430824d} B>boc PUSHREF";  // The offer was cancelled by its creator

fun CANCEL_NOTIFICATION_RIGHT(): cell
    asm "B{b5ee9c7241010101003700006a00000000546865206f66666572207761732063616e63656c6c656420627920746865207365636f6e64207061727469636970616e743c1123f2} B>boc PUSHREF";  // The offer was cancelled by the second participant

fun CANCEL_NOTIFICATION_EXPIRED(): cell
    asm "B{b5ee9c7201010101001700002a546865206f66666572206861732065787069726564} B>boc PUSHREF";  // The offer has expired


/* ---- Compute gas (gas units), measured in SwapGas.spec.ts, padded ~1.6-2.6x ---- */
// Activation handler: ~3,820 measured.
const GAS_SWAP_DEPLOY: int            = 8000;
// Per-domain receive handler; worst branch (fires completeLeftPart) ~10,900.
const GAS_SWAP_RECEIVE_DOMAIN: int    = 18000;
// Settlement-loop slope (completeDeal / returnDomains): ~3,460-3,490 gas/domain.
const GAS_SWAP_SETTLE_PER_DOMAIN: int = 8000;
// Same slope as settle; named separately to mirror GAS_AUCTION_CANCEL_PER_DOMAIN.
const GAS_SWAP_CANCEL_PER_DOMAIN: int = GAS_SWAP_SETTLE_PER_DOMAIN;
// op==0 payment top-up, heavier all-received branch: ~11,100 base.
const GAS_SWAP_PAYMENT: int           = 20000;


/* ---- Swap code+data size (cells/bits) for storage rent, measured in SwapGasSize.spec.ts ----
   Two sides, both dicts fully populated from deploy; padded over N = leftTotal + rightTotal. */
const SWAP_BASE_CELLS: int       = 75;
const SWAP_BASE_BITS: int        = 36000;
const SWAP_PER_DOMAIN_CELLS: int = 3;
const SWAP_PER_DOMAIN_BITS: int  = 300;

/// Swap's own storage rent for `seconds`, scaling with total domains (left + right).
@inline
fun swapStorageReserve(seconds: int, domainsTotal: int): coins {
    return storageFee(
        seconds,
        SWAP_BASE_BITS  + SWAP_PER_DOMAIN_BITS  * domainsTotal,
        SWAP_BASE_CELLS + SWAP_PER_DOMAIN_CELLS * domainsTotal
    );
}

/// Deploy seed: activation compute + a full year of the full-dict storage rent + min buffer.
/// The dict is fully populated at deploy, so its whole rent accrues from t=0; this is the ONLY funding
/// for it (per-domain buffers carry no storage term). Unused reserve is swept back at completion/cancel.
@inline
fun swapDeployValue(domainsTotal: int): coins {
    return gasFee(GAS_SWAP_DEPLOY) + swapStorageReserve(ONE_YEAR, domainsTotal) + TONS_MIN_RESERVE;
}

/// Value each incoming domain must attach beyond its side's payment; its gas buffer for the deal:
///   - domainRefillFee()  settlement transfer with storage refill (a domain may escrow up to ~1yr and
///     drain its reserve; bounce:false send, so a bare nftTransferFee() would strand it on the 402 check).
///   - gasFee(GAS_SWAP_RECEIVE_DOMAIN)    this message's receive-handler compute.
///   - gasFee(GAS_SWAP_SETTLE_PER_DOMAIN) this domain's share of the settlement loop.
/// No storage term: per-domain dict rent is funded once, at deploy (swapDeployValue).
@inline
fun TONS_ADD_DOMAIN(): coins {
    return domainRefillFee()
         + gasFee(GAS_SWAP_RECEIVE_DOMAIN)
         + gasFee(GAS_SWAP_SETTLE_PER_DOMAIN);
}

/// Fee subtracted from an op==0 payment top-up: handler compute + the two PAY_FEES_SEPARATELY forwards
/// completeLeftPart emits. No transfer/storage term (pre-funded elsewhere), so the >=paymentTotal check
/// stays satisfiable for an honest payer.
@inline
fun TONS_ADD_PAYMENT(): coins {
    return gasFee(GAS_SWAP_PAYMENT) + forwardFee(DOMAIN_MSG_BITS, DOMAIN_MSG_CELLS) * 2;
}

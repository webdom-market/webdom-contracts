import "../imports/constants";
import "../imports/gas";
import "../fix_price_sales/constants"

const OP_STOP_AUCTION = 0x793be3b5;

const EXC_BID_TOO_LOW = 61;
const EXC_AUCTION_NOT_ENDED = 63;

const TONS_MIN_BID_INCREMENT: coins     = ton("0.1");
// Per-domain cost of ENDING an auction: buyer notification tip + the lean domain transfer-out
// (transfer compute + 2 onward forwards) + the finalize handler's per-domain compute. Auctions PRE-FUND
// each domain's storage at deploy (domainRefillFee), so the transfer out only needs nftTransferFee — this
// is intentionally SEPARATE from the multiple-SALE TONS_PURCHASE_PER_DOMAIN() (which is domainRefillFee()-
// based because multiple sales do NOT pre-fund their domains). The simple auction subtracts this from the
// bid (userBid = value - TONS_END_TON_AUCTION() - ...), so inflating it would push valid bids into EXC_BID_TOO_LOW.
@inline fun TONS_END_TON_AUCTION(): coins    { return TONS_PURCHASE_NOTIFICATION + nftTransferFee() + gasFee(GAS_MULTIPLE_PURCHASE_PER_DOMAIN); }
@inline fun TONS_END_JETTON_AUCTION(): coins { return TONS_END_TON_AUCTION() + TONS_JETTON_TRANSFER * 2 + TONS_NOTIFY_MARKETPLACE; }
// Business notification tip sent to the (current) bidder on a successful bid. NOT a network-priced
// fee (like TONS_PURCHASE_NOTIFICATION / TONS_NOTIFY_MARKETPLACE) — kept hardcoded by design.
const TONS_NOTIFY_BIDDER: coins         = ton("0.005");

const BID_INCREMENT_DIVIDER = 1000;

/* ---- Auction contract storage reserves ----
   The reserve keeps the AUCTION contract itself funded for a year (the domains keep their own ~1-TON
   reserve separately), computed from the measured contract size (below) at the live storage price.
   MEASURED in tests/auctions/AuctionGasSize.spec.ts (code+data), padded to dominate BOTH the TON and jetton
   variants: simple ton 64c/38256b, jetton 67c/40256b -> 80c/44000b ; multiple base ~75c/47567b +
   ~2c/261b per domain -> 95c/50000b + 3c/320b per domain (dominant up to 50 domains). */
const AUCTION_SIMPLE_CELLS: int           = 80;
const AUCTION_SIMPLE_BITS: int            = 44000;
const MULTI_AUCTION_BASE_CELLS: int       = 95;
const MULTI_AUCTION_BASE_BITS: int        = 50000;
const MULTI_AUCTION_PER_DOMAIN_CELLS: int = 3;
const MULTI_AUCTION_PER_DOMAIN_BITS: int  = 320;

/// One year of a SIMPLE auction contract's own storage rent at the live price.
@inline fun simpleAuctionStorageReserve(): coins {
    return storageFee(ONE_YEAR, AUCTION_SIMPLE_BITS, AUCTION_SIMPLE_CELLS);
}
/// A MULTIPLE auction contract's own storage rent for `seconds`, scaling with the domains dict it holds.
@inline fun multiAuctionStorageReserve(seconds: int, domainsTotal: int): coins {
    return storageFee(
        seconds,
        MULTI_AUCTION_BASE_BITS  + MULTI_AUCTION_PER_DOMAIN_BITS  * domainsTotal,
        MULTI_AUCTION_BASE_CELLS + MULTI_AUCTION_PER_DOMAIN_CELLS * domainsTotal
    );
}

/* ---- Auction compute gas (MEASURED in tests/auctions/AuctionGas.spec.ts) ---- */
const GAS_AUCTION_DEPLOY: int              = 8000;  // simple-auction activation ~4,071 gas measured, ~2x margin
const GAS_AUCTION_FINALIZE_PER_DOMAIN: int = 6000;   // endAuctionSuccess loop ~3,239 gas/domain measured (fixed base ~7,531), ~1.85x slope
const GAS_AUCTION_CANCEL_PER_DOMAIN: int   = 6000;   // endAuctionFailed loop ~3,255 gas/domain measured (fixed base ~8,526), ~1.84x slope
const GAS_AUCTION_BID_PROCESSING: int      = 20000;  // jetton bid handler base: TON ~11,786 gas measured + jetton parse; mirrors GAS_JETTON_MULTIPLE_PURCHASE_BASE

fun AUCTION_CANCEL_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101001f00003a000000005468652061756374696f6e207761732063616e63656c6c6564240f5035} B>boc PUSHREF";  // Auction was cancelled

fun OUTBID_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101002900004e00000000596f75722062696420776173206f757462696420627920616e6f746865722075736572d1f10ef6} B>boc PUSHREF";  // Your bid was outbid by another user

fun MULTIPLE_AUCTION_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101003a000070000000005061796f757420666f72206d756c7469706c6520646f6d61696e732061756374696f6e206f6e20776562646f6d2e6d61726b65748a3cf855} B>boc PUSHREF";  // Payout for multiple domains auction on webdom.market
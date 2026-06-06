import "../imports/constants"
import "../imports/gas"

const EXC_INCORRECT_SELLER_ADDRESS: int = 55;
const EXC_INCORRECT_PRICE: int          = 56;
const EXC_NFT_ALREADY_SOLD: int         = 57;
const EXC_INCORRECT_EXOTIC_CELL: int    = 58;
const EXC_INCORRECT_PROOF: int          = 59;
const EXC_NFT_NOT_FOUND: int            = 60;

// --- Gas budgets = measured handler compute + ~1.5x margin (GasResearchOffers.spec.ts). All
// TON-denominated gas/storage/forward costs come from the live network price via imports/gas.
//
// Offer code+data size: one padded bound covers BOTH variants (rent is tiny). Measured:
// TON offer 72c/38,945b ; JETTON offer 74c/44,486b, padded for growth. At mainnet prices bits are
// free, so the bit pad only affects the (6x-pessimistic) sandbox.
const OFFER_STORAGE_CELLS: int = 80;
const OFFER_STORAGE_BITS: int  = 48000;
// Offer lives at most 30 days (validUntil <= now + 30d enforced at every mutation; accept only fires
// while validUntil > now). So 30d is the worst-case storage drain the execution pad must pre-fund.
// (Cancel-after-expiry NFT return is funded by the price+commission balance, not this pad.)
const OFFER_STORAGE_DURATION: int = ONE_DAY * 30;
// Measured handler compute (gas units), each ~1.5x for margin:
//   accept / execute ~11,300 -> 17,000 (high-stakes: moves buyer funds + NFT)
//   change-price (jetton worst ~14,640) -> 22,000
//   counter-propose ~11,500 -> 17,000 ; deploy / activation ~7,500 -> 12,000
const GAS_OFFER_ACCEPT: int        = 17000;
const GAS_OFFER_CHANGE_PRICE: int  = 22000;
const GAS_OFFER_COUNTERPROPOSE: int = 17000;
const GAS_OFFER_DEPLOY: int        = 12000;
const OFFER_MSG_BITS: int  = 1023;  // conservative single-cell message
const OFFER_MSG_CELLS: int = 1;

@inline fun offerStorageReserve(seconds: int): coins { return storageFee(seconds, OFFER_STORAGE_BITS, OFFER_STORAGE_CELLS); }

// Execution buffer so an accept (now or up to 30d out, after the idle reserve has drained) can pay:
// acceptOffer compute + forward fees of its three sends (commission + payout + NFT hop) + one storage
// window. The NFT transfer (nftTransferFee) and new-owner tip (TONS_PURCHASE_NOTIFICATION) are
// separate terms in the reserves below.
@inline fun offerExecutionPad(): coins {
    return offerStorageReserve(OFFER_STORAGE_DURATION)
         + gasFee(GAS_OFFER_ACCEPT)
         + forwardFee(OFFER_MSG_BITS, OFFER_MSG_CELLS) * 3;
}
@inline fun TONS_TON_SIMPLE_OFFER_RESERVE(): coins { return nftTransferFee() + TONS_PURCHASE_NOTIFICATION + offerExecutionPad(); }
// Jetton variant also pre-funds the two jetton sends (commission + payout) at the jetton-wallet floor
// (TONS_JETTON_TRANSFER — wallet-hardcoded, not a gas/storage cost) plus the commission-notification
// tip (TONS_NOTIFY_MARKETPLACE) — mirrors the jetton sale's per-domain purchase accounting.
@inline fun TONS_JETTON_SIMPLE_OFFER_RESERVE(): coins { return nftTransferFee() + TONS_PURCHASE_NOTIFICATION + 2 * TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE + offerExecutionPad(); }

const TONS_MIN_PRICE_CHANGE: coins = ton("0.1");      // business rule: minimum price bargaining step
const TONS_COUNTERPROPOSE_PRICE: coins = ton("0.05"); // marketplace business fee (revenue), not gas

// Gas a buyer's price-change message must carry beyond price/notification/fee: change-price compute +
// a couple of forward fees. Lowering it puts more of the buyer's coins into the offer price (it's
// subtracted from the incoming value in the TON change-price path).
@inline fun TONS_CHANGE_PRICE_GAS(): coins { return gasFee(GAS_OFFER_CHANGE_PRICE) + forwardFee(OFFER_MSG_BITS, OFFER_MSG_CELLS) * 2; }
// Gas a counter-propose message must leave beyond the marketplace fee: handler compute + forwards.
@inline fun TONS_COUNTERPROPOSE_GAS(): coins { return gasFee(GAS_OFFER_COUNTERPROPOSE) + forwardFee(OFFER_MSG_BITS, OFFER_MSG_CELLS) * 2; }

fun OFFER_ACCEPTED_NOTIFICATION(): cell 
    asm "B{b5ee9c72010101010014000024000000004f66666572206163636570746564} B>boc PUSHREF";
    
fun COUNTERPROPOSAL_REJECTED_NOTIFICATION(): cell 
    asm "B{b5ee9c7201010101002700004a00000000596f757220636f756e74657270726f706f73616c207761732072656a6563746564} B>boc PUSHREF";

fun NFT_SOLD_NOTIFICATION(): cell 
    asm "B{b5ee9c7201010101001f00003a000000004e465420736f6c64206f6e20776562646f6d2e6d61726b6574} B>boc PUSHREF";
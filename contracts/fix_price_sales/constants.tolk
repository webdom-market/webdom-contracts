import "../imports/constants";
import "../imports/gas";

// Per-domain purchase/finalize handler compute, MEASURED in tests/TriggerGas.spec.ts: the multiple
// sale's purchase loop is ~11,450 gas fixed + ~3,620 gas per domain. Charged per domain (×N), so the
// per-domain budget below + the nftTransferFee() margin amortize the fixed base. ~2.2x the slope.
const GAS_MULTIPLE_PURCHASE_PER_DOMAIN: int = 8000;

// Fixed (NON-per-domain) compute base of the JETTON multiple-purchase handler, MEASURED in
// tests/JettonPurchaseGas.spec.ts: ~11,380 gas on the normal path, ~13,705 gas on the heavier
// dedust/excess-return branch (loads the forward-payload ref, parses the real sender, builds a third
// jetton message). 20000 is ~1.5x that worst-case branch. The per-domain compute is covered
// separately by the per-domain budget TONS_TON_SIMPLE_PURCHASE()*N; this only funds the fixed base.
const GAS_JETTON_MULTIPLE_PURCHASE_BASE: int = 20000;

// Fixed (NON-per-domain) compute base of the TON multiple-purchase handler, MEASURED in
// tests/TriggerGas.spec.ts: ~11,510 gas fixed + ~3,620 gas per domain. The per-domain budget
// (gasFee(GAS_MULTIPLE_PURCHASE_PER_DOMAIN)*N) only covers the slope; this funds the fixed base so the
// purchase completes even at small N (N=1,2) where the base is not amortized. ~1.6x the measured base.
const GAS_TON_MULTIPLE_PURCHASE_BASE: int = 18000;

// One domain's purchase cost: the buyer notification tip (TONS_PURCHASE_NOTIFICATION) + the
// NFT-transfer fee (domain transfer compute + 2 onward forwards, computed) + the sale/auction
// handler's per-domain compute (gasFee of the 8000-gas GAS_MULTIPLE_PURCHASE_PER_DOMAIN budget).
@inline fun TONS_PURCHASE_PER_DOMAIN(): coins { return TONS_PURCHASE_NOTIFICATION + domainRefillFee() + gasFee(GAS_MULTIPLE_PURCHASE_PER_DOMAIN); }
// Fixed jetton overhead of a multiple purchase: the three jetton sends (excess-return + commission +
// seller payout) + the marketplace tip + the handler's computed fixed compute base (gasFee of the
// 20000-gas GAS_JETTON_MULTIPLE_PURCHASE_BASE).
@inline fun TONS_JETTON_MULTIPLE_PURCHASE(): coins { return TONS_JETTON_TRANSFER * 3 + TONS_NOTIFY_MARKETPLACE + gasFee(GAS_JETTON_MULTIPLE_PURCHASE_BASE); }
@inline fun TONS_MIN_RESERVE_FOR_AUTOCANCEL(): coins { return TONS_MIN_RESERVE * 2 + nftTransferFee(); }


fun SALE_CANCEL_NOTIFICATION(): cell 
    asm "B{b5ee9c724101010100140000240000000053616c652063616e63656c6c656436dffdf1} B>boc PUSHREF";  // Sale cancelled

fun EXPIRED_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101003f00007a000000004f6e65206f6620796f757220646f6d61696e732068617320657870697265642c2063616e63656c20746865206d756c7469706c652073616c6559a22a1c} B>boc PUSHREF";  // One of your domains has expired, cancel the multiple sale

fun MULTIPLE_SALE_NOTIFICATION(): cell 
    asm "B{b5ee9c7201010101003700006a000000005061796f757420666f72206d756c7469706c6520646f6d61696e732073616c65206f6e20776562646f6d2e6d61726b6574} B>boc PUSHREF";  // Payout for multiple domains sale on webdom.market 

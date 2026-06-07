import "../imports/constants";
import "../imports/gas";

// Per-domain purchase handler compute (TriggerGas.spec.ts): ~11,745 fixed + ~3,618/domain.
// Charged per domain (×N); this budget + nftTransferFee() margin amortize the base. ~2.2x the slope.
const GAS_MULTIPLE_PURCHASE_PER_DOMAIN: int = 8000;

// Fixed compute base of the JETTON multiple-purchase handler (JettonPurchaseGas.spec.ts): ~11,620 normal,
// ~13,945 on the dedust/excess-return branch (third jetton message). 20000 is ~1.43x worst case.
// Per-domain compute is funded separately; this only covers the fixed base.
const GAS_JETTON_MULTIPLE_PURCHASE_BASE: int = 20000;

// Fixed compute base of the TON multiple-purchase handler (TriggerGas.spec.ts): ~11,745 fixed + ~3,618/domain.
// Per-domain budget covers the slope; this funds the base so small N (1,2) stays funded. ~1.53x measured.
const GAS_TON_MULTIPLE_PURCHASE_BASE: int = 18000;

// One domain's purchase cost: buyer notification tip + domain refill (transfer + 2 forwards + one year
// storage — multiple sales don't pre-fund domains) + the handler's per-domain compute.
@inline fun TONS_PURCHASE_PER_DOMAIN(): coins { return TONS_PURCHASE_NOTIFICATION + domainRefillFee() + gasFee(GAS_MULTIPLE_PURCHASE_PER_DOMAIN); }
// Fixed jetton overhead of a multiple purchase: 3 jetton sends (excess-return + commission + seller
// payout) + marketplace tip + the handler's fixed compute base.
@inline fun TONS_JETTON_MULTIPLE_PURCHASE(): coins { return TONS_JETTON_TRANSFER * 3 + TONS_NOTIFY_MARKETPLACE + gasFee(GAS_JETTON_MULTIPLE_PURCHASE_BASE); }


fun SALE_CANCEL_NOTIFICATION(): cell 
    asm "B{b5ee9c724101010100140000240000000053616c652063616e63656c6c656436dffdf1} B>boc PUSHREF";  // Sale cancelled

fun EXPIRED_NOTIFICATION(): cell 
    asm "B{b5ee9c7241010101003f00007a000000004f6e65206f6620796f757220646f6d61696e732068617320657870697265642c2063616e63656c20746865206d756c7469706c652073616c6559a22a1c} B>boc PUSHREF";  // One of your domains has expired, cancel the multiple sale

fun MULTIPLE_SALE_NOTIFICATION(): cell 
    asm "B{b5ee9c7201010101003700006a000000005061796f757420666f72206d756c7469706c6520646f6d61696e732073616c65206f6e20776562646f6d2e6d61726b6574} B>boc PUSHREF";  // Payout for multiple domains sale on webdom.market 

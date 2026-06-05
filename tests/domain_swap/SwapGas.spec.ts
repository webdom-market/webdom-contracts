import { Blockchain, SandboxContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DomainSwap, DomainSwapConfig } from '../../wrappers/DomainSwap';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { MIN_PRICE_START_TIME } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Mirrors GAS_SWAP_* in contracts/domain_swap/constants.tolk — the budgets these tests must dominate.
const GAS_SWAP_DEPLOY = 10000;
const GAS_SWAP_RECEIVE_DOMAIN = 18000;
const GAS_SWAP_SETTLE_PER_DOMAIN = 8000;
const GAS_SWAP_CANCEL_PER_DOMAIN = 8000;
const GAS_SWAP_PAYMENT = 20000;

// compute gas of the LAST tx whose inbound message hits the swap (the handler we triggered)
function swapGas(res: any, swap: Address): { gas: number; exit: number } {
    const hits = (res.transactions as any[]).filter(t => t.inMessage?.info?.dest?.toString?.() === swap.toString());
    const t = hits[hits.length - 1];
    return { gas: Number((t?.description)?.computePhase?.gasUsed ?? 0), exit: (t?.description)?.computePhase?.exitCode };
}

let swapCode: Cell, dnsCode: Cell, domainCode: Cell;
const ADD = () => DomainSwap.ADD_DOMAIN_TONS;

// Build an ACTIVE swap (deployed) holding L left + R right domains, with the given payment totals.
async function buildActive(L: number, R: number, tag: string, leftPay: bigint, rightPay: bigint) {
    const bc = await Blockchain.create();
    bc.now = MIN_PRICE_START_TIME;
    const admin = await bc.treasury('admin'); const left = await bc.treasury('left'); const right = await bc.treasury('right');
    const dns = bc.openContract(DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
    await dns.sendDeploy(admin.getSender(), toNano('0.05'));
    const leftDomains: SandboxContract<Domain>[] = [], rightDomains: SandboxContract<Domain>[] = [];
    const ld = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
    const rd = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
    for (let i = 0; i < L + R; i++) {
        const r = await dns.sendStartAuction(admin.getSender(), `g${tag}x${i}99.ton`);
        const addr = r.transactions[2].inMessage!.info.dest! as Address;
        const d = bc.openContract(Domain.createFromAddress(addr)); bc.now += 3601;
        if (i < L) { await d.sendTransfer(admin.getSender(), left.address, admin.address); leftDomains.push(d); ld.set(addr, false); }
        else { await d.sendTransfer(admin.getSender(), right.address, admin.address); rightDomains.push(d); rd.set(addr, false); }
    }
    const cfg: DomainSwapConfig = {
        leftParticipantAddress: left.address, leftDomainsTotal: L, leftDomainsReceived: 0, leftDomainsDict: ld, leftPaymentTotal: leftPay, leftPaymentReceived: 0n,
        rightParticipantAddress: right.address, rightDomainsTotal: R, rightDomainsReceived: 0, rightDomainsDict: rd, rightPaymentTotal: rightPay, rightPaymentReceived: 0n,
        state: DomainSwap.STATE_CANCELLED, createdAt: bc.now!, validUntil: bc.now! + 60 * 120, lastActionTime: 0, commission: toNano('0.1'), needsAlert: false, cancelledByLeft: false,
    };
    const swap = bc.openContract(DomainSwap.createFromConfig(cfg, swapCode));
    const dep = await swap.sendDeploy(admin.getSender(), toNano('3'));
    const activation = swapGas(dep, swap.address).gas;
    return { bc, swap, left, right, leftDomains, rightDomains, activation };
}

function fit(pts: Array<{ n: number; gas: number }>) {
    const N = pts.length, sx = pts.reduce((a, p) => a + p.n, 0), sy = pts.reduce((a, p) => a + p.gas, 0);
    const sxx = pts.reduce((a, p) => a + p.n * p.n, 0), sxy = pts.reduce((a, p) => a + p.n * p.gas, 0);
    const slope = (N * sxy - sx * sy) / (N * sxx - sx * sx);
    return { base: (sy - slope * sx) / N, slope };
}

describe('SwapGas — DomainSwap handler compute vs GAS_SWAP_* budgets', () => {
    beforeAll(async () => { swapCode = await compile('DomainSwap'); dnsCode = await compile('DnsCollection'); domainCode = await compile('Domain'); });

    it('activation, receive, completeDeal/returnDomains slope, op==0 payment', async () => {
        const counts: [number, number][] = [[1, 1], [2, 2], [4, 4], [8, 8]];
        let activation = 0, plainRecv = 0, leftPartRecv = 0;
        const dealPts: { n: number; gas: number }[] = [];
        const retPts: { n: number; gas: number }[] = [];
        const payPts: { n: number; gas: number }[] = [];

        for (const [L, R] of counts) {
            // (A) completeDeal via domains: leftPay=0 (left auto-completes), rightPay=0 (last right completes deal)
            const A = await buildActive(L, R, `d${L}`, 0n, 0n);
            activation = Math.max(activation, A.activation);
            for (let i = 0; i < L; i++) {
                A.bc.now! += 5;
                const r = await A.leftDomains[i].sendTransfer(A.left.getSender(), A.swap.address, null, null, ADD());
                const g = swapGas(r, A.swap.address).gas;
                if (L > 1 && i === 0) plainRecv = Math.max(plainRecv, g);     // non-completing receive
                if (i === L - 1) leftPartRecv = Math.max(leftPartRecv, g);    // receive that fires completeLeftPart
            }
            let deal = 0;
            for (let i = 0; i < R; i++) {
                A.bc.now! += 5;
                const r = await A.rightDomains[i].sendTransfer(A.right.getSender(), A.swap.address, null, null, ADD());
                if (i === R - 1) deal = swapGas(r, A.swap.address).gas;       // receive that fires completeDeal
            }
            dealPts.push({ n: L + R, gas: deal });

            // (B) returnDomains via external expiry: rightPay huge so it never completes; deliver all, then expire
            const B = await buildActive(L, R, `r${L}`, 0n, toNano('1000'));
            for (let i = 0; i < L; i++) { B.bc.now! += 5; await B.leftDomains[i].sendTransfer(B.left.getSender(), B.swap.address, null, null, ADD()); }
            for (let i = 0; i < R; i++) { B.bc.now! += 5; await B.rightDomains[i].sendTransfer(B.right.getSender(), B.swap.address, null, null, ADD()); }
            const cfgB = await B.swap.getStorageData();
            B.bc.now = cfgB.validUntil + 1;
            const rext = await B.swap.sendExternalCancel();
            retPts.push({ n: L + R, gas: swapGas(rext, B.swap.address).gas });

            // (C) op==0 payment that completes the deal: rightPay small, deliver all right domains (no completion),
            //     then top up to complete -> completeDeal runs inside the op==0 handler.
            const C = await buildActive(L, R, `p${L}`, 0n, toNano('1'));
            for (let i = 0; i < L; i++) { C.bc.now! += 5; await C.leftDomains[i].sendTransfer(C.left.getSender(), C.swap.address, null, null, ADD()); }
            for (let i = 0; i < R; i++) { C.bc.now! += 5; await C.rightDomains[i].sendTransfer(C.right.getSender(), C.swap.address, null, null, ADD()); }
            const rpay = await C.swap.sendAddPayment(C.right.getSender(), toNano('1'));
            payPts.push({ n: L + R, gas: swapGas(rpay, C.swap.address).gas });
        }

        const fd = fit(dealPts), fr = fit(retPts), fp = fit(payPts);
        log(`\n>>> DomainSwap compute (classic prices):`);
        log(`>>>   activation              = ${activation}  (budget GAS_SWAP_DEPLOY=${GAS_SWAP_DEPLOY})`);
        log(`>>>   plain receive           = ${plainRecv}`);
        log(`>>>   completeLeftPart receive= ${leftPartRecv}  (budget GAS_SWAP_RECEIVE_DOMAIN=${GAS_SWAP_RECEIVE_DOMAIN})`);
        log(`>>>   completeDeal fit        = ${fd.base.toFixed(0)} + ${fd.slope.toFixed(0)}/domain  (slope budget GAS_SWAP_SETTLE_PER_DOMAIN=${GAS_SWAP_SETTLE_PER_DOMAIN})`);
        log(`>>>   returnDomains fit (ext) = ${fr.base.toFixed(0)} + ${fr.slope.toFixed(0)}/domain  (slope budget GAS_SWAP_CANCEL_PER_DOMAIN=${GAS_SWAP_CANCEL_PER_DOMAIN})`);
        log(`>>>   op==0 completeDeal fit  = ${fp.base.toFixed(0)} + ${fp.slope.toFixed(0)}/domain  (base budget GAS_SWAP_PAYMENT=${GAS_SWAP_PAYMENT})`);

        // --- Drift guards: each budget must dominate the measured worst case ---
        expect(activation).toBeGreaterThan(0);
        expect(activation).toBeLessThanOrEqual(GAS_SWAP_DEPLOY);
        // the per-domain receive buffer must cover the heaviest single receive (incl. completeLeftPart branch)
        expect(Math.max(plainRecv, leftPartRecv)).toBeLessThanOrEqual(GAS_SWAP_RECEIVE_DOMAIN);
        // per-domain settlement/cancel slope budgets must dominate the measured slopes
        expect(fd.slope).toBeLessThanOrEqual(GAS_SWAP_SETTLE_PER_DOMAIN);
        expect(fr.slope).toBeLessThanOrEqual(GAS_SWAP_CANCEL_PER_DOMAIN);
        // the op==0 handler total must be covered by GAS_SWAP_PAYMENT (base) + per-domain settle buffers (slope),
        // at every measured point (the receive that triggers completeDeal in path A is covered the same way by
        // GAS_SWAP_RECEIVE_DOMAIN + the per-domain buffers).
        for (const p of payPts) expect(GAS_SWAP_PAYMENT + GAS_SWAP_SETTLE_PER_DOMAIN * p.n).toBeGreaterThanOrEqual(p.gas);
        for (const p of dealPts) expect(GAS_SWAP_RECEIVE_DOMAIN + GAS_SWAP_SETTLE_PER_DOMAIN * p.n).toBeGreaterThanOrEqual(p.gas);
    }, 180000);
});

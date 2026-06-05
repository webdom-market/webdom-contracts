import { Blockchain } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { TonMultipleSale, TonMultipleSaleConfig } from '../../wrappers/TonMultipleSale';
import { MIN_PRICE_START_TIME, ONE_DAY } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure the multiple sale's per-domain COMPUTE on its two domain-looping handlers — the external
// auto-renew trigger and the buyer purchase — vs domain count, to size GAS_AUTORENEW_TX_PER_DOMAIN
// and GAS_MULTIPLE_PURCHASE_PER_DOMAIN from the real per-domain marginal (not magic TON values).
describe('TriggerGas', () => {
    let dnsCode: Cell, domainCode: Cell, saleCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('TonMultipleSale');
    });

    // Build an ACTIVE multiple sale holding n domains (optionally with k auto-renew iterations).
    async function buildActiveSale(n: number, tag: string, autoRenewIters: number) {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const buyer = await bc.treasury('buyer');
        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));

        const domains: any[] = [];
        const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        for (let i = 0; i < n; i++) {
            const r = await dns.sendStartAuction(admin.getSender(), `trig${tag}x${i}99.ton`);
            const addr = r.transactions[2].inMessage!.info.dest! as Address;
            const d = bc.openContract(Domain.createFromAddress(addr));
            bc.now += 3601;
            await d.sendTransfer(admin.getSender(), seller.address, seller.address);
            domains.push(d);
            dict.set(addr, 0);
        }
        const cfg: TonMultipleSaleConfig = {
            sellerAddress: seller.address, domainsDict: dict, domainsTotal: n, domainsReceived: 0,
            price: toNano('2'), state: TonMultipleSale.STATE_UNINIT, commission: toNano('0.2'),
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 3,
            buyerAddress: null, tonsToReserve: n, autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(TonMultipleSale.createFromConfig(cfg, saleCode));
        await sale.sendDeploy(admin.getSender(), toNano('0.04'));
        for (const d of domains) {
            await d.sendTransfer(seller.getSender(), sale.address, null, null, toNano('0.1'));
        }
        if (autoRenewIters > 0) {
            await sale.sendSetAutoRenewParams(seller.getSender(), n, ONE_DAY, autoRenewIters);
        }
        return { bc, sale, buyer };
    }

    // gasUsed of the (single) tx whose inbound message hits the sale and matches `pick`.
    function saleTxGas(res: any, saleAddr: Address, pick: (t: any) => boolean): bigint {
        const txs = res.transactions as any[];
        for (const t of txs) {
            if (t.inMessage?.info?.dest?.toString?.() === saleAddr.toString() && pick(t)) {
                return (t.description as any)?.computePhase?.gasUsed ?? 0n;
            }
        }
        return 0n;
    }

    async function triggerGasFor(n: number, tag: string): Promise<bigint> {
        const { bc, sale } = await buildActiveSale(n, tag, 2);
        bc.now! += ONE_DAY;
        const res = await sale.sendExternalTriggerAutoRenew();
        return saleTxGas(res, sale.address, t => t.inMessage?.info?.type === 'external-in');
    }

    async function purchaseGasFor(n: number, tag: string): Promise<bigint> {
        const { sale, buyer } = await buildActiveSale(n, tag, 0);
        const res = await sale.sendPurchase(buyer.getSender(), toNano('2'), n);
        return saleTxGas(res, sale.address, t => t.inMessage?.info?.type === 'internal');
    }

    function fit(pts: Array<{ n: number; gas: number }>) {
        const N = pts.length;
        const sx = pts.reduce((a, p) => a + p.n, 0);
        const sy = pts.reduce((a, p) => a + p.gas, 0);
        const sxx = pts.reduce((a, p) => a + p.n * p.n, 0);
        const sxy = pts.reduce((a, p) => a + p.n * p.gas, 0);
        const slope = (N * sxy - sx * sy) / (N * sxx - sx * sx);
        const base = (sy - slope * sx) / N;
        return { base, slope };
    }

    const counts = [1, 4, 8, 16, 32, 64];

    it('auto-renew trigger compute vs domain count', async () => {
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> external auto-renew trigger compute:`);
        for (let i = 0; i < counts.length; i++) {
            const n = counts[i];
            const gas = Number(await triggerGasFor(n, 't' + i));
            pts.push({ n, gas });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(gas).padStart(6)} gas | ${(gas / n).toFixed(0)}/domain`);
        }
        const f = fit(pts);
        log(`>>>   fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain ; constants BASE=12000 PER_DOMAIN=5000`);
        for (const p of pts) expect(12000 + 5000 * p.n).toBeGreaterThanOrEqual(p.gas);
    });

    it('buyer purchase compute vs domain count', async () => {
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> multiple-sale purchase compute:`);
        for (let i = 0; i < counts.length; i++) {
            const n = counts[i];
            const gas = Number(await purchaseGasFor(n, 'p' + i));
            pts.push({ n, gas });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(gas).padStart(6)} gas | ${(gas / n).toFixed(0)}/domain`);
        }
        const f = fit(pts);
        log(`>>>   fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain`);
        log(`>>>   GAS_MULTIPLE_PURCHASE_PER_DOMAIN must cover slope + base/N amortization (nftTransferFee margin helps)`);
        // the TONS_TON_SIMPLE_PURCHASE per-domain compute budget must dominate the real per-domain cost
        const worstPerDomain = Math.max(...pts.map(p => p.gas / p.n));
        log(`>>>   worst gas/domain across points = ${worstPerDomain.toFixed(0)} (drives GAS_MULTIPLE_PURCHASE_PER_DOMAIN)`);
        // TONS_TON_SIMPLE_PURCHASE reserves per domain: gasFee(GAS_MULTIPLE_PURCHASE_PER_DOMAIN=8000)
        // + nftTransferFee()'s DOMAIN_TRANSFER_GAS=16000 (available as margin since the transfer itself
        // is funded from the seller's domainRefillFee reserve). That budget must dominate the measured
        // purchase compute (base + slope*N) at every point.
        for (const p of pts) expect((8000 + 16000) * p.n).toBeGreaterThanOrEqual(p.gas);

    });
});

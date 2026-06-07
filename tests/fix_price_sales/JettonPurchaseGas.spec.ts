import { Blockchain } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { JettonMultipleSale, JettonMultipleSaleConfig } from '../../wrappers/JettonMultipleSale';
import { JettonMinter } from '../../wrappers/JettonMinter';
import { JettonWallet } from '../../wrappers/JettonWallet';
import { MIN_PRICE_START_TIME, ONE_DAY } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure the JETTON multiple sale's purchase handler COMPUTE (the JettonsTransferNotification path)
// vs domain count, to size the fixed-base part of TONS_JETTON_MULTIPLE_PURCHASE (currently a magic
// ton("0.005")) from the real fixed compute, and confirm the per-domain slope is covered by the
// per-domain budget already attached as TONS_TON_SIMPLE_PURCHASE()*N.
describe('JettonPurchaseGas', () => {
    let dnsCode: Cell, domainCode: Cell, saleCode: Cell, minterCode: Cell, walletCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('JettonMultipleSale');
        minterCode = await compile('JettonMinter');
        walletCode = await compile('JettonWallet');
    });

    // Build an ACTIVE jetton multiple sale holding n domains, return the buyer's jetton wallet + sale.
    async function buildActiveSale(n: number, tag: string) {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const buyer = await bc.treasury('buyer');

        const minter = bc.openContract(JettonMinter.createFromConfig(
            { admin: admin.address, content: beginCell().storeStringTail('usdt').endCell(), wallet_code: walletCode },
            minterCode));
        await minter.sendDeploy(admin.getSender(), toNano('0.05'));
        await minter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano('0.2'), toNano('0.5'));
        const buyerWallet = bc.openContract(JettonWallet.createFromAddress(await minter.getWalletAddress(buyer.address)));

        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));

        const domains: any[] = [];
        const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        for (let i = 0; i < n; i++) {
            const r = await dns.sendStartAuction(admin.getSender(), `jp${tag}x${i}99.ton`);
            const addr = r.transactions[2].inMessage!.info.dest! as Address;
            const d = bc.openContract(Domain.createFromAddress(addr));
            bc.now += 3601;
            await d.sendTransfer(admin.getSender(), seller.address, seller.address);
            domains.push(d);
            dict.set(addr, 0);
        }

        const cfg: JettonMultipleSaleConfig = {
            jettonMinterAddress: minter.address,
            jettonWalletAddress: undefined,
            sellerAddress: seller.address, domainsDict: dict, domainsTotal: n, domainsReceived: 0,
            price: toNano('2'), state: JettonMultipleSale.STATE_UNINIT, commission: toNano('0.2'),
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 3,
            buyerAddress: null, tonsToReserve: 15000000, autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(JettonMultipleSale.createFromConfig(cfg, saleCode));
        const saleWallet = bc.openContract(JettonWallet.createFromAddress(await minter.getWalletAddress(sale.address)));
        await sale.sendDeploy(admin.getSender(), toNano('0.05'), beginCell().storeAddress(saleWallet.address).endCell());
        for (const d of domains) {
            await d.sendTransfer(seller.getSender(), sale.address, null, null, toNano('0.1'));
        }
        return { bc, sale, buyer, buyerWallet };
    }

    // gasUsed of the single internal tx whose inbound message hits the sale (the transfer notification).
    function saleTxGas(res: any, saleAddr: Address): bigint {
        for (const t of res.transactions as any[]) {
            if (t.inMessage?.info?.dest?.toString?.() === saleAddr.toString()
                && t.inMessage?.info?.type === 'internal') {
                return (t.description as any)?.computePhase?.gasUsed ?? 0n;
            }
        }
        return 0n;
    }

    // excess>0 exercises the heavier branch: the dedust forward-payload handling + the THIRD jetton
    // message (return-excess-to-buyer) that a normal purchase skips. This is the worst-case fixed base.
    async function purchaseGasFor(n: number, tag: string, excess: boolean): Promise<{ gas: bigint; ok: boolean }> {
        const { sale, buyer, buyerWallet } = await buildActiveSale(n, tag);
        // Generously over-fund the forward TON so the purchase SUCCEEDS (we measure the success path).
        // F1: TONS_PURCHASE_PER_DOMAIN is now domainRefillFee-based (~0.106/domain), so fund above it.
        const forwardTon = toNano((0.13 * n + 0.6).toFixed(3));
        const jettons = excess ? toNano('2.5') : toNano('2'); // price is toNano('2')
        const res = await buyerWallet.sendTransfer(buyer.getSender(), jettons, sale.address, buyer.address, forwardTon);
        const ok = (res.transactions as any[]).some(t =>
            t.inMessage?.info?.dest?.toString?.() === sale.address.toString()
            && t.inMessage?.info?.type === 'internal'
            && (t.description as any)?.computePhase?.success === true
            && (t.description as any)?.computePhase?.exitCode === 0);
        return { gas: saleTxGas(res, sale.address), ok };
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

    async function measure(excess: boolean, label: string) {
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> jetton multiple-sale purchase compute (${label}):`);
        for (let i = 0; i < counts.length; i++) {
            const n = counts[i];
            const { gas, ok } = await purchaseGasFor(n, (excess ? 'e' : 'j') + i, excess);
            expect(ok).toBe(true); // must be the SUCCESS path or the measurement is meaningless
            pts.push({ n, gas: Number(gas) });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(Number(gas)).padStart(6)} gas | ${(Number(gas) / n).toFixed(0)}/domain`);
        }
        const f = fit(pts);
        log(`>>>   fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain`);
        return { pts, f };
    }

    it('jetton purchase compute vs domain count (normal + dedust/excess)', async () => {
        const normal = await measure(false, 'normal path');
        const dedust = await measure(true, 'dedust/excess-return path — worst case');
        log(`\n>>> ton("0.005") classic = 12500 gas; per-domain budget margin = (8000+16000)=24000 gas/domain`);
        log(`>>>   worst-case fixed base = ${Math.max(normal.f.base, dedust.f.base).toFixed(0)} gas -> drives GAS_JETTON_MULTIPLE_PURCHASE_BASE`);
        // The fixed base is covered by gasFee(GAS_JETTON_MULTIPLE_PURCHASE_BASE=20000); the slope is
        // covered by the per-domain budget attached as TONS_TON_SIMPLE_PURCHASE()*N (gasFee(24000)/dom).
        expect(20000).toBeGreaterThanOrEqual(Math.max(normal.f.base, dedust.f.base));
        expect(normal.f.slope).toBeLessThan(24000);
        expect(dedust.f.slope).toBeLessThan(24000);
        // end-to-end: the WHOLE handler compute must fit the gas the buyer's budget frees up:
        //   fixed gasFee(GAS_JETTON_MULTIPLE_PURCHASE_BASE) + per-domain gasFee(8000+16000)*N.
        for (const p of dedust.pts) expect(20000 + (8000 + 16000) * p.n).toBeGreaterThanOrEqual(p.gas);
    }, 120000);
});

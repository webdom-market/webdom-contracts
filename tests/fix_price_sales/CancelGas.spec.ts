import { Blockchain, SandboxContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { TonMultipleSale, TonMultipleSaleConfig } from '../../wrappers/TonMultipleSale';
import { MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure the external-cancel COMPUTE gas of the multiple sale vs domain count, to size a cancel
// gas buffer that getTonsToReserve must hold so the cancel can always afford to return every domain.
describe('CancelGas — multiple-sale cancel compute gas', () => {
    let dnsCode: Cell, domainCode: Cell, saleCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('TonMultipleSale');
    });

    async function buildActive(n: number, tag: string) {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        const domains: SandboxContract<Domain>[] = [];
        for (let i = 0; i < n; i++) {
            const r = await dns.sendStartAuction(admin.getSender(), `cg${tag}x${i}9.ton`);
            const addr = r.transactions[2].inMessage!.info.dest! as Address;
            const d = bc.openContract(Domain.createFromAddress(addr));
            bc.now! += 3601;
            await d.sendTransfer(admin.getSender(), seller.address, seller.address);
            domains.push(d); dict.set(addr, 0);
        }
        const cfg: TonMultipleSaleConfig = {
            sellerAddress: seller.address, domainsDict: dict, domainsTotal: n, domainsReceived: 0,
            price: toNano('2'), state: TonMultipleSale.STATE_UNINIT, commission: toNano('0.2'),
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 2,
            buyerAddress: null, tonsToReserve: n, autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(TonMultipleSale.createFromConfig(cfg, saleCode));
        await sale.sendDeploy(admin.getSender(), toNano('0.04'));
        for (const d of domains) await d.sendTransfer(seller.getSender(), sale.address, null, null, toNano('0.1'));
        return { bc, sale };
    }

    it('external-cancel compute vs N', async () => {
        const pts: { n: number; gas: number }[] = [];
        for (const n of [1, 2, 4, 8, 16, 32]) {
            const { bc, sale } = await buildActive(n, 'c' + n);
            bc.now = (await sale.getStorageData()).validUntil + 5;
            const res = await sale.sendExternalCancel();
            const tx = res.transactions.find(t => t.inMessage?.info?.type === 'external-in');
            const gas = Number((tx?.description as any)?.computePhase?.gasUsed ?? 0n);
            pts.push({ n, gas });
            log(`>>> cancel N=${n}: compute=${gas} gas (${(gas / n).toFixed(0)}/domain)`);
        }
        // linear fit
        const N = pts.length, sx = pts.reduce((a, p) => a + p.n, 0), sy = pts.reduce((a, p) => a + p.gas, 0);
        const sxx = pts.reduce((a, p) => a + p.n * p.n, 0), sxy = pts.reduce((a, p) => a + p.n * p.gas, 0);
        const slope = (N * sxy - sx * sy) / (N * sxx - sx * sx);
        const base = (sy - slope * sx) / N;
        log(`>>> cancel compute fit: base ${base.toFixed(0)} + ${slope.toFixed(0)}/domain`);
    });
});

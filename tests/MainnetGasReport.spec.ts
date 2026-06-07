import { Blockchain, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, fromNano, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { GasProbe } from '../wrappers/GasProbe';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain } from '../wrappers/Domain';
import { TonSimpleSale, TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import { MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR } from '../wrappers/helpers/constants';
import { collectGas, log, TxGas } from './helpers/gas';

// ---------------------------------------------------------------------------
// Live TON mainnet config params decoded from chain (June 2026 — the ~6x basechain fee cut).
// Same blobs used by tests/fix_price_sales/GasResearch4.spec.ts.
//   18 = storage prices, 20 = masterchain gas, 21 = basechain gas, 25 = forward (msg) prices.
// ---------------------------------------------------------------------------
const LIVE = {
    18: 'te6cckEBAwEAWQACAUgBAgBM3swAAAAAAAAAAAAAAAEAAAAAAAAB9AAAAAAAAAPoAAAAAAAHoSAAU71Pk/sGY0+T+wAAAAAAAAAAAAAAAAAAAAQ4AAAAAAAAH0AAAAAAAD0JBPXsekg=',
    20: 'te6cckEBAQEATAAAlNEAAAAAAAAAZAAAAAAAD0JA3gAAAAAnEAAAAAAAAAAPQkAAAAAABCwdgAAAAAAAACcQAAAAAAAmJaAAAAAABfXhAAAAAAA7msoAKm2gQw==',
    21: 'te6cckEBAQEATAAAlNEAAAAAAAAAZAAAAAAAABoL3gAAAAAAQqqrAAAAAAAPQkAAAAAAAA9CQAAAAAAAACcQAAAAAACYloAAAAAABfXhAAAAAAA7msoAgyFv5Q==',
    25: 'te6cckEBAQEAIwAAQuoAAAAAAAEEawAAAAAAQqqrAAAAABoKqqsAAYAAVVVVVXUQ/H0=',
} as const;

function patchConfigToMainnet(blockchain: Blockchain) {
    const dict = Dictionary.loadDirect(Dictionary.Keys.Int(32), Dictionary.Values.Cell(), blockchain.config);
    for (const [k, b64] of Object.entries(LIVE)) {
        dict.set(Number(k), Cell.fromBase64(b64));
    }
    blockchain.setConfig(beginCell().storeDictDirect(dict).endCell());
}

const ton = (v: bigint) => fromNano(v).padStart(12);

function txTo(res: SendMessageResult, to: Address): TxGas | undefined {
    const i = res.transactions.findIndex((t) => t.inMessage?.info?.dest?.toString() === to.toString());
    return i >= 0 ? collectGas(res)[i] : undefined;
}

describe('MainnetGasReport — gas + required TON for domain & sale actions at mainnet prices', () => {
    let probeCode: Cell, dnsCode: Cell, domainCode: Cell, saleCode: Cell;

    beforeAll(async () => {
        probeCode = await compile('GasProbe');
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('TonSimpleSale');
    });

    // -----------------------------------------------------------------------
    // PART 1 — exact "required TON" the contracts compute, classic vs mainnet
    // -----------------------------------------------------------------------
    it('REQUIRED-TON table: contract-computed fee budgets (classic sandbox vs live mainnet)', async () => {
        async function readProbe(mainnet: boolean) {
            const bc = await Blockchain.create();
            if (mainnet) patchConfigToMainnet(bc);
            const deployer = await bc.treasury('deployer');
            const probe = bc.openContract(GasProbe.createFromConfig({}, probeCode));
            await probe.sendDeploy(deployer.getSender(), toNano('5'));

            return {
                gasPrice: await probe.getGas(1_000_000n), // nanoTON per 1e6 gas
                'NFT/domain transfer': await probe.getNftTransferFee(),
                'domain renew (1yr)': await probe.getRenewDomainFee(),
                'domain refill (xfer+1yr)': await probe.getDomainRefillFee(),
                'TON simple purchase': await probe.getTonSimplePurchaseFee(),
                'auto-renew lock / iter': await probe.getAutoRenewLockPerIter(),
                'end TON auction': await probe.getEndTonAuction(),
                'end jetton auction': await probe.getEndJettonAuction(),
                'TON offer reserve': await probe.getTonSimpleOfferReserve(),
                'jetton offer reserve': await probe.getJettonSimpleOfferReserve(),
                'offer execution pad': await probe.getOfferExecutionPad(),
                'offer change price gas': await probe.getOfferChangePriceGas(),
                'offer counterpropose gas': await probe.getOfferCounterproposeGas(),
                'swap add domain': await probe.getAddDomain(),
                'swap add payment': await probe.getAddPayment(),
                'swap deploy (2 dom)': await probe.getSwapDeploy(2n),
            };
        }

        const classic = await readProbe(false);
        const mainnet = await readProbe(true);

        const cGasPrice = Number(classic.gasPrice) / 1_000_000;
        const mGasPrice = Number(mainnet.gasPrice) / 1_000_000;

        log('\n================ REQUIRED TON PER ACTION (contract-computed budgets) ================');
        log(`gas price: classic ${cGasPrice.toFixed(2)} nT/gas   |   mainnet ${mGasPrice.toFixed(3)} nT/gas   (≈ ${(cGasPrice / mGasPrice).toFixed(1)}x cheaper live)`);
        log('');
        log('action'.padEnd(28) + 'classic (TON)'.padStart(16) + 'mainnet (TON)'.padStart(16));
        log('-'.repeat(60));
        for (const k of Object.keys(classic)) {
            if (k === 'gasPrice') continue;
            log(k.padEnd(28) + ton((classic as any)[k]) + '    ' + ton((mainnet as any)[k]));
        }
        log('-'.repeat(60));
        log('Note: jetton transfers add a fixed 0.05 TON wallet floor per leg (not a gas/price-scaled cost).');

        expect(mGasPrice).toBeGreaterThan(0);
        expect(mGasPrice).toBeLessThan(cGasPrice);
    });

    // -----------------------------------------------------------------------
    // PART 1b — deploy cost of a TON simple sale (the value the deployer must attach)
    // -----------------------------------------------------------------------
    it('DEPLOY COST: TON simple sale (classic vs mainnet)', async () => {
        // Mirrors contracts/fix_price_sales/ton_simple_sale/deploy_function.tolk:
        //   value -> domain : domainRefillFee()                                     (NFT deposit + 1yr domain storage)
        //   value -> sale   : deployTonSimpleSaleValue()
        //                     = nftTransferFee() + saleStorageReserve(1yr) + gasFee(GAS_SALE_DEPLOY=10000)
        //   + forward fees of those two outgoing messages (deploy msg carries the state init).
        // (auto-renew reserve/prepay are extra and only if iterations are prepaid — excluded here.)
        const SALE_BITS = 40000n, SALE_CELLS = 80n; // SALE_STORAGE_* (padded), from ton_simple_sale/constants.tolk
        const GAS_SALE_DEPLOY = 10000n;

        async function breakdown(mainnet: boolean) {
            const bc = await Blockchain.create();
            if (mainnet) patchConfigToMainnet(bc);
            const deployer = await bc.treasury('deployer');
            const probe = bc.openContract(GasProbe.createFromConfig({}, probeCode));
            await probe.sendDeploy(deployer.getSender(), toNano('5'));

            const nftTransfer = await probe.getNftTransferFee();
            const saleStorageYear = await probe.getStorageYear(SALE_BITS, SALE_CELLS);
            const activationGas = await probe.getGas(GAS_SALE_DEPLOY);
            const domainRefill = await probe.getDomainRefillFee();
            const saleFunding = nftTransfer + saleStorageYear + activationGas;
            return { domainRefill, saleFunding, nftTransfer, saleStorageYear, activationGas, total: domainRefill + saleFunding };
        }

        const c = await breakdown(false);
        const m = await breakdown(true);

        log('\n================ DEPLOY COST — TON simple sale ================');
        log('component'.padEnd(34) + 'classic (TON)'.padStart(15) + 'mainnet (TON)'.padStart(16));
        log('-'.repeat(65));
        const row = (label: string, cv: bigint, mv: bigint) => log(label.padEnd(34) + ton(cv) + '   ' + ton(mv));
        row('→ sale: NFT transfer fee', c.nftTransfer, m.nftTransfer);
        row('→ sale: 1yr sale storage reserve', c.saleStorageYear, m.saleStorageYear);
        row('→ sale: activation gas (10k units)', c.activationGas, m.activationGas);
        log('   '.padEnd(34) + '         ----' + '            ----');
        row('  = sale funding subtotal', c.saleFunding, m.saleFunding);
        row('→ domain: refill (xfer + 1yr stor)', c.domainRefill, m.domainRefill);
        log('-'.repeat(65));
        row('TOTAL value attached (no auto-renew)', c.total, m.total);
        log('-'.repeat(65));
        log('Excludes: deploy-message forward fees (~0.001-0.002 TON live, paid by deployer) and the');
        log('marketplace handler gas. Auto-renew prepay adds autoRenewLockPerIter + 0.1 TON fee per iteration.');

        expect(m.total).toBeGreaterThan(0n);
        expect(m.total).toBeLessThan(c.total);
    });

    // -----------------------------------------------------------------------
    // PART 2 — measured gas of real action chains under LIVE mainnet prices
    // -----------------------------------------------------------------------
    const DOMAIN_NAME = 'gasreport1234.ton';
    const PRICE = toNano('100');

    async function freshDomain(bc: Blockchain, admin: SandboxContract<TreasuryContract>, owner: Address, name: string) {
        const dns = bc.openContract(
            DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode),
        );
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const r = await dns.sendStartAuction(admin.getSender(), name);
        const addr = r.transactions[2].inMessage!.info.dest! as Address;
        const d = bc.openContract(Domain.createFromAddress(addr));
        bc.now! += 3601;
        await d.sendTransfer(admin.getSender(), owner, owner);
        return { dns, d, addr };
    }

    async function buildActiveSale(bc: Blockchain, admin: SandboxContract<TreasuryContract>, seller: SandboxContract<TreasuryContract>) {
        const { d, addr } = await freshDomain(bc, admin, seller.address, DOMAIN_NAME);
        const cfg: TonSimpleSaleConfig = {
            domainAddress: addr, sellerAddress: seller.address, price: PRICE,
            state: TonSimpleSale.STATE_UNINIT, commission: toNano('5'),
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 30,
            buyerAddress: null, domainName: DOMAIN_NAME, autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(TonSimpleSale.createFromConfig(cfg, saleCode));
        await sale.sendDeploy(admin.getSender(), toNano('0.05'));
        await d.sendTransfer(seller.getSender(), sale.address, null, null, 0n, 0, toNano('0.015'));
        return { sale, domain: d, dAddr: addr };
    }

    type Row = { action: string; actor: string; gasUsed: bigint; gasFee: bigint; totalNet: bigint };

    it('MEASURED gas of action chains at live mainnet prices', async () => {
        const rows: Row[] = [];
        const push = (action: string, actor: string, g?: TxGas) => {
            if (g) rows.push({ action, actor, gasUsed: g.gasUsed, gasFee: g.gasFees, totalNet: g.totalFees });
        };

        // ---- standalone domain transfer (bare NFT move) ----
        {
            const bc = await Blockchain.create();
            patchConfigToMainnet(bc);
            bc.now = MIN_PRICE_START_TIME;
            const admin = await bc.treasury('admin');
            const a = await bc.treasury('alice');
            const b = await bc.treasury('bob');
            const { d, addr } = await freshDomain(bc, admin, a.address, 'xferdomain01.ton');
            const res = await d.sendTransfer(a.getSender(), b.address, a.address, null, 0n, 0, toNano('0.03'));
            push('domain transfer', 'domain item', txTo(res, addr));
        }

        // ---- sale: purchase / cancel / renew ----
        for (const which of ['purchase', 'cancel', 'renew'] as const) {
            const bc = await Blockchain.create();
            patchConfigToMainnet(bc);
            bc.now = MIN_PRICE_START_TIME;
            const admin = await bc.treasury('admin');
            const seller = await bc.treasury('seller');
            const buyer = await bc.treasury('buyer');
            const { sale, dAddr } = await buildActiveSale(bc, admin, seller);

            if (which === 'purchase') {
                const res = await sale.sendPurchase(buyer.getSender(), PRICE);
                push('sale purchase', 'sale handler', txTo(res, sale.address));
                push('  └ domain xfer', 'domain item', txTo(res, dAddr));
            } else if (which === 'cancel') {
                const res = await sale.sendCancelSale(seller.getSender());
                push('sale cancel', 'sale handler', txTo(res, sale.address));
                push('  └ domain xfer', 'domain item', txTo(res, dAddr));
            } else {
                bc.now! += ONE_DAY * 30;
                const res = await sale.sendRenewDomain(seller.getSender());
                push('sale renew domain', 'sale handler', txTo(res, sale.address));
                push('  └ domain renew', 'domain item', txTo(res, dAddr));
            }
        }

        log('\n================ MEASURED GAS (live mainnet prices, 66.67 nT/gas) ================');
        log('action'.padEnd(22) + 'who'.padEnd(14) + 'gasUsed'.padStart(9) + 'gasFee TON'.padStart(15) + 'net fees TON'.padStart(15));
        log('-'.repeat(75));
        for (const r of rows) {
            log(r.action.padEnd(22) + r.actor.padEnd(14) + String(r.gasUsed).padStart(9) + ton(r.gasFee) + '   ' + ton(r.totalNet));
        }
        log('-'.repeat(75));
        log('gasUsed is price-independent (raw VM units). gasFee = gasUsed × live gas price.');
        log('net fees = gas + storage + forward actually burned by that account on that tx.');

        expect(rows.length).toBeGreaterThan(0);
    });
});

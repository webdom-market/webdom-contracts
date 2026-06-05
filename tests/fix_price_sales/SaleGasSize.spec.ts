import { Blockchain, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, fromNano, toNano } from '@ton/core';
import { TonSimpleSale, TonSimpleSaleConfig } from '../../wrappers/TonSimpleSale';
import { TonMultipleSale, TonMultipleSaleConfig } from '../../wrappers/TonMultipleSale';
import { JettonMultipleSale, JettonMultipleSaleConfig } from '../../wrappers/JettonMultipleSale';
import { Dictionary } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { ONE_DAY, ONE_YEAR } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// count distinct cells + total bits of a cell tree
function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}

describe('SaleGasSize', () => {
    it('measures sale code+data size and the forward fee for its messages', async () => {
        const saleCode = await compile('TonSimpleSale');
        const cfg: TonSimpleSaleConfig = {
            domainAddress: new Address(0, Buffer.alloc(32)), sellerAddress: new Address(0, Buffer.alloc(32)),
            price: toNano('100'), state: 1, commission: toNano('5'),
            createdAt: 1, lastRenewalTime: 1, validUntil: 2, buyerAddress: null,
            domainName: 'examplelongdomainname.ton', autoRenewCooldown: ONE_DAY, autoRenewIterations: 2,
        };
        const data = TonSimpleSale.createFromConfig(cfg, saleCode).init!.data;
        const c = sizeOf(saleCode), d = sizeOf(data);
        const total = { cells: c.cells + d.cells, bits: c.bits + d.bits };
        log(`\n>>> sale CODE: ${c.cells} cells, ${c.bits} bits`);
        log(`>>> sale DATA: ${d.cells} cells, ${d.bits} bits`);
        log(`>>> sale TOTAL (code+data): ${total.cells} cells, ${total.bits} bits`);
        // storage rent/year at classic (cell 500, bit 1) and mainnet (cell 135, bit 0):
        const classic = (total.cells*500 + total.bits*1) * ONE_YEAR / 65536;
        const mainnet = (total.cells*135 + total.bits*0) * ONE_YEAR / 65536;
        log(`>>> storage/year classic(cell500/bit1) = ${(classic/1e9).toFixed(6)} TON ; mainnet(cell135/bit0) = ${(mainnet/1e9).toFixed(6)} TON`);
        // forward fee for a typical message: lump + bits*bit_price + cells*cell_price
        const fwd = (cells:number, bits:number, lump:number, bp:number, cp:number) => (lump + Math.ceil((bp*bits + cp*cells)/65536));
        log(`>>> fwd fee, 1-cell ~600-bit msg: classic=${(fwd(1,600,400000,26214400,2621440000)/1e9).toFixed(6)} TON ; mainnet=${(fwd(1,600,66667,4369067,436906667)/1e9).toFixed(6)} TON`);
        log(`>>> fwd fee, header-only msg (~300 bits, 0 ref-cells): mainnet=${(fwd(0,300,66667,4369067,436906667)/1e9).toFixed(6)} TON`);

        // Guard against size drift: these mirror SALE_STORAGE_CELLS / SALE_STORAGE_BITS in
        // contracts/fix_price_sales/ton_simple_sale/constants.tolk. If this fails, re-measure and bump them.
        expect(total.cells).toBeLessThanOrEqual(80);
        expect(total.bits).toBeLessThanOrEqual(40000);
    });

    it('measures multiple-sale code+data size, base and per-domain slope', async () => {
        const code = await compile('TonMultipleSale');
        const c = sizeOf(code);
        log(`\n>>> multiple-sale CODE: ${c.cells} cells, ${c.bits} bits`);

        const mk = (n: number) => {
            const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
            for (let i = 0; i < n; i++) dict.set(new Address(0, Buffer.alloc(32, i + 1)), 0);
            const cfg: TonMultipleSaleConfig = {
                sellerAddress: new Address(0, Buffer.alloc(32)), domainsDict: dict,
                domainsTotal: n, domainsReceived: 0, price: toNano('100'), state: 1,
                commission: toNano('5'), createdAt: 1, lastRenewalTime: 1, validUntil: 2,
                buyerAddress: null, tonsToReserve: 0, autoRenewCooldown: ONE_DAY, autoRenewIterations: 2,
            };
            return sizeOf(TonMultipleSale.createFromConfig(cfg, code).init!.data);
        };

        const d1 = mk(1), d50 = mk(50);
        // total = code + data; data grows with the domains dict
        const tot = (d: {cells:number,bits:number}) => ({ cells: c.cells + d.cells, bits: c.bits + d.bits });
        const t1 = tot(d1), t50 = tot(d50);
        log(`>>> multiple-sale TOTAL @ 1 domain : ${t1.cells} cells, ${t1.bits} bits`);
        log(`>>> multiple-sale TOTAL @ 50 domains: ${t50.cells} cells, ${t50.bits} bits`);
        // linear fit: per-domain slope and base (size at 0 domains)
        const slopeCells = (t50.cells - t1.cells) / 49, slopeBits = (t50.bits - t1.bits) / 49;
        const baseCells = t1.cells - slopeCells, baseBits = t1.bits - slopeBits;
        log(`>>> fit: base ${baseCells.toFixed(1)} cells / ${baseBits.toFixed(0)} bits ; per-domain +${slopeCells.toFixed(2)} cells / +${slopeBits.toFixed(1)} bits`);
        // storage/year at classic & mainnet for the 50-domain case
        const rent = (t:{cells:number,bits:number}, cp:number, bp:number) => (t.cells*cp + t.bits*bp) * ONE_YEAR / 65536;
        log(`>>> storage/year @50: classic=${(rent(t50,500,1)/1e9).toFixed(6)} TON ; mainnet=${(rent(t50,135,0)/1e9).toFixed(6)} TON`);
        log(`>>> storage/year @1 : classic=${(rent(t1,500,1)/1e9).toFixed(6)} TON ; mainnet=${(rent(t1,135,0)/1e9).toFixed(6)} TON`);

        // jetton multiple sale (different code size, same per-domain dict slope)
        const jcode = await compile('JettonMultipleSale');
        const jc = sizeOf(jcode);
        const mkj = (n: number) => {
            const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
            for (let i = 0; i < n; i++) dict.set(new Address(0, Buffer.alloc(32, i + 1)), 0);
            const cfg: JettonMultipleSaleConfig = {
                sellerAddress: new Address(0, Buffer.alloc(32)), domainsDict: dict,
                domainsTotal: n, domainsReceived: 0, price: toNano('100'), state: 1,
                commission: toNano('5'), createdAt: 1, lastRenewalTime: 1, validUntil: 2,
                buyerAddress: null, jettonMinterAddress: new Address(0, Buffer.alloc(32)),
                jettonWalletAddress: null, tonsToReserve: 0, autoRenewCooldown: ONE_DAY, autoRenewIterations: 2,
            };
            return sizeOf(JettonMultipleSale.createFromConfig(cfg, jcode).init!.data);
        };
        const jt50 = { cells: jc.cells + mkj(50).cells, bits: jc.bits + mkj(50).bits };
        log(`>>> jetton-multiple CODE: ${jc.cells} cells, ${jc.bits} bits ; TOTAL @50: ${jt50.cells} cells, ${jt50.bits} bits`);

        // Drift guard: the storage-size constants in {ton,jetton}_multiple_sale/constants.tolk are
        //   MULTI_SALE_BASE = 90 cells / 50000 bits ; per-domain = 3 cells / 320 bits.
        // The padded model must dominate the measured size at 50 domains for BOTH variants.
        const modelCells = 90 + 3 * 50, modelBits = 50000 + 320 * 50;
        expect(t50.cells).toBeLessThanOrEqual(modelCells);
        expect(t50.bits).toBeLessThanOrEqual(modelBits);
        expect(jt50.cells).toBeLessThanOrEqual(modelCells);
        expect(jt50.bits).toBeLessThanOrEqual(modelBits);
        // base (0-domain) must also be covered
        expect(baseCells).toBeLessThanOrEqual(90);
        expect(baseBits).toBeLessThanOrEqual(50000);
    });
});

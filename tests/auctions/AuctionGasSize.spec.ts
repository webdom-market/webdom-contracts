import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { TonSimpleAuction, TonSimpleAuctionConfig } from '../../wrappers/TonSimpleAuction';
import { JettonSimpleAuction, JettonSimpleAuctionConfig } from '../../wrappers/JettonSimpleAuction';
import { TonMultipleAuction, TonMultipleAuctionConfig } from '../../wrappers/TonMultipleAuction';
import { JettonMultipleAuction, JettonMultipleAuctionConfig } from '../../wrappers/JettonMultipleAuction';
import { ONE_YEAR } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure the AUCTION contracts' own code+data size, to replace the magic TONS_MIN_TON_FOR_STORAGE
// (ton 0.035 / 0.04, "reserve to pay storage fees for ~1 year") with a computed storageFee() model:
//   simpleAuctionStorageReserve()        = storageFee(ONE_YEAR, AUCTION_SIMPLE_BITS, AUCTION_SIMPLE_CELLS)
//   multiAuctionStorageReserve(secs, N)  = storageFee(secs, MULTI_BASE_BITS+PER_DOMAIN_BITS*N, MULTI_BASE_CELLS+PER_DOMAIN_CELLS*N)
// One padded model per category must dominate BOTH the TON and jetton variants.
function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}
const A = () => new Address(0, Buffer.alloc(32, 7));
const rentClassic = (t: { cells: number; bits: number }) => (t.cells * 500 + t.bits * 1) * ONE_YEAR / 65536;
const rentMainnet = (t: { cells: number; bits: number }) => (t.cells * 135 + t.bits * 0) * ONE_YEAR / 65536;

describe('AuctionGasSize', () => {
    it('simple auctions (ton + jetton) fit AUCTION_SIMPLE model', async () => {
        const tonCode = await compile('TonSimpleAuction');
        const jettonCode = await compile('JettonSimpleAuction');
        const longName = 'examplelongestdomainname1234.ton';

        const tonCfg: TonSimpleAuctionConfig = {
            domainAddress: A(), sellerAddress: A(), minBidValue: toNano('1'), maxBidValue: toNano('100'),
            minBidIncrement: 1100, timeIncrement: 3600, commissionFactor: 500, state: 1, isDeferred: false,
            startTime: 1, endTime: 2, lastDomainRenewalTime: 1, lastBidValue: toNano('5'), lastBidTime: 1,
            lastBidderAddress: A(), domainName: longName, maxCommission: toNano('10'), hotUntil: 123456, coloredUntil: 123456,
        };
        const jettonCfg: JettonSimpleAuctionConfig = {
            domainAddress: A(), sellerAddress: A(), minBidValue: toNano('1'), maxBidValue: toNano('100'),
            minBidIncrement: 1100, timeIncrement: 3600, commissionFactor: 500, maxCommission: toNano('10'),
            jettonWalletAddress: A(), jettonMinterAddress: A(), state: 1, startTime: 1, endTime: 2,
            lastDomainRenewalTime: 1, lastBidValue: toNano('5'), lastBidTime: 1, lastBidderAddress: A(),
            domainName: longName, isDeferred: false, hotUntil: 123456, coloredUntil: 123456,
        };

        const tonTot = add(sizeOf(tonCode), sizeOf(TonSimpleAuction.createFromConfig(tonCfg, tonCode).init!.data));
        const jTot = add(sizeOf(jettonCode), sizeOf(JettonSimpleAuction.createFromConfig(jettonCfg, jettonCode).init!.data));
        log(`\n>>> ton_simple_auction    TOTAL: ${tonTot.cells} cells / ${tonTot.bits} bits | rent/yr classic ${(rentClassic(tonTot) / 1e9).toFixed(6)} mainnet ${(rentMainnet(tonTot) / 1e9).toFixed(6)}`);
        log(`>>> jetton_simple_auction TOTAL: ${jTot.cells} cells / ${jTot.bits} bits | rent/yr classic ${(rentClassic(jTot) / 1e9).toFixed(6)} mainnet ${(rentMainnet(jTot) / 1e9).toFixed(6)}`);

        // Proposed padded model — must dominate both variants:
        const AUCTION_SIMPLE_CELLS = 80, AUCTION_SIMPLE_BITS = 44000;
        log(`>>> model AUCTION_SIMPLE = ${AUCTION_SIMPLE_CELLS} cells / ${AUCTION_SIMPLE_BITS} bits | reserve/yr classic ${(rentClassic({ cells: AUCTION_SIMPLE_CELLS, bits: AUCTION_SIMPLE_BITS }) / 1e9).toFixed(6)} (old magic 0.035)`);
        expect(tonTot.cells).toBeLessThanOrEqual(AUCTION_SIMPLE_CELLS);
        expect(tonTot.bits).toBeLessThanOrEqual(AUCTION_SIMPLE_BITS);
        expect(jTot.cells).toBeLessThanOrEqual(AUCTION_SIMPLE_CELLS);
        expect(jTot.bits).toBeLessThanOrEqual(AUCTION_SIMPLE_BITS);
    });

    it('multiple auctions (ton + jetton) fit MULTI_AUCTION base+per-domain model', async () => {
        const tonCode = await compile('TonMultipleAuction');
        const jettonCode = await compile('JettonMultipleAuction');

        const dict = (n: number) => {
            const d = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
            for (let i = 0; i < n; i++) d.set(new Address(0, Buffer.alloc(32, i + 1)), 1);
            return d;
        };
        const tonData = (n: number) => sizeOf(TonMultipleAuction.createFromConfig({
            sellerAddress: A(), domainsDict: dict(n), domainsTotal: n, domainsReceived: n,
            minBidValue: toNano('1'), maxBidValue: toNano('100'), minBidIncrement: 1100, timeIncrement: 3600,
            commissionFactor: 500, maxCommission: toNano('10'), state: 1, startTime: 1, endTime: 2,
            lastDomainRenewalTime: 1, lastBidValue: toNano('5'), lastBidTime: 1, lastBidderAddress: A(),
            isDeferred: false, hotUntil: 123456, coloredUntil: 123456,
        } as TonMultipleAuctionConfig, tonCode).init!.data);
        const jettonData = (n: number) => sizeOf(JettonMultipleAuction.createFromConfig({
            sellerAddress: A(), domainsDict: dict(n), domainsTotal: n, domainsReceived: n,
            minBidValue: toNano('1'), maxBidValue: toNano('100'), minBidIncrement: 1100, timeIncrement: 3600,
            commissionFactor: 500, maxCommission: toNano('10'), jettonWalletAddress: A(), jettonMinterAddress: A(),
            state: 1, startTime: 1, endTime: 2, lastDomainRenewalTime: 1, lastBidValue: toNano('5'), lastBidTime: 1,
            lastBidderAddress: A(), isDeferred: false, hotUntil: 123456, coloredUntil: 123456,
        } as JettonMultipleAuctionConfig, jettonCode).init!.data);

        const tc = sizeOf(tonCode), jc = sizeOf(jettonCode);
        const ton1 = add(tc, tonData(1)), ton50 = add(tc, tonData(50));
        const j1 = add(jc, jettonData(1)), j50 = add(jc, jettonData(50));
        const slope = (a: any, b: any, d: number) => ({ cells: (b.cells - a.cells) / d, bits: (b.bits - a.bits) / d });
        const tonSlope = slope(ton1, ton50, 49), jSlope = slope(j1, j50, 49);
        log(`\n>>> ton_multiple    @1=${ton1.cells}c/${ton1.bits}b  @50=${ton50.cells}c/${ton50.bits}b  per-domain +${tonSlope.cells.toFixed(2)}c/+${tonSlope.bits.toFixed(1)}b`);
        log(`>>> jetton_multiple @1=${j1.cells}c/${j1.bits}b  @50=${j50.cells}c/${j50.bits}b  per-domain +${jSlope.cells.toFixed(2)}c/+${jSlope.bits.toFixed(1)}b`);
        log(`>>> rent/yr @50 classic: ton ${(rentClassic(ton50) / 1e9).toFixed(6)} jetton ${(rentClassic(j50) / 1e9).toFixed(6)} (old magic 0.035/0.04)`);

        // Proposed padded model — must dominate BOTH variants at up to 50 domains AND the base:
        const BASE_CELLS = 95, BASE_BITS = 50000, PER_DOMAIN_CELLS = 3, PER_DOMAIN_BITS = 320;
        const model = (n: number) => ({ cells: BASE_CELLS + PER_DOMAIN_CELLS * n, bits: BASE_BITS + PER_DOMAIN_BITS * n });
        log(`>>> model MULTI base=${BASE_CELLS}c/${BASE_BITS}b per-domain=${PER_DOMAIN_CELLS}c/${PER_DOMAIN_BITS}b | reserve/yr @1 classic ${(rentClassic(model(1)) / 1e9).toFixed(6)} @50 ${(rentClassic(model(50)) / 1e9).toFixed(6)}`);
        for (const n of [1, 50]) {
            expect(add(tc, tonData(n)).cells).toBeLessThanOrEqual(model(n).cells);
            expect(add(tc, tonData(n)).bits).toBeLessThanOrEqual(model(n).bits);
            expect(add(jc, jettonData(n)).cells).toBeLessThanOrEqual(model(n).cells);
            expect(add(jc, jettonData(n)).bits).toBeLessThanOrEqual(model(n).bits);
        }
    });
});

function add(a: { cells: number; bits: number }, b: { cells: number; bits: number }) {
    return { cells: a.cells + b.cells, bits: a.bits + b.bits };
}

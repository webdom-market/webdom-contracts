import { Blockchain } from '@ton/sandbox';
import { Address, Cell, Dictionary, toNano } from '@ton/core';
import { DomainSwap, DomainSwapConfig } from '../../wrappers/DomainSwap';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { ONE_YEAR } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// count distinct cells + total bits of a cell tree
function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}

// Mirrors SWAP_BASE_* / SWAP_PER_DOMAIN_* in contracts/domain_swap/constants.tolk.
// The swap holds TWO sides (leftInfo + rightInfo), so the size scales with the TOTAL domains (left+right).
const SWAP_BASE_CELLS = 75, SWAP_BASE_BITS = 36000, SWAP_PER_DOMAIN_CELLS = 3, SWAP_PER_DOMAIN_BITS = 300;

describe('SwapGasSize', () => {
    it('measures DomainSwap code+data size, base + per-(total)domain slope', async () => {
        const code = await compile('DomainSwap');
        const c = sizeOf(code);
        log(`\n>>> DomainSwap CODE: ${c.cells} cells, ${c.bits} bits`);

        // build a fully-populated two-dict config holding L left + R right domains
        const mk = (L: number, R: number) => {
            const ld = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
            for (let i = 0; i < L; i++) ld.set(new Address(0, Buffer.alloc(32, i + 1)), true);
            const rd = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
            for (let i = 0; i < R; i++) rd.set(new Address(0, Buffer.alloc(32, 200 - i)), true);
            const cfg: DomainSwapConfig = {
                leftParticipantAddress: new Address(0, Buffer.alloc(32)), leftDomainsTotal: L, leftDomainsReceived: L,
                leftDomainsDict: ld, leftPaymentTotal: toNano('5'), leftPaymentReceived: toNano('5'),
                rightParticipantAddress: new Address(0, Buffer.alloc(32, 9)), rightDomainsTotal: R, rightDomainsReceived: R,
                rightDomainsDict: rd, rightPaymentTotal: toNano('10'), rightPaymentReceived: toNano('10'),
                state: 1, createdAt: 1, validUntil: 2, lastActionTime: 1, commission: toNano('0.1'), needsAlert: true, cancelledByLeft: false,
            };
            return sizeOf(DomainSwap.createFromConfig(cfg, code).init!.data);
        };

        // measure at several TOTAL-domain counts (split across both sides)
        const pts: Array<{ n: number; cells: number; bits: number }> = [];
        for (const [L, R] of [[1, 1], [2, 3], [25, 25], [50, 50]] as [number, number][]) {
            const d = mk(L, R);
            const tot = { cells: c.cells + d.cells, bits: c.bits + d.bits };
            pts.push({ n: L + R, cells: tot.cells, bits: tot.bits });
            log(`>>> @ ${String(L + R).padStart(3)} domains (L${L}+R${R}): TOTAL ${tot.cells} cells, ${tot.bits} bits`);
        }
        // linear fit base + per-domain slope (use the two extreme points)
        const a = pts[0], z = pts[pts.length - 1];
        const slopeCells = (z.cells - a.cells) / (z.n - a.n), slopeBits = (z.bits - a.bits) / (z.n - a.n);
        const baseCells = a.cells - slopeCells * a.n, baseBits = a.bits - slopeBits * a.n;
        log(`>>> fit: base ${baseCells.toFixed(1)}c / ${baseBits.toFixed(0)}b ; per-domain +${slopeCells.toFixed(2)}c / +${slopeBits.toFixed(1)}b`);

        // storage/year sanity at classic & mainnet
        const rent = (cells: number, bits: number, cp: number, bp: number) => Math.ceil((cells * cp + bits * bp) * ONE_YEAR / 65536);
        const big = pts[pts.length - 1];
        log(`>>> storage/yr @${big.n}: classic=${(rent(big.cells, big.bits, 500, 1) / 1e9).toFixed(6)} TON ; mainnet=${(rent(big.cells, big.bits, 135, 0) / 1e9).toFixed(6)} TON`);

        // Drift guard: the padded model in constants.tolk must DOMINATE the measured size at every point
        // (so swapStorageReserve never under-reserves), AND dominate the fitted base/slope.
        for (const p of pts) {
            expect(p.cells).toBeLessThanOrEqual(SWAP_BASE_CELLS + SWAP_PER_DOMAIN_CELLS * p.n);
            expect(p.bits).toBeLessThanOrEqual(SWAP_BASE_BITS + SWAP_PER_DOMAIN_BITS * p.n);
        }
        expect(baseCells).toBeLessThanOrEqual(SWAP_BASE_CELLS);
        expect(baseBits).toBeLessThanOrEqual(SWAP_BASE_BITS);
        expect(slopeCells).toBeLessThanOrEqual(SWAP_PER_DOMAIN_CELLS);
        expect(slopeBits).toBeLessThanOrEqual(SWAP_PER_DOMAIN_BITS);
    });
});

import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { MIN_PRICE_START_TIME, ONE_YEAR } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}
// storage fee per year, nanoTON, given size and (cellPrice,bitPrice) per 65536 s
const storagePerYear = (cells: number, bits: number, cp: number, bp: number) =>
    Math.ceil((cells * cp + bits * bp) * ONE_YEAR / 65536);

// a representative DNS wallet "address" record value cell (~tag + DISTINCT address + flags)
function dnsAddrValue(seed: number): Cell {
    const a = Buffer.alloc(32); a.writeUInt32BE(seed >>> 0, 0); a.writeUInt32BE((seed * 2654435761) >>> 0, 4);
    return beginCell().storeUint(0x9fd3, 16).storeAddress(new Address(0, a)).storeUint(0, 8).endCell();
}
function contentWith(n: number): Cell {
    const d = Dictionary.empty(Dictionary.Keys.BigUint(256), Dictionary.Values.Cell());
    for (let i = 0; i < n; i++) d.set(BigInt(i + 1), dnsAddrValue(i));
    return beginCell().storeUint(0, 8).storeDict(d).endCell();
}

describe('DomainGasSize', () => {
    let dnsCode: Cell, domainCode: Cell;
    beforeAll(async () => { dnsCode = await compile('DnsCollection'); domainCode = await compile('Domain'); });

    it('TG username item: code size + projected storage (same record-dict cost)', async () => {
        const tgCode = await compile('TgUsername');
        const cs = sizeOf(tgCode);
        log(`\n>>> TG username item CODE: ${cs.cells} cells, ${cs.bits} bits`);
        // per-record cost measured on the TON DNS item: ~3 cells, ~295 bits (identical udict_set_ref(256,..) structure)
        const baseDataCells = 4, baseDataBits = 1200; // ~comparable item header (owner, content, auction, royalty)
        log(`#recs | est total cells | storage/yr CLASSIC | storage/yr MAINNET`);
        for (const N of [0, 100, 1000]) {
            const cells = cs.cells + baseDataCells + 3 * N;
            const bits = cs.bits + baseDataBits + 295 * N;
            log(`${String(N).padEnd(5)} | ${String(cells).padEnd(15)} | ${(storagePerYear(cells, bits, 500, 1)/1e9).toFixed(6)} TON | ${(storagePerYear(cells, bits, 135, 0)/1e9).toFixed(6)} TON`);
        }
    });

    it('TON DNS item size + 1-year storage vs #records', async () => {
        const codeSize = sizeOf(domainCode);
        log(`\n>>> TON DNS item CODE: ${codeSize.cells} cells, ${codeSize.bits} bits`);
        log(`#recs | data cells | data bits | total cells | storage/yr CLASSIC(cell500/bit1) | storage/yr MAINNET(cell135/bit0)`);
        for (const N of [50]) {
            const bc = await Blockchain.create();
            bc.now = MIN_PRICE_START_TIME;
            const admin = await bc.treasury('admin');
            const owner = await bc.treasury('owner');
            const dns = bc.openContract(DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
            await dns.sendDeploy(admin.getSender(), toNano('0.05'));
            const r = await dns.sendStartAuction(admin.getSender(), `sizetest${N}999.ton`);
            const dAddr = r.transactions[2].inMessage!.info.dest! as Address;
            const domain = bc.openContract(Domain.createFromAddress(dAddr));
            bc.now += 3601;
            await domain.sendTransfer(admin.getSender(), owner.address, owner.address);
            if (N > 0) {
                // edit_content with enough gas (wrapper hardcodes 0.001 TON = 2500 gas -> out of gas)
                const cc = await owner.send({ to: dAddr, value: toNano('0.2'), body: Domain.changeContentMessage(contentWith(N), 0) });
                const ok = cc.transactions.some((t: any) => t.inMessage?.info?.dest?.toString() === dAddr.toString() && t.description.computePhase?.success);
                if (!ok) log(`  (N=${N}) edit_content FAILED`);
            }

            const st = await bc.provider(dAddr).getState();
            const raw = (st.state as any).data;
            const data = Buffer.isBuffer(raw) ? Cell.fromBoc(raw)[0] : raw as Cell;
            const ds = sizeOf(data);
            const total = { cells: codeSize.cells + ds.cells, bits: codeSize.bits + ds.bits };
            const classic = storagePerYear(total.cells, total.bits, 500, 1);
            const mainnet = storagePerYear(total.cells, total.bits, 135, 0);
            log(`${String(N).padEnd(5)} | ${String(ds.cells).padEnd(10)} | ${String(ds.bits).padEnd(9)} | ${String(total.cells).padEnd(11)} | ${(classic/1e9).toFixed(6)} TON | ${(mainnet/1e9).toFixed(6)} TON`);
        }
    });
});

import { Blockchain } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain, createTextRecordCell } from '../../wrappers/Domain';
import { MIN_PRICE_START_TIME, ONE_YEAR } from '../../wrappers/helpers/constants';
import { txGas, log } from '../helpers/gas';

function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}
const storagePerYear = (cells: number, bits: number, cp: number, bp: number) =>
    Math.ceil((cells * cp + bits * bp) * ONE_YEAR / 65536);
const gasFee = (units: number, price: number) => Math.ceil(units * price);

// a representative DNS "address" record value cell (distinct address each)
function dnsAddrValue(seed: number): Cell {
    const a = Buffer.alloc(32); a.writeUInt32BE(seed >>> 0, 0); a.writeUInt32BE((seed * 2654435761) >>> 0, 4);
    return beginCell().storeUint(0x9fd3, 16).storeAddress(new Address(0, a)).storeUint(0, 8).endCell();
}
function contentWith(n: number): Cell {
    const d = Dictionary.empty(Dictionary.Keys.BigUint(256), Dictionary.Values.Cell());
    for (let i = 0; i < n; i++) d.set(BigInt(i + 1), dnsAddrValue(i));
    return beginCell().storeUint(0, 8).storeDict(d).endCell();
}

// classic (sandbox) and live-mainnet (June 2026) prices
const PRICES = {
    classic: { gas: 400, cell: 500, bit: 1 },
    mainnet: { gas: 66.6672, cell: 135, bit: 0 },
};

describe('ChangeDnsRecordGas — actual change_dns_record compute + the storage one record adds', () => {
    let dnsCode: Cell, domainCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    // the change_dns_record tx on the item: dest = item, op = 0x4eb1f0f9
    function measureChange(res: any, itemAddr: Address) {
        const txs = res.transactions as any[];
        for (let i = 0; i < txs.length; i++) {
            const t = txs[i];
            if (t.inMessage?.info?.dest?.toString?.() !== itemAddr.toString()) continue;
            const body = t.inMessage?.body?.beginParse?.();
            if (!body || body.remainingBits < 32) continue;
            if (body.loadUint(32) !== 0x4eb1f0f9) continue;
            const g = txGas(t, i);
            return { gasUsed: g.gasUsed, exit: g.exitCode ?? 0, found: true };
        }
        return { gasUsed: 0n, exit: -999, found: false };
    }

    async function dataSize(bc: Blockchain, addr: Address) {
        const st = await bc.provider(addr).getState();
        const raw = (st.state as any).data; const data = Buffer.isBuffer(raw) ? Cell.fromBoc(raw)[0] : raw as Cell;
        return sizeOf(data);
    }

    it('TON DNS domain: change_dns_record compute (worst case near 50 records) + per-record size', async () => {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const owner = await bc.treasury('owner');
        const dns = bc.openContract(DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const r = await dns.sendStartAuction(admin.getSender(), 'changednsgas999.ton');
        const dAddr = r.transactions[2].inMessage!.info.dest! as Address;
        const domain = bc.openContract(Domain.createFromAddress(dAddr));
        bc.now += 3601;
        await domain.sendTransfer(admin.getSender(), owner.address, owner.address);

        // pre-load 49 records, then measure adding the 50th (deepest dict insert = worst case)
        await owner.send({ to: dAddr, value: toNano('0.3'), body: Domain.changeContentMessage(contentWith(49), 0) });
        const size49 = await dataSize(bc, dAddr);

        // ADD a new (50th) record — fresh key
        const addRes = await domain.sendChangeDnsRecord(owner.getSender(), BigInt(50), dnsAddrValue(49), 0, toNano('0.1'));
        const mAdd = measureChange(addRes, dAddr);
        const size50 = await dataSize(bc, dAddr);

        // OVERWRITE an existing record (same key, new value) — also a realistic case
        const owRes = await domain.sendChangeDnsRecord(owner.getSender(), BigInt(25), dnsAddrValue(1000), 0, toNano('0.1'));
        const mOw = measureChange(owRes, dAddr);

        const perAddr = { cells: size50.cells - size49.cells, bits: size50.bits - size49.bits };

        // WORST-CASE record we actually send: the per-domain `links` text record for a max-length
        // domain name ("https://webdom.market/domain/" = 29B + up to 126B name -> 2-chunk dns_text).
        const linkText = 'https://webdom.market/domain/' + 'n'.repeat(126);
        const linkValue = createTextRecordCell(linkText);
        const sizeBeforeLink = await dataSize(bc, dAddr);
        const linkRes = await domain.sendChangeDnsRecord(owner.getSender(), BigInt(60), linkValue, 0, toNano('0.1'));
        const mLink = measureChange(linkRes, dAddr);
        const sizeAfterLink = await dataSize(bc, dAddr);
        const perLink = { cells: sizeAfterLink.cells - sizeBeforeLink.cells, bits: sizeAfterLink.bits - sizeBeforeLink.bits };

        log(`\n===== TON DNS domain: change_dns_record =====`);
        log(`add address record : exit=${mAdd.exit} compute=${mAdd.gasUsed} gas`);
        log(`overwrite address  : exit=${mOw.exit} compute=${mOw.gasUsed} gas`);
        log(`add max link record: exit=${mLink.exit} compute=${mLink.gasUsed} gas`);
        log(`size delta address record: +${perAddr.cells} cells, +${perAddr.bits} bits`);
        log(`size delta max link rec. : +${perLink.cells} cells, +${perLink.bits} bits`);
        const worstGas = Number([mAdd.gasUsed, mOw.gasUsed, mLink.gasUsed].reduce((a, b) => (a > b ? a : b)));
        const worstCells = Math.max(perAddr.cells, perLink.cells);
        const worstBits = Math.max(perAddr.bits, perLink.bits);
        for (const [name, p] of Object.entries(PRICES)) {
            const compute = gasFee(worstGas, p.gas);
            const storage = storagePerYear(worstCells, worstBits, p.cell, p.bit);
            log(`  ${name.padEnd(8)}: compute=${(compute / 1e9).toFixed(6)}  storage/yr(worst rec)=${(storage / 1e9).toFixed(6)} TON`);
        }

        expect(mAdd.exit).toBe(0);
        expect(mOw.exit).toBe(0);
        expect(mLink.exit).toBe(0);
        // Drift guards — the gas.tolk constants must dominate the measured worst case (incl. max link).
        expect(worstGas).toBeLessThanOrEqual(17000);         // DNS_CHANGE_RECORD_GAS
        expect(worstCells).toBeLessThanOrEqual(6);           // DNS_RECORD_CELLS
        expect(worstBits).toBeLessThanOrEqual(1600);         // DNS_RECORD_BITS
    });
});

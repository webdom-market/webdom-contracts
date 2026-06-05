import { Blockchain } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { TonSimpleAuction, TonSimpleAuctionConfig } from '../../wrappers/TonSimpleAuction';
import { TonMultipleAuction, TonMultipleAuctionConfig } from '../../wrappers/TonMultipleAuction';
import { MIN_PRICE_START_TIME, ONE_DAY } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure auction COMPUTE to replace the magic gas pads in the auction contracts:
//   - simple-auction activation compute   -> GAS_AUCTION_DEPLOY            (was ton("0.005") deploy pad)
//   - multiple endAuctionSuccess per-dom  -> GAS_AUCTION_FINALIZE_PER_DOMAIN (was ton("0.01")/domain)
//   - multiple endAuctionFailed per-dom   -> GAS_AUCTION_CANCEL_PER_DOMAIN   (was ton("0.0075")/domain)
describe('AuctionGas', () => {
    let dnsCode: Cell, domainCode: Cell, simpleCode: Cell, multiCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        simpleCode = await compile('TonSimpleAuction');
        multiCode = await compile('TonMultipleAuction');
    });

    function txGas(res: any, dest: Address, pick: (t: any) => boolean = () => true): bigint {
        for (const t of res.transactions as any[]) {
            if (t.inMessage?.info?.dest?.toString?.() === dest.toString() && pick(t)) {
                return (t.description as any)?.computePhase?.gasUsed ?? 0n;
            }
        }
        return 0n;
    }
    function fit(pts: Array<{ n: number; gas: number }>) {
        const N = pts.length;
        const sx = pts.reduce((a, p) => a + p.n, 0), sy = pts.reduce((a, p) => a + p.gas, 0);
        const sxx = pts.reduce((a, p) => a + p.n * p.n, 0), sxy = pts.reduce((a, p) => a + p.n * p.gas, 0);
        const slope = (N * sxy - sx * sy) / (N * sxx - sx * sx);
        return { base: (sy - slope * sx) / N, slope };
    }

    // Build a multiple auction holding n domains (active, all received). withBid => place one sub-max bid.
    async function buildMulti(n: number, tag: string, withBid: boolean) {
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
            const r = await dns.sendStartAuction(admin.getSender(), `auc${tag}x${i}99.ton`);
            const addr = r.transactions[2].inMessage!.info.dest! as Address;
            const d = bc.openContract(Domain.createFromAddress(addr));
            bc.now += 3601;
            await d.sendTransfer(admin.getSender(), seller.address, seller.address);
            domains.push(d);
            dict.set(addr, 0);
        }
        const cfg: TonMultipleAuctionConfig = {
            sellerAddress: seller.address, domainsDict: dict, domainsTotal: n, domainsReceived: 0,
            minBidValue: toNano('1'), maxBidValue: toNano('100000'), minBidIncrement: 1050, timeIncrement: 300,
            commissionFactor: 500, maxCommission: toNano('1'), state: TonMultipleAuction.STATE_UNINIT,
            startTime: bc.now!, endTime: bc.now! + ONE_DAY * 120, lastDomainRenewalTime: bc.now!,
            lastBidValue: 0n, lastBidTime: bc.now!, lastBidderAddress: null, isDeferred: false,
        };
        const auction = bc.openContract(TonMultipleAuction.createFromConfig(cfg, multiCode));
        await auction.sendDeploy(admin.getSender(), toNano('0.06'));
        for (const d of domains) {
            await d.sendTransfer(seller.getSender(), auction.address, seller.address, null, toNano('0.07'));
        }
        if (withBid) {
            // generous total so net bid >= minBidValue after the (old) reserve, and < maxBidValue (no auto-finalize)
            await auction.sendPlaceBid(buyer.getSender(), toNano((0.2 * n + 5).toFixed(3)), n);
        }
        return { bc, auction, seller };
    }

    const counts = [1, 4, 8, 16, 32, 64];

    it('multiple-auction endAuctionSuccess per-domain compute', async () => {
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> endAuctionSuccess (finalize) compute:`);
        for (let i = 0; i < counts.length; i++) {
            const n = counts[i];
            const { bc, auction } = await buildMulti(n, 'f' + i, true);
            bc.now! += ONE_DAY * 121; // past endTime
            // External finalizer => acceptExternalMessage => contract pays gas from balance (UNCAPPED),
            // unlike internal stopAuction (limited by msg value). lastBidValue>0 & ended => endAuctionSuccess.
            const res = await auction.sendExternalCancel();
            const gas = Number(txGas(res, auction.address, t => t.inMessage?.info?.type === 'external-in'));
            pts.push({ n, gas });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(gas).padStart(6)} gas | ${(gas / n).toFixed(0)}/domain`);
        }
        const f = fit(pts);
        log(`>>>   fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain ; choose GAS_AUCTION_FINALIZE_PER_DOMAIN ~1.6x slope`);
        // The per-domain reserve gasFee(GAS_AUCTION_FINALIZE_PER_DOMAIN) must dominate the per-domain slope.
        expect(8000).toBeGreaterThanOrEqual(f.slope);
    }, 300000);

    it('multiple-auction endAuctionFailed per-domain compute', async () => {
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> endAuctionFailed (cancel) compute:`);
        for (let i = 0; i < counts.length; i++) {
            const n = counts[i];
            const { auction, seller } = await buildMulti(n, 'c' + i, false);
            const res = await auction.sendStopAuction(seller.getSender()); // lastBidValue==0 => endAuctionFailed
            const gas = Number(txGas(res, auction.address, t => t.inMessage?.info?.type === 'internal'));
            pts.push({ n, gas });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(gas).padStart(6)} gas | ${(gas / n).toFixed(0)}/domain`);
        }
        const f = fit(pts);
        log(`>>>   fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain ; choose GAS_AUCTION_CANCEL_PER_DOMAIN ~1.6x slope`);
        expect(6000).toBeGreaterThanOrEqual(f.slope);
    }, 300000);

    it('multiple-auction bid-handler base compute (proxy for jetton GAS_AUCTION_BID_PROCESSING)', async () => {
        // The jetton bid pad ton("0.01") (jetton_multiple:247) covers the bid handler's FIXED compute.
        // Measure the TON bid handler (a first bid) as a floor; the jetton variant adds jetton-notification
        // parsing/refund (~+3k, like jetton-purchase vs ton-purchase), so we pad GAS_AUCTION_BID_PROCESSING.
        const pts: Array<{ n: number; gas: number }> = [];
        log(`\n>>> TON multiple-auction bid-handler compute (first bid):`);
        for (const n of [1, 16, 32]) {
            const { bc, auction, seller } = await buildMulti(n, 'b' + n, false);
            const buyer = await bc.treasury('bidder');
            const res = await auction.sendPlaceBid(buyer.getSender(), toNano((0.2 * n + 5).toFixed(3)), n);
            const gas = Number(txGas(res, auction.address, t => t.inMessage?.info?.type === 'internal'));
            pts.push({ n, gas });
            log(`>>>   ${String(n).padStart(3)} domains | ${String(gas).padStart(6)} gas`);
        }
        const f = fit(pts);
        log(`>>>   TON bid fit: base ${f.base.toFixed(0)} + ${f.slope.toFixed(0)}/domain ; jetton base ~+3k => GAS_AUCTION_BID_PROCESSING=20000 (mirrors GAS_JETTON_MULTIPLE_PURCHASE_BASE)`);
        expect(20000).toBeGreaterThanOrEqual(f.base + 3000); // jetton bid base estimate must fit the 20000 budget
    }, 120000);

    it('simple-auction activation compute', async () => {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const cfg: TonSimpleAuctionConfig = {
            domainAddress: new Address(0, Buffer.alloc(32, 9)), sellerAddress: seller.address,
            minBidValue: toNano('1'), maxBidValue: toNano('100'), minBidIncrement: 1050, timeIncrement: 300,
            commissionFactor: 500, state: TonSimpleAuction.STATE_UNINIT, isDeferred: false,
            startTime: bc.now!, endTime: bc.now! + ONE_DAY * 120, lastDomainRenewalTime: bc.now!,
            lastBidValue: 0n, lastBidTime: bc.now!, lastBidderAddress: null, domainName: 'activationtest99.ton',
            maxCommission: toNano('1'),
        };
        const auction = bc.openContract(TonSimpleAuction.createFromConfig(cfg, simpleCode));
        const res = await auction.sendDeploy(admin.getSender(), toNano('0.03')); // FillUpBalance: UNINIT -> ACTIVE
        const gas = Number(txGas(res, auction.address));
        log(`\n>>> simple-auction activation compute = ${gas} gas ; choose GAS_AUCTION_DEPLOY ~2x => 10000`);
        expect(10000).toBeGreaterThanOrEqual(gas);
    });
});

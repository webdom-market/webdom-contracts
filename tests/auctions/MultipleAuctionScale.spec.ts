import { Blockchain, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { TonMultipleAuction, TonMultipleAuctionConfig } from '../../wrappers/TonMultipleAuction';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { MIN_PRICE_START_TIME, ONE_DAY, Tons } from '../../wrappers/helpers/constants';

// DIAGNOSTIC: measure the real auction balance through the multiple-auction cancel path,
// and find at what N the no-bid cancel (endAuctionFailed, sends domainRefillFee per domain) breaks.
describe('AuditDiag-MultiCancel', () => {
    let multiCode: Cell, dnsCode: Cell, domainCode: Cell;
    beforeAll(async () => {
        multiCode = await compile('TonMultipleAuction');
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    async function build(n: number, tag: string) {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));

        const domains: SandboxContract<Domain>[] = [];
        const dict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        for (let i = 0; i < n; i++) {
            const r = await dns.sendStartAuction(admin.getSender(), `dg${tag}x${i}99.ton`);
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
            await d.sendTransfer(seller.getSender(), auction.address, seller.address, null, toNano('0.1'));
        }
        return { bc, auction, seller, domains };
    }

    for (const n of [3, 20, 40]) {
        it(`WITH-BID finalize delivers all domains, N=${n}`, async () => {
            const { bc, auction, seller, domains } = await build(n, 'f' + n);
            const buyer = await bc.treasury('bidder');
            // sub-max bid (maxBidValue is 100000); generous TON so net bid >= minBidValue
            await auction.sendPlaceBid(buyer.getSender(), toNano((0.2 * n + 5).toFixed(3)), n);
            const cfgBid = await auction.getStorageData();
            const balAfterBid = (await bc.getContract(auction.address)).balance;
            console.log(`\n=== FINALIZE N=${n} === lastBid=${cfgBid.lastBidValue} balAfterBid=${Number(balAfterBid)/1e9} reserveTrue=${(Tons.DOMAIN_REFILL_FEE+Tons.PURCHASE_NOTIFICATION+90n*40000n)*BigInt(n)}`);
            bc.now! += ONE_DAY * 121; // past endTime
            const res = await auction.sendExternalCancel();
            let delivered = 0;
            for (const d of domains) {
                const c = await d.getStorageData();
                if (c.ownerAddress?.toString() === buyer.address.toString()) delivered++;
            }
            const cfgAfter = await auction.getStorageData();
            console.log(`state=${cfgAfter.state} (2=COMPLETED) delivered=${delivered}/${n}`);
            for (const t of res.transactions as any[]) {
                const ph = (t.description as any)?.actionPhase;
                if (ph && ph.success === false) console.log(`  ACTION FAILED rc=${ph.resultCode} to=${t.inMessage?.info?.dest?.toString?.()}`);
            }
            expect(cfgAfter.state).toEqual(TonMultipleAuction.STATE_COMPLETED);
            expect(delivered).toEqual(n);
        }, 120000);
    }

    for (const n of [3, 20]) {
        it(`EXTERNAL no-bid cancel reverts (guard passes, action fails), N=${n}`, async () => {
            const { bc, auction, seller, domains } = await build(n, 'e' + n);
            bc.now! += ONE_DAY * 121;
            const res = await auction.sendExternalCancel();
            let returned = 0;
            for (const d of domains) {
                const c = await d.getStorageData();
                if (c.ownerAddress?.toString() === seller.address.toString()) returned++;
            }
            const cfgAfter = await auction.getStorageData();
            console.log(`\n=== EXTERNAL no-bid N=${n} === state=${cfgAfter.state} returned=${returned}/${n}`);
            // After the fix: external no-bid finalize must succeed and return every domain.
            expect(cfgAfter.state).toEqual(3);
            expect(returned).toEqual(n);
        }, 120000);
    }

    for (const n of [3, 10, 20, 40]) {
        it(`no-bid cancel with N=${n}`, async () => {
            const { bc, auction, seller, domains } = await build(n, 'c' + n);
            const balBefore = (await bc.getContract(auction.address)).balance;
            console.log(`\n=== N=${n} ===`);
            console.log(`auction balance after all domains received = ${balBefore} (${Number(balBefore) / 1e9} TON)`);
            console.log(`refillFee*N = ${Tons.DOMAIN_REFILL_FEE * BigInt(n)} ; nftTransfer*N = ${Tons.NFT_TRANSFER_FEE * BigInt(n)}`);

            const res = await auction.sendStopAuction(seller.getSender());
            // count successfully-returned domains
            let returned = 0;
            for (const d of domains) {
                const c = await d.getStorageData();
                if (c.ownerAddress?.toString() === seller.address.toString()) returned++;
            }
            const cfgAfter = await auction.getStorageData();
            const balAfter = (await bc.getContract(auction.address)).balance;
            console.log(`state after cancel = ${cfgAfter.state} (3=CANCELLED) ; domains returned = ${returned}/${n} ; auction balance after = ${Number(balAfter) / 1e9} TON`);
            // After the fix: cancel must succeed and return EVERY domain to the seller.
            expect(cfgAfter.state).toEqual(3);
            expect(returned).toEqual(n);
        }, 120000);
    }
});

import { Blockchain, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../../wrappers/Domain';
import { TonSimpleOffer, TonSimpleOfferConfig } from '../../wrappers/TonSimpleOffer';
import { JettonSimpleOffer, JettonSimpleOfferConfig } from '../../wrappers/JettonSimpleOffer';
import { JettonMinter } from '../../wrappers/JettonMinter';
import { JettonWallet } from '../../wrappers/JettonWallet';
import { MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR } from '../../wrappers/helpers/constants';
import { collectGas, log } from '../helpers/gas';

// ---- live mainnet config (2026 ~6x basechain fee cut), copied from GasResearch4 ----
const LIVE = {
    18: 'te6cckEBAwEAWQACAUgBAgBM3swAAAAAAAAAAAAAAAEAAAAAAAAB9AAAAAAAAAPoAAAAAAAHoSAAU71Pk/sGY0+T+wAAAAAAAAAAAAAAAAAAAAQ4AAAAAAAAH0AAAAAAAD0JBPXsekg=',
    20: 'te6cckEBAQEATAAAlNEAAAAAAAAAZAAAAAAAD0JA3gAAAAAnEAAAAAAAAAAPQkAAAAAABCwdgAAAAAAAACcQAAAAAAAmJaAAAAAABfXhAAAAAAA7msoAKm2gQw==',
    21: 'te6cckEBAQEATAAAlNEAAAAAAAAAZAAAAAAAABoL3gAAAAAAQqqrAAAAAAAPQkAAAAAAAA9CQAAAAAAAACcQAAAAAACYloAAAAAABfXhAAAAAAA7msoAgyFv5Q==',
    25: 'te6cckEBAQEAIwAAQuoAAAAAAAEEawAAAAAAQqqrAAAAABoKqqsAAYAAVVVVVXUQ/H0=',
} as const;
function patchConfigToMainnet(blockchain: Blockchain) {
    const dict = Dictionary.loadDirect(Dictionary.Keys.Int(32), Dictionary.Values.Cell(), blockchain.config);
    for (const [k, b64] of Object.entries(LIVE)) dict.set(Number(k), Cell.fromBase64(b64));
    blockchain.setConfig(beginCell().storeDictDirect(dict).endCell());
}

function sizeOf(root: Cell) {
    const seen = new Set<string>(); let cells = 0, bits = 0;
    const walk = (c: Cell) => { const h = c.hash().toString('hex'); if (seen.has(h)) return; seen.add(h); cells++; bits += c.bits.length; for (const r of c.refs) walk(r); };
    walk(root); return { cells, bits };
}

// gasUsed of the transaction whose inbound message hits `addr` (the offer's own handler).
// `which` picks among multiple such txs (default: the max-gas one).
function handlerGas(res: SendMessageResult, addr: Address, which: 'max' | number = 'max'): bigint {
    const rows = collectGas(res);
    const idxs: { i: number; gas: bigint }[] = [];
    res.transactions.forEach((t, i) => {
        const dest = (t as any).inMessage?.info?.dest;
        if (dest && dest.toString() === addr.toString()) idxs.push({ i, gas: rows[i].gasUsed });
    });
    if (idxs.length === 0) return 0n;
    if (which === 'max') return idxs.reduce((a, b) => (b.gas > a.gas ? b : a)).gas;
    return idxs[which]?.gas ?? 0n;
}

const DOMAIN_NAME = 'test12345678.ton';

describe('GasResearchOffers — measured compute gas + sizes for purchase offers', () => {
    let offerCode: Cell, jettonOfferCode: Cell, dnsCode: Cell, domainCode: Cell, jwCode: Cell, jmCode: Cell;
    beforeAll(async () => {
        offerCode = await compile('TonSimpleOffer');
        jettonOfferCode = await compile('JettonSimpleOffer');
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        jwCode = await compile('JettonWallet');
        jmCode = await compile('JettonMinter');
    });

    it('SIZE: TON & jetton offer code+data', async () => {
        const tonData = TonSimpleOffer.createFromConfig({
            domainAddress: new Address(0, Buffer.alloc(32)), price: toNano('100'), state: 1,
            commission: toNano('5'), createdAt: 1, validUntil: 2, buyerAddress: new Address(0, Buffer.alloc(32)),
            sellerAddress: new Address(0, Buffer.alloc(32)), domainName: 'examplelongdomainname.ton', sellerPrice: toNano('120'),
        } as TonSimpleOfferConfig, offerCode).init!.data;
        const jData = JettonSimpleOffer.createFromConfig({
            state: 1, price: toNano('100'), commission: toNano('5'), validUntil: 2,
            sellerAddress: new Address(0, Buffer.alloc(32)), jettonWalletAddress: new Address(0, Buffer.alloc(32)),
            sellerPrice: toNano('120'), createdAt: 1, domainAddress: new Address(0, Buffer.alloc(32)),
            buyerAddress: new Address(0, Buffer.alloc(32)), jettonMinterAddress: new Address(0, Buffer.alloc(32)),
            domainName: 'examplelongdomainname.ton',
        } as JettonSimpleOfferConfig, jettonOfferCode).init!.data;

        const tc = sizeOf(offerCode), td = sizeOf(tonData);
        const jc = sizeOf(jettonOfferCode), jd = sizeOf(jData);
        const tt = { cells: tc.cells + td.cells, bits: tc.bits + td.bits };
        const jt = { cells: jc.cells + jd.cells, bits: jc.bits + jd.bits };
        log(`\n>>> TON offer    CODE ${tc.cells}c/${tc.bits}b  DATA ${td.cells}c/${td.bits}b  TOTAL ${tt.cells}c/${tt.bits}b`);
        log(`>>> JETTON offer CODE ${jc.cells}c/${jc.bits}b  DATA ${jd.cells}c/${jd.bits}b  TOTAL ${jt.cells}c/${jt.bits}b`);
        const rent = (t: {cells:number,bits:number}, cp:number, bp:number, secs:number) => (t.cells*cp + t.bits*bp) * secs / 65536;
        for (const [name, t] of [['TON', tt], ['JETTON', jt]] as const) {
            log(`>>> ${name} storage: classic/yr=${(rent(t,500,1,ONE_YEAR)/1e9).toFixed(6)}  mainnet/yr=${(rent(t,135,0,ONE_YEAR)/1e9).toFixed(6)}  classic/30d=${(rent(t,500,1,ONE_DAY*30)/1e9).toFixed(6)}  mainnet/30d=${(rent(t,135,0,ONE_DAY*30)/1e9).toFixed(6)}`);
        }
        // Size-drift guard: these mirror OFFER_STORAGE_CELLS / OFFER_STORAGE_BITS in
        // contracts/purchase_offers/constants.tolk. If this fails, re-measure and bump them.
        expect(tt.cells).toBeLessThanOrEqual(80);
        expect(tt.bits).toBeLessThanOrEqual(48000);
        expect(jt.cells).toBeLessThanOrEqual(80);
        expect(jt.bits).toBeLessThanOrEqual(48000);
    });

    // ---------- TON offer flows ----------
    async function tonEnv(mainnet: boolean) {
        const bc = await Blockchain.create();
        if (mainnet) patchConfigToMainnet(bc);
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const buyer = await bc.treasury('buyer');
        const dns = bc.openContract(DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const r = await dns.sendStartAuction(admin.getSender(), DOMAIN_NAME);
        const dAddr = r.transactions[2].inMessage!.info.dest! as Address;
        const domain = bc.openContract(Domain.createFromAddress(dAddr));
        bc.now += 3601;
        await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
        const cfg: TonSimpleOfferConfig = {
            domainAddress: dAddr, price: toNano('2'), state: TonSimpleOffer.STATE_NOT_INITIALIZED, commission: toNano('0.2'),
            createdAt: bc.now, validUntil: bc.now + ONE_DAY * 3, buyerAddress: buyer.address, sellerAddress: seller.address,
            domainName: DOMAIN_NAME, sellerPrice: 0n,
        };
        const offer = bc.openContract(TonSimpleOffer.createFromConfig(cfg, offerCode));
        const deployRes = await offer.sendDeploy(admin.getSender(), cfg.price + cfg.commission + toNano('0.085'));
        return { bc, admin, seller, buyer, domain, offer, cfg, deployRes };
    }

    it('TON: per-handler gasUsed (classic + mainnet)', async () => {
        for (const mainnet of [false, true]) {
            const tag = mainnet ? 'mainnet' : 'classic';
            const e = await tonEnv(mainnet);
            log(`\n=== TON offer handler gasUsed [${tag}] ===`);
            log(`  deploy/FillUpBalance : ${handlerGas(e.deployRes, e.offer.address)}`);

            // accept via NFT empty payload
            let e1 = await tonEnv(mainnet);
            let res = await e1.domain.sendTransfer(e1.seller.getSender(), e1.offer.address, e1.seller.address, null, toNano('0.02'));
            log(`  accept (NFT empty)   : ${handlerGas(res, e1.offer.address)}`);

            // counterpropose via NFT payload (bargaining branch)
            let e2 = await tonEnv(mainnet);
            res = await e2.domain.sendTransfer(e2.seller.getSender(), e2.offer.address, e2.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), true), toNano('0.2'));
            log(`  NFT counterpropose   : ${handlerGas(res, e2.offer.address)}`);

            // ChangePrice (bargaining, no execute) with notify
            let e3 = await tonEnv(mainnet);
            res = await e3.offer.sendChangePrice(e3.buyer.getSender(), e3.cfg.price, e3.cfg.commission, toNano('3'), e3.bc.now! + ONE_DAY * 4, true);
            log(`  ChangePrice (notify) : ${handlerGas(res, e3.offer.address)}`);

            // ChangePrice that executes the offer (price >= sellerPrice after a counterproposal)
            let e4 = await tonEnv(mainnet);
            await e4.domain.sendTransfer(e4.seller.getSender(), e4.offer.address, e4.seller.address, TonSimpleOffer.counterProposePayload(toNano('2.1'), false), toNano('0.2'));
            let cfg4 = await e4.offer.getStorageData();
            res = await e4.offer.sendChangePrice(e4.buyer.getSender(), cfg4.price, cfg4.commission, toNano('2.1'), cfg4.validUntil, false, 0, true);
            log(`  ChangePrice (EXECUTE): ${handlerGas(res, e4.offer.address)}`);

            // CounterPropose message (bargaining) after first counterproposal
            let e5 = await tonEnv(mainnet);
            await e5.domain.sendTransfer(e5.seller.getSender(), e5.offer.address, e5.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
            res = await e5.offer.sendCounterpropose(e5.seller.getSender(), toNano('7'), true);
            log(`  CounterPropose msg   : ${handlerGas(res, e5.offer.address)}`);

            // ChangeValidUntil
            let e6 = await tonEnv(mainnet);
            res = await e6.offer.sendChangeValidUntil(e6.buyer.getSender(), e6.bc.now! + ONE_DAY * 10);
            log(`  ChangeValidUntil     : ${handlerGas(res, e6.offer.address)}`);

            // CancelDeal by buyer (after counterproposal so it returns the NFT)
            let e7 = await tonEnv(mainnet);
            await e7.domain.sendTransfer(e7.seller.getSender(), e7.offer.address, e7.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
            res = await e7.offer.sendCancelOffer(e7.buyer.getSender());
            log(`  Cancel buyer (+NFT)  : ${handlerGas(res, e7.offer.address)}`);

            // CancelDeal by seller (no counterproposal -> decline reward path)
            let e8 = await tonEnv(mainnet);
            res = await e8.offer.sendCancelOffer(e8.seller.getSender(), 'x');
            log(`  Cancel seller        : ${handlerGas(res, e8.offer.address)}`);

            // external cancel after expiry
            let e9 = await tonEnv(mainnet);
            e9.bc.now = e9.cfg.validUntil + 1;
            res = await e9.offer.sendExternalCancel();
            log(`  External cancel      : ${handlerGas(res, e9.offer.address)}`);
        }
    });

    // ---------- Jetton offer flows ----------
    async function jettonEnv(mainnet: boolean) {
        const bc = await Blockchain.create();
        if (mainnet) patchConfigToMainnet(bc);
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const buyer = await bc.treasury('buyer');
        const usdtMinter = bc.openContract(JettonMinter.createFromConfig({ admin: admin.address, content: beginCell().storeStringTail('usdt').endCell(), wallet_code: jwCode }, jmCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano('0.05'));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano('0.2'), toNano('0.5'));
        const buyerWallet = bc.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));
        const dns = bc.openContract(DnsCollection.createFromConfig({ content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const r = await dns.sendStartAuction(admin.getSender(), DOMAIN_NAME);
        const dAddr = r.transactions[2].inMessage!.info.dest! as Address;
        const domain = bc.openContract(Domain.createFromAddress(dAddr));
        bc.now += 3601;
        await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
        const cfg: JettonSimpleOfferConfig = {
            domainAddress: dAddr, price: toNano('2'), state: JettonSimpleOffer.STATE_NOT_INITIALIZED, commission: toNano('0.2'),
            createdAt: bc.now, validUntil: bc.now + ONE_DAY * 3, buyerAddress: buyer.address, sellerAddress: seller.address,
            sellerPrice: 0n, domainName: DOMAIN_NAME, jettonWalletAddress: null, jettonMinterAddress: usdtMinter.address,
        };
        const offer = bc.openContract(JettonSimpleOffer.createFromConfig(cfg, jettonOfferCode));
        const offerWalletAddr = await usdtMinter.getWalletAddress(offer.address);
        const deployRes = await offer.sendDeploy(admin.getSender(), toNano('0.17'), beginCell().storeAddress(offerWalletAddr).endCell());
        const c2 = await offer.getStorageData();
        await buyerWallet.sendTransfer(buyer.getSender(), c2.price + c2.commission, offer.address, buyer.address, 0n);
        return { bc, admin, seller, buyer, domain, offer, buyerWallet, cfg, deployRes };
    }

    it('JETTON: per-handler gasUsed (classic + mainnet)', async () => {
        for (const mainnet of [false, true]) {
            const tag = mainnet ? 'mainnet' : 'classic';
            const e = await jettonEnv(mainnet);
            log(`\n=== JETTON offer handler gasUsed [${tag}] ===`);
            log(`  deploy/SetWallet     : ${handlerGas(e.deployRes, e.offer.address)}`);

            let e1 = await jettonEnv(mainnet);
            let res = await e1.domain.sendTransfer(e1.seller.getSender(), e1.offer.address, e1.seller.address, null, toNano('0.02'));
            log(`  accept (NFT empty)   : ${handlerGas(res, e1.offer.address)}`);

            let e2 = await jettonEnv(mainnet);
            res = await e2.domain.sendTransfer(e2.seller.getSender(), e2.offer.address, e2.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), true), toNano('0.2'));
            log(`  NFT counterpropose   : ${handlerGas(res, e2.offer.address)}`);

            // change price via jetton transfer (bargaining branch), with notify
            let e3 = await jettonEnv(mainnet);
            let c3 = await e3.offer.getStorageData();
            res = await e3.buyerWallet.sendTransfer(e3.buyer.getSender(), c3.price + c3.commission, e3.offer.address, e3.buyer.address, toNano('0.125'), JettonSimpleOffer.changePricePayload(e3.bc.now! + ONE_DAY * 4, true));
            log(`  JettonChangePrice    : ${handlerGas(res, e3.offer.address)}`);

            // CounterPropose msg (bargaining)
            let e5 = await jettonEnv(mainnet);
            await e5.domain.sendTransfer(e5.seller.getSender(), e5.offer.address, e5.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
            res = await e5.offer.sendCounterpropose(e5.seller.getSender(), toNano('7'), true);
            log(`  CounterPropose msg   : ${handlerGas(res, e5.offer.address)}`);

            let e6 = await jettonEnv(mainnet);
            res = await e6.offer.sendChangeValidUntil(e6.buyer.getSender(), e6.bc.now! + ONE_DAY * 10);
            log(`  ChangeValidUntil     : ${handlerGas(res, e6.offer.address)}`);

            let e7 = await jettonEnv(mainnet);
            await e7.domain.sendTransfer(e7.seller.getSender(), e7.offer.address, e7.seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
            res = await e7.offer.sendCancelOffer(e7.buyer.getSender());
            log(`  Cancel buyer (+NFT)  : ${handlerGas(res, e7.offer.address)}`);

            let e8 = await jettonEnv(mainnet);
            res = await e8.offer.sendCancelOffer(e8.seller.getSender(), 'x');
            log(`  Cancel seller        : ${handlerGas(res, e8.offer.address)}`);

            let e9 = await jettonEnv(mainnet);
            e9.bc.now = e9.cfg.validUntil + 1;
            res = await e9.offer.sendExternalCancel();
            log(`  External cancel      : ${handlerGas(res, e9.offer.address)}`);
        }
    });
});

import { Blockchain, internal } from '@ton/sandbox';
import { Address, beginCell, Cell, contractAddress, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { JettonSimpleSale, JettonSimpleSaleConfig } from '../../wrappers/JettonSimpleSale';
import { JettonMinter } from '../../wrappers/JettonMinter';
import { JettonWallet } from '../../wrappers/JettonWallet';
import { MIN_PRICE_START_TIME, ONE_DAY } from '../../wrappers/helpers/constants';
import { log } from '../helpers/gas';

// Measure the JETTON SIMPLE sale's purchase handler COMPUTE (the JettonsTransferNotification path) to
// size GAS_JETTON_SIMPLE_PURCHASE — the simple sale was previously (wrongly) borrowing the TON sale's
// GAS_TON_SIMPLE_PURCHASE. The jetton path is heavier: it parses the (optional dedust) forward payload
// and emits up to THREE jetton sends (excess-return + marketplace commission + seller payout) plus the
// domain transfer, where the TON sale emits one TON payout + the domain transfer.
describe('JettonSimplePurchaseGas', () => {
    let dnsCode: Cell, domainCode: Cell, saleCode: Cell, minterCode: Cell, walletCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('JettonSimpleSale');
        minterCode = await compile('JettonMinter');
        walletCode = await compile('JettonWallet');
    });

    const PRICE = toNano('2');
    const COMMISSION = toNano('0.2');

    // Build an ACTIVE jetton simple sale holding one domain; return the buyer's jetton wallet + sale.
    async function buildActiveSale(tag: string) {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');
        const seller = await bc.treasury('seller');
        const buyer = await bc.treasury('buyer');

        const minter = bc.openContract(JettonMinter.createFromConfig(
            { admin: admin.address, content: beginCell().storeStringTail('usdt').endCell(), wallet_code: walletCode },
            minterCode));
        await minter.sendDeploy(admin.getSender(), toNano('0.05'));
        await minter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano('0.2'), toNano('0.5'));
        const buyerWallet = bc.openContract(JettonWallet.createFromAddress(await minter.getWalletAddress(buyer.address)));

        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));

        const domainName = `jsp${tag}99.ton`;
        const r = await dns.sendStartAuction(admin.getSender(), domainName);
        const domainAddr = r.transactions[2].inMessage!.info.dest! as Address;
        const domain = bc.openContract(Domain.createFromAddress(domainAddr));
        bc.now += 3601;
        await domain.sendTransfer(admin.getSender(), seller.address, seller.address);

        const cfg: JettonSimpleSaleConfig = {
            domainAddress: domainAddr,
            sellerAddress: seller.address,
            jettonMinterAddress: minter.address,
            price: PRICE, state: JettonSimpleSale.STATE_UNINIT, commission: COMMISSION,
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 3,
            buyerAddress: null, domainName, autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(JettonSimpleSale.createFromConfig(cfg, saleCode));
        const saleWallet = bc.openContract(JettonWallet.createFromAddress(await minter.getWalletAddress(sale.address)));
        await sale.sendDeploy(admin.getSender(), toNano('0.05'), beginCell().storeAddress(saleWallet.address).endCell());
        await domain.sendTransfer(seller.getSender(), sale.address, seller.address);
        return { bc, sale, buyer, buyerWallet };
    }

    // gasUsed of the single internal tx whose inbound message hits the sale (the transfer notification).
    function saleTxGas(res: any, saleAddr: Address): bigint {
        for (const t of res.transactions as any[]) {
            if (t.inMessage?.info?.dest?.toString?.() === saleAddr.toString()
                && t.inMessage?.info?.type === 'internal') {
                return (t.description as any)?.computePhase?.gasUsed ?? 0n;
            }
        }
        return 0n;
    }

    // excess>0 exercises the heaviest branch: the dedust forward-payload parse + the THIRD jetton
    // message (return-excess-to-buyer) on top of commission + seller payout + domain transfer.
    async function purchaseGas(tag: string, excess: boolean, dedust: boolean): Promise<{ gas: bigint; ok: boolean }> {
        const { sale, buyer, buyerWallet } = await buildActiveSale(tag);
        const jettons = excess ? PRICE + toNano('0.5') : PRICE;
        // dedust path: a 267-bit address payload makes the handler re-parse the real sender.
        const payload = dedust ? beginCell().storeAddress(buyer.address).endCell() : undefined;
        const res = await buyerWallet.sendTransfer(buyer.getSender(), jettons, sale.address, buyer.address, toNano('0.3'), payload);
        const ok = (res.transactions as any[]).some(t =>
            t.inMessage?.info?.dest?.toString?.() === sale.address.toString()
            && t.inMessage?.info?.type === 'internal'
            && (t.description as any)?.computePhase?.success === true
            && (t.description as any)?.computePhase?.exitCode === 0);
        return { gas: saleTxGas(res, sale.address), ok };
    }

    it('jetton simple purchase compute (normal + dedust/excess worst case)', async () => {
        const normal = await purchaseGas('n', false, false);
        expect(normal.ok).toBe(true);
        const worst = await purchaseGas('w', true, true);
        expect(worst.ok).toBe(true);

        log(`\n>>> jetton SIMPLE sale purchase compute:`);
        log(`>>>   normal path (exact price)          | ${String(Number(normal.gas)).padStart(6)} gas`);
        log(`>>>   dedust/excess path (worst case)     | ${String(Number(worst.gas)).padStart(6)} gas`);
        log(`>>>   -> drives GAS_JETTON_SIMPLE_PURCHASE`);

        // Sandbox runs CLASSIC prices (~6x pessimistic vs live mainnet), so any constant clearing the
        // measured worst case here has a large live-mainnet margin. Assert the chosen budget covers it.
        const GAS_JETTON_SIMPLE_PURCHASE = 25000;
        expect(GAS_JETTON_SIMPLE_PURCHASE).toBeGreaterThanOrEqual(Number(worst.gas));

        // Compute the EXACT jettonSimplePurchaseFee() at classic prices from the GasProbe primitives,
        // so the wrapper's JettonSimpleSale.PURCHASE and the unit-test buyer amounts can be set above it.
        const probeCode = await compile('GasProbe');
        const bc = await Blockchain.create();
        const init = { code: probeCode, data: beginCell().endCell() };
        const addr = contractAddress(0, init);
        const provider = bc.provider(addr, init);
        const t = await bc.treasury('t');
        await bc.sendMessage(internal({ from: t.address, to: addr, value: toNano('1'), bounce: false, stateInit: init, body: beginCell().endCell() }));
        const get = async (m: string, args: any[] = []) => (await provider.get(m, args.map(v => ({ type: 'int', value: BigInt(v) })) as any)).stack.readBigNumber();
        const domainRefill = await get('domain_refill_fee');
        const gas25k = await get('gas', [GAS_JETTON_SIMPLE_PURCHASE]);
        // jettonSimplePurchaseFee = domainRefillFee + TONS_PURCHASE_NOTIFICATION + gasFee(25000) + 3*TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE
        const fee = domainRefill + toNano('0.03') + gas25k + 3n * toNano('0.05') + toNano('0.01');
        log(`>>>   jettonSimplePurchaseFee classic = ${Number(fee) / 1e9} TON  (domainRefill ${Number(domainRefill) / 1e9} + gas25k ${Number(gas25k) / 1e9} + 0.19 fixed)`);
    }, 120000);
});

import { Blockchain } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain } from '../../wrappers/Domain';
import { TonSimpleSale, TonSimpleSaleConfig } from '../../wrappers/TonSimpleSale';
import { MIN_PRICE_START_TIME, ONE_DAY } from '../../wrappers/helpers/constants';
import { txGas, log } from '../helpers/gas';

// Measure the sale's ACTIVATION compute (the deploy/FillUpBalance handler that flips STATE_UNINIT ->
// STATE_ACTIVE) so the deploy funding can use gasFee(measured) instead of a flat ton("0.005") pad.
describe('DeployGas', () => {
    let dnsCode: Cell, domainCode: Cell, saleCode: Cell;
    beforeAll(async () => {
        dnsCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        saleCode = await compile('TonSimpleSale');
    });

    it('measures TON simple sale activation compute', async () => {
        const bc = await Blockchain.create();
        bc.now = MIN_PRICE_START_TIME;
        const admin = await bc.treasury('admin');   // == marketplace (substituted MARKETPLACE_ADDRESS)
        const seller = await bc.treasury('seller');
        const dns = bc.openContract(DnsCollection.createFromConfig(
            { content: beginCell().endCell(), nftItemCode: domainCode } as DnsCollectionConfig, dnsCode));
        await dns.sendDeploy(admin.getSender(), toNano('0.05'));
        const r = await dns.sendStartAuction(admin.getSender(), 'deploygastest99.ton');
        const dAddr = r.transactions[2].inMessage!.info.dest! as Address;
        const domain = bc.openContract(Domain.createFromAddress(dAddr));
        bc.now += 3601;
        await domain.sendTransfer(admin.getSender(), seller.address, seller.address);

        const cfg: TonSimpleSaleConfig = {
            domainAddress: dAddr, sellerAddress: seller.address, price: toNano('2'),
            state: TonSimpleSale.STATE_UNINIT, commission: toNano('0.2'),
            createdAt: bc.now!, lastRenewalTime: bc.now!, validUntil: bc.now! + ONE_DAY * 3,
            buyerAddress: null, domainName: 'deploygastest99.ton', autoRenewCooldown: ONE_DAY * 30, autoRenewIterations: 0,
        };
        const sale = bc.openContract(TonSimpleSale.createFromConfig(cfg, saleCode));
        const res = await sale.sendDeploy(admin.getSender(), toNano('0.05'));

        const txs = res.transactions as any[];
        let gasUsed = 0n;
        for (let i = 0; i < txs.length; i++) {
            if (txs[i].inMessage?.info?.dest?.toString?.() === sale.address.toString()) {
                gasUsed = txGas(txs[i], i).gasUsed; break;
            }
        }
        log(`\n>>> TON simple sale activation compute: ${gasUsed} gas`);
        log(`>>>   old pad ton("0.005") = 12500 gas-equivalent @classic; suggested DEPLOY_GAS w/ ~2x margin: ${Math.ceil(Number(gasUsed) * 2 / 1000) * 1000}`);
        expect(Number(gasUsed)).toBeGreaterThan(0);
        expect(Number(gasUsed)).toBeLessThanOrEqual(10000); // sanity: activation is cheap
    });
});

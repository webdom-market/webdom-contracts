import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { TonSimpleSale, TonSimpleSaleConfig } from '../../wrappers/TonSimpleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../../wrappers/Domain';
import { getIndexByDomainName } from '../../wrappers/helpers/dnsUtils';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { jettonsToString } from '../../wrappers/helpers/functions';

describe('TonSimpleSale', () => {
    let fixPriceSaleCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        fixPriceSaleCode = await compile('TonSimpleSale');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let tonSimpleSale: SandboxContract<TonSimpleSale>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let tonSimpleSaleConfig: TonSimpleSaleConfig;
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;

        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');
        
        dnsCollection = blockchain.openContract(DnsCollection.createFromConfig({
            content: beginCell().endCell(),
            nftItemCode: domainCode,
        } as DnsCollectionConfig, dnsCollectionCode));

        transactionRes = await dnsCollection.sendDeploy(admin.getSender(), toNano('0.05'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: dnsCollection.address,
            deploy: true,
            success: true,
        });

        transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), DOMAIN_NAME);
        const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
        expect(transactionRes.transactions).toHaveTransaction({
            from: dnsCollection.address,
            to: domainAddress,
            deploy: true,
            success: true
        })
        domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
        
        blockchain.now += 60 * 60 + 1;  // end of the auction
        transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);

        tonSimpleSaleConfig = {
            domainAddress,
            sellerAddress: seller.address,
            price: toNano('2'),
            state: TonSimpleSale.STATE_UNINIT,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            lastRenewalTime: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: null,
            domainName: DOMAIN_NAME,
            autoRenewCooldown: ONE_DAY * 30,
            autoRenewIterations: 0,
        }
        tonSimpleSale = blockchain.openContract(TonSimpleSale.createFromConfig(tonSimpleSaleConfig, fixPriceSaleCode));
        transactionRes = await tonSimpleSale.sendDeploy(admin.getSender(), toNano('0.05'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tonSimpleSale.address,
            deploy: true,
            success: true
        })

        transactionRes = await domain.sendTransfer(seller.getSender(), tonSimpleSale.address, null, null, 0n, 0, toNano('0.015'));
        let domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress?.toString()).toEqual(tonSimpleSale.address.toString());
    });

    it('should sell domain', async () => {
        // reject if valid_until < now
        blockchain.now! = tonSimpleSaleConfig.validUntil + 1;
        transactionRes = await tonSimpleSale.sendPurchase(buyer.getSender(), tonSimpleSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })

        // accept 
        await tonSimpleSale.sendChangePrice(seller.getSender(), tonSimpleSaleConfig.price, blockchain.now! + 600);
        transactionRes = await tonSimpleSale.sendPurchase(buyer.getSender(), tonSimpleSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleSale.address,
            to: seller.address,
            value(x) { return x! >= tonSimpleSaleConfig.price - tonSimpleSaleConfig.commission },
            success: true
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleSale.address,
            to: marketplace.address,
            value(x) { return (x! > tonSimpleSaleConfig.commission - toNano('0.001')) },
            success: true
        })

        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.buyerAddress!.toString()).toEqual(buyer.address.toString());

        // reject if already sold
        transactionRes = await tonSimpleSale.sendPurchase(buyer.getSender(), tonSimpleSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })
    });

    it("should handle dedust swap", async () => {
        transactionRes = await buyer.send({
            to: tonSimpleSale.address,
            value: tonSimpleSaleConfig.price + toNano('0.2'),
            body: beginCell().storeUint(OpCodes.DEDUST_PAYOUT, 32).storeUint(0, 64).storeAddress(buyer.address).endCell()
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleSale.address,
        })
    })

    it('should change price', async () => {
        let checks = 100;
        for (let i = 0; i < 100; ++i) {
            let newPrice = BigInt(Math.ceil(Math.random() * 10 ** (i % 9 + 9)));
            let timeSpent = Math.ceil(ONE_DAY * Math.random() * 700 / checks);  
            blockchain.now! += timeSpent;
            let newValidUntil = Math.ceil(blockchain.now! + ONE_DAY * Math.random() * 700 / checks);
            transactionRes = await tonSimpleSale.sendChangePrice(seller.getSender(), newPrice, newValidUntil);
            if (tonSimpleSaleConfig.lastRenewalTime + ONE_YEAR - ONE_DAY < newValidUntil || newValidUntil < Math.max(blockchain.now! + 600, tonSimpleSaleConfig.validUntil)) {
                expect(transactionRes.transactions).toHaveTransaction({
                    from: seller.address,
                    to: tonSimpleSale.address,
                    exitCode: Exceptions.INCORRECT_VALID_UNTIL
                })
            }
            else {
                tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
                expect(tonSimpleSaleConfig.price).toEqual(newPrice);
                expect(tonSimpleSaleConfig.validUntil).toEqual(newValidUntil);
                
                let notificationMessage = transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail();
                let priceString = notificationMessage.split(' ')[3];
                let expectedPriceString = jettonsToString(Number(newPrice), 9);
                expect(priceString).toEqual(expectedPriceString);
            }
        }
    });

    it("should cap validUntil at the domain lifetime for .ton domains", async () => {
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        const maxValidUntil = tonSimpleSaleConfig.lastRenewalTime
            + tonSimpleSaleConfig.autoRenewCooldown! * tonSimpleSaleConfig.autoRenewIterations!
            + ONE_YEAR - ONE_DAY;

        // setting exactly the cap succeeds
        transactionRes = await tonSimpleSale.sendChangePrice(seller.getSender(), tonSimpleSaleConfig.price, maxValidUntil);
        expect(transactionRes.transactions).not.toHaveTransaction({
            from: seller.address,
            to: tonSimpleSale.address,
            exitCode: Exceptions.INCORRECT_VALID_UNTIL
        });
        expect((await tonSimpleSale.getStorageData()).validUntil).toEqual(maxValidUntil);

        // setting one second beyond the cap is rejected
        transactionRes = await tonSimpleSale.sendChangePrice(seller.getSender(), tonSimpleSaleConfig.price, maxValidUntil + 1);
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: tonSimpleSale.address,
            exitCode: Exceptions.INCORRECT_VALID_UNTIL
        });
    });

    it("should renew domain", async () => {
        blockchain.now! += ONE_DAY * 30;
        transactionRes = await tonSimpleSale.sendRenewDomain(seller.getSender());
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!);
        
        blockchain.now! += ONE_YEAR - ONE_DAY + 1;
        transactionRes = await tonSimpleSale.sendRenewDomain(seller.getSender());
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!);
    });

    it("should cancel by external message", async () => {
        blockchain.now! += ONE_YEAR;
        transactionRes = await tonSimpleSale.sendExternalCancel();
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(tonSimpleSaleConfig.sellerAddress.toString());
    });

    it('should handle domain expiration', async () => {
        blockchain.now! += ONE_YEAR + ONE_DAY;
        transactionRes = await domain.sendStartAuction(buyer.getSender(), DOMAIN_NAME);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleSale.address,
            to: seller.address,
        })
        let saleConfig = await tonSimpleSale.getStorageData();
        expect(saleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
    })

    it("should reject purchase when domain is expired by renewal time", async () => {
        // Prepay auto-renew so validUntil may legitimately extend past the domain's renewal-time expiry
        // (under the cap an iterations=0 sale's validUntil ends exactly at that boundary, so the only way
        // to reach the DOMAIN_EXPIRED guard with validUntil still in the future is via prepaid iterations).
        await tonSimpleSale.sendSetAutoRenewParams(seller.getSender(), ONE_DAY * 30, 2);
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        // Past the renewal-time expiry (lastRenewal + ONE_YEAR - ONE_DAY) but still within validUntil
        blockchain.now! = tonSimpleSaleConfig.lastRenewalTime + ONE_YEAR;
        expect(tonSimpleSaleConfig.validUntil).toBeGreaterThan(blockchain.now!);
        transactionRes = await tonSimpleSale.sendPurchase(buyer.getSender(), tonSimpleSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        });
    });


    it("should top up auto-renew and execute external auto-renew", async () => {
        transactionRes = await tonSimpleSale.sendSetAutoRenewParams(seller.getSender(), ONE_DAY, 2);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleSale.address,
            to: marketplace.address,
            op: OpCodes.AUTORENEW_PREPAY,
            value(x) { return x! >= Tons.AUTORENEW_MARKETPLACE_FEE * 2n },
        });

        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.autoRenewIterations).toEqual(2);

        blockchain.now! += ONE_DAY;
        transactionRes = await tonSimpleSale.sendExternalTriggerAutoRenew();
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.autoRenewIterations).toEqual(1);
        expect(tonSimpleSaleConfig.lastRenewalTime).toEqual(blockchain.now!);

        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!);
    });

    it("should cancel by internal message", async () => {
        blockchain.now! = tonSimpleSaleConfig.validUntil;
        // console.log((await blockchain.getContract(tonFixPriceSale.address)).balance);
        transactionRes = await tonSimpleSale.sendCancelSale(seller.getSender());
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(tonSimpleSaleConfig.sellerAddress.toString());
    });
    
    it("should make hot", async () => {
        transactionRes = await tonSimpleSale.sendMakeHot(admin.getSender(), blockchain.now! + ONE_DAY * 3 / 2);
        transactionRes = await tonSimpleSale.sendMakeColored(admin.getSender(), blockchain.now! + ONE_DAY * 2);
        tonSimpleSaleConfig = await tonSimpleSale.getStorageData();
        expect(tonSimpleSaleConfig.hotUntil).toEqual(blockchain.now! + ONE_DAY * 3 / 2);
        expect(tonSimpleSaleConfig.coloredUntil).toEqual(blockchain.now! + ONE_DAY * 2);
    });
});

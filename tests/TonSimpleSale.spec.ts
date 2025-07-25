import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { TonSimpleSale, TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { getIndexByDomainName } from '../wrappers/helpers/dnsUtils';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';

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

    let tonFixPriceSale: SandboxContract<TonSimpleSale>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let tonFixPriceSaleConfig: TonSimpleSaleConfig;
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
        const domainAddress = transactionRes.transactions[2].inMessage!!.info.dest!! as Address; 
        expect(transactionRes.transactions).toHaveTransaction({
            from: dnsCollection.address,
            to: domainAddress,
            deploy: true,
            success: true
        })
        domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
        
        blockchain.now += 60 * 60 + 1;  // end of the auction
        transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);

        tonFixPriceSaleConfig = {
            domainAddress,
            sellerAddress: seller.address,
            price: toNano('2'),
            state: TonSimpleSale.STATE_UNINIT,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            lastRenewalTime: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: null,
            domainName: DOMAIN_NAME
        }
        tonFixPriceSale = blockchain.openContract(TonSimpleSale.createFromConfig(tonFixPriceSaleConfig, fixPriceSaleCode));
        transactionRes = await tonFixPriceSale.sendDeploy(admin.getSender(), toNano('0.05'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tonFixPriceSale.address,
            deploy: true,
            success: true
        })

        transactionRes = await domain.sendTransfer(seller.getSender(), tonFixPriceSale.address, null, null, 0n, 0, toNano('0.015'));
        let domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress?.toString()).toEqual(tonFixPriceSale.address.toString());
    });

    it('should sell domain', async () => {
        // reject if valid_until < now
        blockchain.now!! = tonFixPriceSaleConfig.validUntil + 1;
        transactionRes = await tonFixPriceSale.sendPurchase(buyer.getSender(), tonFixPriceSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonFixPriceSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        })

        // accept 
        await tonFixPriceSale.sendChangePrice(seller.getSender(), tonFixPriceSaleConfig.price, blockchain.now!! + 600);
        transactionRes = await tonFixPriceSale.sendPurchase(buyer.getSender(), tonFixPriceSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonFixPriceSale.address,
            to: seller.address,
            value(x) { return x!! >= tonFixPriceSaleConfig.price - tonFixPriceSaleConfig.commission },
            success: true
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonFixPriceSale.address,
            to: marketplace.address,
            value(x) { return (x!! > tonFixPriceSaleConfig.commission - toNano('0.001')) },
            success: true
        })

        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());


        // reject if already sold
        transactionRes = await tonFixPriceSale.sendPurchase(buyer.getSender(), tonFixPriceSaleConfig.price);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonFixPriceSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })
    });


    it('should change price', async () => {
        let checks = 100;
        for (let i = 0; i < 100; ++i) {
            let newPrice = BigInt(Math.ceil(Math.random() * 10 ** (i % 9 + 9)));
            let timeSpent = Math.ceil(ONE_DAY * Math.random() * 700 / checks);  
            blockchain.now!! += timeSpent;
            let newValidUntil = Math.ceil(blockchain.now!! + ONE_DAY * Math.random() * 700 / checks);
            transactionRes = await tonFixPriceSale.sendChangePrice(seller.getSender(), newPrice, newValidUntil);
            if (tonFixPriceSaleConfig.lastRenewalTime + ONE_YEAR - ONE_DAY < newValidUntil || newValidUntil < Math.max(blockchain.now!! + 600, tonFixPriceSaleConfig.validUntil)) {
                expect(transactionRes.transactions).toHaveTransaction({
                    from: seller.address,
                    to: tonFixPriceSale.address,
                    // success: false,
                    exitCode: Exceptions.INCORRECT_VALID_UNTIL
                })
                if (newValidUntil >= Math.max(blockchain.now!! + 600, tonFixPriceSaleConfig.lastRenewalTime)) break;
            }
            else {
                tonFixPriceSaleConfig = await tonFixPriceSale.getStorageData();
                expect(tonFixPriceSaleConfig.price).toEqual(newPrice);
                expect(tonFixPriceSaleConfig.validUntil).toEqual(newValidUntil);
                
                let notificationMessage = transactionRes.transactions[2].inMessage!!.body.beginParse().skip(32).loadStringTail();
                let priceString = notificationMessage.split(' ')[3];
                let expectedPriceString = jettonsToString(Number(newPrice), 9);
                expect(priceString).toEqual(expectedPriceString);
            }
        }
    });

    it("should renew domain", async () => {
        blockchain.now!! += ONE_DAY * 30;
        transactionRes = await tonFixPriceSale.sendRenewDomain(seller.getSender());
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!!);
        
        blockchain.now!! += ONE_YEAR - ONE_DAY + 1;
        transactionRes = await tonFixPriceSale.sendRenewDomain(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: tonFixPriceSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        });
    });

    it("should cancel by external message", async () => {
        blockchain.now!! += ONE_YEAR;
        // console.log((await blockchain.getContract(tonFixPriceSale.address)).balance);
        transactionRes = await tonFixPriceSale.sendExternalCancel();
        printTransactionFees(transactionRes.transactions);
        tonFixPriceSaleConfig = await tonFixPriceSale.getStorageData();
        expect(tonFixPriceSaleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(tonFixPriceSaleConfig.sellerAddress.toString());
    });

    it('should handle domain expiration', async () => {
        blockchain.now!! += ONE_YEAR + ONE_DAY;
        transactionRes = await domain.sendStartAuction(buyer.getSender(), DOMAIN_NAME);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonFixPriceSale.address,
            to: seller.address,
        })
        let saleConfig = await tonFixPriceSale.getStorageData();
        expect(saleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
    })


    it("should cancel by internal message", async () => {
        blockchain.now!! = tonFixPriceSaleConfig.validUntil;
        // console.log((await blockchain.getContract(tonFixPriceSale.address)).balance);
        transactionRes = await tonFixPriceSale.sendCancelSale(seller.getSender());
        tonFixPriceSaleConfig = await tonFixPriceSale.getStorageData();
        expect(tonFixPriceSaleConfig.state).toEqual(TonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(tonFixPriceSaleConfig.sellerAddress.toString());
    });
    
    it("should make hot", async () => {
        transactionRes = await tonFixPriceSale.sendMakeHot(admin.getSender(), blockchain.now!! + ONE_DAY * 3 / 2);
        transactionRes = await tonFixPriceSale.sendMakeColored(admin.getSender(), blockchain.now!! + ONE_DAY * 2);
        tonFixPriceSaleConfig = await tonFixPriceSale.getStorageData();
        expect(tonFixPriceSaleConfig.hotUntil).toEqual(blockchain.now!! + ONE_DAY * 3 / 2);
        expect(tonFixPriceSaleConfig.coloredUntil).toEqual(blockchain.now!! + ONE_DAY * 2);
    });
});

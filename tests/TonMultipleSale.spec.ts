import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { TonMultipleSale, TonMultipleSaleConfig } from '../wrappers/TonMultipleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';


describe('MultipleTonSale', () => {
    let tonMultipleSaleCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        tonMultipleSaleCode = await compile('TonMultipleSale');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let tonMultipleSale: SandboxContract<TonMultipleSale>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton"];
    let domainConfigs: Array<DomainConfig>;
    let transactionRes: SendMessageResult;

    let tonMultipleSaleConfig: TonMultipleSaleConfig;
    let tmp = 0;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        domains = [];
        domainConfigs = [];

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

        let domainsDict: Dictionary<Address, number> = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        for (let domainName of DOMAIN_NAMES) {  // deploy domains
            transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), domainName);
            const domainAddress = transactionRes.transactions[2].inMessage!!.info.dest!! as Address; 
            expect(transactionRes.transactions).toHaveTransaction({
                from: dnsCollection.address,
                to: domainAddress,
                deploy: true,
                success: true
            })
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            blockchain.now += 60 * 60 + 1;  // end of the auction
            transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
            
            domains.push(domain);
            domainsDict.set(domainAddress, 0);
        }

        tonMultipleSaleConfig = {
            sellerAddress: seller.address,
            domainsDict: domainsDict,
            domainsTotal: domains.length,
            domainsReceived: 0,
            price: toNano('2'),
            state: TonMultipleSale.STATE_UNINIT,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            lastRenewalTime: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: null,
            tonsToReserve: domains.length,
        }
        tonMultipleSale = blockchain.openContract(TonMultipleSale.createFromConfig(tonMultipleSaleConfig, tonMultipleSaleCode));
        transactionRes = await tonMultipleSale.sendDeploy(admin.getSender(), toNano('0.04'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tonMultipleSale.address,
            deploy: true,
            success: true
        })

        for (let domain of domains) {
            transactionRes = await domain.sendTransfer(seller.getSender(), tonMultipleSale.address, null, null, toNano('0.1'));
            domainConfigs.push(await domain.getStorageData());
        }
        // printTransactionFees(transactionRes.transactions);

        expect(transactionRes.transactions).toHaveTransaction({
            from: tonMultipleSale.address,
            to: seller.address,
            body: beginCell().storeUint(0, 32).storeStringTail("Multiple sale on webdom.market is active").endCell(),
            // value(x) {
            //     return x!! >= toNano('0.09') * BigInt(domains.length)
            // },
        })

        tonMultipleSaleConfig = await tonMultipleSale.getStorageData();
        expect(tonMultipleSaleConfig.domainsReceived).toEqual(domains.length);
        for (let domain of domains) {
            expect(tonMultipleSaleConfig.domainsDict.get(domain.address)).toEqual(1);
        }
    });

    // it('should deploy', async () => {

    // });

    it('should sell domains', async () => {
        // reject if valid_until < now
        blockchain.now!! = tonMultipleSaleConfig.validUntil + 1;
        transactionRes = await tonMultipleSale.sendPurchase(buyer.getSender(), tonMultipleSaleConfig.price, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })

        // accept 
        transactionRes = await tonMultipleSale.sendChangePrice(seller.getSender(), tonMultipleSaleConfig.price, blockchain.now!! + 600);
        transactionRes = await tonMultipleSale.sendPurchase(buyer.getSender(), tonMultipleSaleConfig.price, domains.length);
        
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonMultipleSale.address,
            to: seller.address,
            value(x) {
                return x!! > tonMultipleSaleConfig.price - tonMultipleSaleConfig.commission - toNano('0.01');
            },
            success: true
        });

        expect(transactionRes.transactions).toHaveTransaction({
            from: tonMultipleSale.address,
            to: marketplace.address,
            value(x) { return (x!! > tonMultipleSaleConfig.commission - toNano('0.001')) },
            success: true
        });

        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        }


        // // reject if already sold
        transactionRes = await tonMultipleSale.sendPurchase(buyer.getSender(), tonMultipleSaleConfig.price, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleSale.address,
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
            transactionRes = await tonMultipleSale.sendChangePrice(seller.getSender(), newPrice, newValidUntil);
            if (tonMultipleSaleConfig.lastRenewalTime + ONE_YEAR - ONE_DAY < newValidUntil || newValidUntil < Math.max(blockchain.now!! + 600, tonMultipleSaleConfig.validUntil)) {
                expect(transactionRes.transactions).toHaveTransaction({
                    from: seller.address,
                    to: tonMultipleSale.address,
                    // success: false,
                    exitCode: Exceptions.INCORRECT_VALID_UNTIL
                })
                if (newValidUntil >= Math.max(blockchain.now!! + 600, tonMultipleSaleConfig.lastRenewalTime)) break;
            }
            else {
                tonMultipleSaleConfig = await tonMultipleSale.getStorageData();
                expect(tonMultipleSaleConfig.price).toEqual(newPrice);
                expect(tonMultipleSaleConfig.validUntil).toEqual(newValidUntil);
                
                let notificationMessage = transactionRes.transactions[2].inMessage!!.body.beginParse().skip(32).loadStringTail();
                let priceString = notificationMessage.split(' ')[3];
                let expectedPriceString = jettonsToString(Number(newPrice), 9);
                expect(priceString).toEqual(expectedPriceString);
            }
        }
    });

    it("should renew domain", async () => {
        blockchain.now!! += ONE_DAY * 30;
        transactionRes = await tonMultipleSale.sendRenewDomain(seller.getSender(), tonMultipleSaleConfig.domainsTotal);
        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!!);
        }
        
        blockchain.now!! += ONE_YEAR - ONE_DAY + 1;
        transactionRes = await tonMultipleSale.sendRenewDomain(seller.getSender(), tonMultipleSaleConfig.domainsTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: tonMultipleSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        });
    });

    it("should handle expiration notification", async () => {
        blockchain.now!! += ONE_YEAR + 1;
        transactionRes = await domains[0].sendStartAuction(admin.getSender(), DOMAIN_NAMES[0]);
        for (let i = 1; i < domains.length; ++i) {
            let domainConfig = await domains[i].getStorageData();
            expect(domainConfig.ownerAddress!!.toString()).toEqual(tonMultipleSaleConfig.sellerAddress.toString());
        }
        expect((await blockchain.getContract(tonMultipleSale.address)).balance).toEqual(0n);
        tonMultipleSaleConfig = await tonMultipleSale.getStorageData();
        expect(tonMultipleSaleConfig.state).toEqual(TonMultipleSale.STATE_CANCELLED);
    });

    it("should cancel by external message", async () => {
        blockchain.now!! = tonMultipleSaleConfig.validUntil;
        transactionRes = await tonMultipleSale.sendExternalCancel();
        tonMultipleSaleConfig = await tonMultipleSale.getStorageData();
        expect(tonMultipleSaleConfig.state).toEqual(TonMultipleSale.STATE_CANCELLED);
        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.ownerAddress!!.toString()).toEqual(tonMultipleSaleConfig.sellerAddress.toString());
        }
    });

});

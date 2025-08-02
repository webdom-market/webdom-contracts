import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { JettonMultipleSale, JettonMultipleSaleConfig } from '../wrappers/JettonMultipleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';


describe('MultipleJettonSale', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;

    let jettonMultipleSaleCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');

        jettonMultipleSaleCode = await compile('JettonMultipleSale');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let jettonMultipleSale: SandboxContract<JettonMultipleSale>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtMarketplaceWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtSaleWallet: SandboxContract<JettonWallet>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton"];
    let domainConfigs: Array<DomainConfig>;
    let transactionRes: SendMessageResult;

    let jettonMultipleSaleConfig: JettonMultipleSaleConfig;
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
        
        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.2"), toNano("0.5"));
        usdtMarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtBuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));

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
            const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
            expect(transactionRes.transactions).toHaveTransaction({
                from: dnsCollection.address,
                to: domainAddress,
                deploy: true,
                success: true
            })
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            blockchain.now += 60 * 60 + 1;  // end of the auction
            transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
            
            // console.log((await domain.getStorageData()).ownerAddress);
            domains.push(domain);
            domainsDict.set(domainAddress, 0);
        }

        jettonMultipleSaleConfig = {
            jettonMinterAddress: usdtMinter.address,
            jettonWalletAddress: undefined,
            sellerAddress: seller.address,
            domainsDict: domainsDict,
            domainsTotal: domains.length,
            domainsReceived: 0,
            price: toNano('2'),
            state: JettonMultipleSale.STATE_UNINIT,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            lastRenewalTime: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: null,
            tonsToReserve: 15000000,
        }
        jettonMultipleSale = blockchain.openContract(JettonMultipleSale.createFromConfig(jettonMultipleSaleConfig, jettonMultipleSaleCode));
        usdtSaleWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(jettonMultipleSale.address)));

        transactionRes = await jettonMultipleSale.sendDeploy(admin.getSender(), toNano('0.05'), beginCell().storeAddress(usdtSaleWallet.address).endCell());
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: jettonMultipleSale.address,
            deploy: true,
            success: true
        })

        for (let domain of domains) {
            transactionRes = await domain.sendTransfer(seller.getSender(), jettonMultipleSale.address, null, null, toNano('0.1'));
            domainConfigs.push(await domain.getStorageData());
        }

        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonMultipleSale.address,
            to: seller.address,
            body: beginCell().storeUint(0, 32).storeStringTail("Multiple sale on webdom.market is active").endCell(),
        })

        jettonMultipleSaleConfig = await jettonMultipleSale.getStorageData();
        expect(jettonMultipleSaleConfig.domainsReceived).toEqual(domains.length);
        for (let domain of domains) {
            expect(jettonMultipleSaleConfig.domainsDict.get(domain.address)).toEqual(1);
        }

        expect(usdtSaleWallet.address.toString()).toEqual(jettonMultipleSaleConfig.jettonWalletAddress!.toString());
    });

    // it('should deploy', async () => {

    // });

    it('should sell domains', async () => {
        // reject if valid_until < now
        blockchain.now! = jettonMultipleSaleConfig.validUntil + 1;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonMultipleSaleConfig.price, jettonMultipleSale.address, buyer.address, toNano("0.555"));
        expect(transactionRes.transactions).toHaveTransaction({
            to: jettonMultipleSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })

        // accept 
        transactionRes = await jettonMultipleSale.sendChangePrice(seller.getSender(), jettonMultipleSaleConfig.price, blockchain.now! + 600);
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonMultipleSaleConfig.price, jettonMultipleSale.address, buyer.address, toNano("0.555"));

        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(jettonMultipleSaleConfig.price - jettonMultipleSaleConfig.commission, jettonMultipleSale.address, 
                beginCell().storeUint(0, 32).storeStringTail("Payout for multiple domains sale on webdom.market").endCell()
            ),
        })

        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtMarketplaceWallet.address,
            to: marketplace.address,
            body: JettonWallet.transferNotificationMessage(jettonMultipleSaleConfig.commission, jettonMultipleSale.address,
                beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
            ),
        })

        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
        }

        // reject if already sold
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonMultipleSaleConfig.price, jettonMultipleSale.address, buyer.address, toNano("0.225"));
        expect(transactionRes.transactions).toHaveTransaction({
            to: jettonMultipleSale.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        })
    });


    it('should change price', async () => {
        let checks = 100;
        for (let i = 0; i < 100; ++i) {
            let newPrice = BigInt(Math.ceil(Math.random() * 10 ** (i % 9 + 9)));
            let timeSpent = Math.ceil(ONE_DAY * Math.random() * 700 / checks);  
            blockchain.now! += timeSpent;
            let newValidUntil = Math.ceil(blockchain.now! + ONE_DAY * Math.random() * 700 / checks);
            transactionRes = await jettonMultipleSale.sendChangePrice(seller.getSender(), newPrice, newValidUntil);
            if (jettonMultipleSaleConfig.lastRenewalTime + ONE_YEAR - ONE_DAY < newValidUntil || newValidUntil < Math.max(blockchain.now! + 600, jettonMultipleSaleConfig.validUntil)) {
                expect(transactionRes.transactions).toHaveTransaction({
                    from: seller.address,
                    to: jettonMultipleSale.address,
                    // success: false,
                    exitCode: Exceptions.INCORRECT_VALID_UNTIL
                })
                if (newValidUntil >= Math.max(blockchain.now! + 600, jettonMultipleSaleConfig.lastRenewalTime)) break;
            }
            else {
                jettonMultipleSaleConfig = await jettonMultipleSale.getStorageData();
                expect(jettonMultipleSaleConfig.price).toEqual(newPrice);
                expect(jettonMultipleSaleConfig.validUntil).toEqual(newValidUntil);
                
                let notificationMessage = transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail();
                let priceString = notificationMessage.split(' ')[3];
                let expectedPriceString = jettonsToString(Number(newPrice), 6);
                expect(priceString).toEqual(expectedPriceString);
            }
        }
    });

    it("should renew domain", async () => {
        blockchain.now! += ONE_DAY * 30;
        transactionRes = await jettonMultipleSale.sendRenewDomain(seller.getSender(), jettonMultipleSaleConfig.domainsTotal);
        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!);
        }
        
        blockchain.now! += ONE_YEAR - ONE_DAY + 1;
        transactionRes = await jettonMultipleSale.sendRenewDomain(seller.getSender(), jettonMultipleSaleConfig.domainsTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: jettonMultipleSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        });
    });

    it("should handle expiration notification", async () => {
        blockchain.now! += ONE_YEAR + 1;
        transactionRes = await domains[0].sendStartAuction(admin.getSender(), DOMAIN_NAMES[0]);
        for (let i = 1; i < domains.length; ++i) {
            let domainConfig = await domains[i].getStorageData();
            expect(domainConfig.ownerAddress!.toString()).toEqual(jettonMultipleSaleConfig.sellerAddress.toString());
        }
        expect((await blockchain.getContract(jettonMultipleSale.address)).balance).toEqual(0n);
        jettonMultipleSaleConfig = await jettonMultipleSale.getStorageData();
        expect(jettonMultipleSaleConfig.state).toEqual(JettonMultipleSale.STATE_CANCELLED);
    });

    it("should cancel by external message", async () => {
        blockchain.now! = jettonMultipleSaleConfig.validUntil;
        transactionRes = await jettonMultipleSale.sendExternalCancel();
        jettonMultipleSaleConfig = await jettonMultipleSale.getStorageData();
        expect(jettonMultipleSaleConfig.state).toEqual(JettonMultipleSale.STATE_CANCELLED);
        for (let domain of domains) {
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.ownerAddress!.toString()).toEqual(jettonMultipleSaleConfig.sellerAddress.toString());
        }
    });
});

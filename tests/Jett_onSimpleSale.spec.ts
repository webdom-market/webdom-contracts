import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { JettonSimpleSale, JettonSimpleSaleConfig } from '../wrappers/JettonSimpleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { getIndexByDomainName } from '../wrappers/helpers/dnsUtils';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';


function domainToNotification(domainName: string): Cell {
    return beginCell().storeUint(0, 32).storeStringTail(`Your domain was sold on webdom.market: `).storeRef(beginCell().storeStringTail(domainName).endCell()).endCell();
}


describe('JettonSimpleSale', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;
    
    let fixPriceSaleCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');

        fixPriceSaleCode = await compile('JettonSimpleSale');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let jettonSimpleSale: SandboxContract<JettonSimpleSale>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtMarketplaceWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtSaleWallet: SandboxContract<JettonWallet>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let jettonSimpleSaleConfig: JettonSimpleSaleConfig;
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;

        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');

        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.2"), toNano("0.5"));
        await usdtMinter.sendMint(admin.getSender(), admin.address, toNano(100), toNano("0.2"), toNano("0.5"));
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

        jettonSimpleSaleConfig = {
            domainAddress,
            sellerAddress: seller.address,
            jettonMinterAddress: usdtMinter.address,
            price: toNano('2'),
            state: JettonSimpleSale.STATE_UNINIT,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            lastRenewalTime: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: null,
            domainName: DOMAIN_NAME
        }
        jettonSimpleSale = blockchain.openContract(JettonSimpleSale.createFromConfig(jettonSimpleSaleConfig, fixPriceSaleCode));
        usdtSaleWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(jettonSimpleSale.address)));

        transactionRes = await jettonSimpleSale.sendDeploy(admin.getSender(), toNano('0.05'), beginCell().storeAddress(usdtSaleWallet.address).endCell());
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: jettonSimpleSale.address,
            deploy: true,
            success: true
        })

        transactionRes = await domain.sendTransfer(seller.getSender(), jettonSimpleSale.address, seller.address);
        let domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress?.toString()).toEqual(jettonSimpleSale.address.toString());

        jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.state).toEqual(JettonSimpleSale.STATE_ACTIVE);
        expect(usdtSaleWallet.address.toString()).toEqual(jettonSimpleSaleConfig.jettonWalletAddress!!.toString());
    });

    it('should sell domain', async () => {
        // reject if valid_until < now
        blockchain.now!! = jettonSimpleSaleConfig.validUntil + 1;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleSaleConfig.price, jettonSimpleSale.address, buyer.address, toNano("0.225"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.price, jettonSimpleSale.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.DEAL_NOT_ACTIVE}`).endCell()),
        })

        await jettonSimpleSale.sendChangePrice(seller.getSender(), jettonSimpleSaleConfig.price, blockchain.now!! + 600);

        // reject if not enough jettons
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleSaleConfig.price - 100n, jettonSimpleSale.address, buyer.address, toNano("0.235"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.price - 100n, jettonSimpleSale.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.NOT_ENOUGH_JETTONS}`).endCell()),
        })

        // reject if not enough gas
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleSaleConfig.price, jettonSimpleSale.address, buyer.address, toNano("0.2"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.price, jettonSimpleSale.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.OUT_OF_GAS}`).endCell()),
        })

        // accept 
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleSaleConfig.price + 100n, jettonSimpleSale.address, buyer.address, toNano("0.235"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.price - jettonSimpleSaleConfig.commission, jettonSimpleSale.address, 
                domainToNotification(DOMAIN_NAME)
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtMarketplaceWallet.address,
            to: marketplace.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.commission, jettonSimpleSale.address,
                beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(100n, jettonSimpleSale.address, 
                beginCell().storeUint(0, 32).storeStringTail(`Excesses`).endCell()
            ),
        })

        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());

        // reject if already sold
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleSaleConfig.price, jettonSimpleSale.address, buyer.address, toNano("0.235"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleSaleConfig.price, jettonSimpleSale.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.DEAL_NOT_ACTIVE}`).endCell()),
        })
    });

    it("should handle dedust swap", async () => {
        transactionRes = await usdtMarketplaceWallet.sendTransfer(
            admin.getSender(), jettonSimpleSaleConfig.price, jettonSimpleSale.address, buyer.address, 
            toNano("0.235"), beginCell().storeAddress(buyer.address).endCell()
        );
        jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.buyerAddress!.toString()).toEqual(buyer.address.toString());
    })


    it('should change price', async () => {
        let checks = 100;
        for (let i = 0; i < 100; ++i) {
            let newPrice = BigInt(Math.ceil(Math.random() * 10 ** (i % 9 + 9)));
            let timeSpent = Math.ceil(ONE_DAY * Math.random() * 700 / checks);  
            blockchain.now!! += timeSpent;
            let newValidUntil = Math.ceil(blockchain.now!! + ONE_DAY * Math.random() * 700 / checks);
            transactionRes = await jettonSimpleSale.sendChangePrice(seller.getSender(), newPrice, newValidUntil);
            if (jettonSimpleSaleConfig.lastRenewalTime + ONE_YEAR - ONE_DAY < newValidUntil || newValidUntil < Math.max(blockchain.now!! + 600, jettonSimpleSaleConfig.validUntil)) {
                expect(transactionRes.transactions).toHaveTransaction({
                    from: seller.address,
                    to: jettonSimpleSale.address,
                    // success: false,
                    exitCode: Exceptions.INCORRECT_VALID_UNTIL
                })
                if (newValidUntil >= Math.max(blockchain.now!! + 600, jettonSimpleSaleConfig.lastRenewalTime)) break;
            }
            else {
                jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
                expect(jettonSimpleSaleConfig.price).toEqual(newPrice);
                expect(jettonSimpleSaleConfig.validUntil).toEqual(newValidUntil);
                
                let notificationMessage = transactionRes.transactions[2].inMessage!!.body.beginParse().skip(32).loadStringTail();
                let priceString = notificationMessage.split(' ')[3];
                let expectedPriceString = jettonsToString(Number(newPrice), 6);
                expect(priceString).toEqual(expectedPriceString);
            }
        }
    });

    it("should renew domain", async () => {
        blockchain.now!! += ONE_DAY * 30;
        transactionRes = await jettonSimpleSale.sendRenewDomain(seller.getSender());
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!!);
        
        blockchain.now!! += ONE_YEAR - ONE_DAY + 1;
        transactionRes = await jettonSimpleSale.sendRenewDomain(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: jettonSimpleSale.address,
            exitCode: Exceptions.DOMAIN_EXPIRED
        });
    });

    it("should cancel by external message", async () => {
        blockchain.now!! = jettonSimpleSaleConfig.validUntil;
        // console.log((await blockchain.getContract(jettonSimpleSale.address)).balance);
        transactionRes = await jettonSimpleSale.sendExternalCancel();
        jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.state).toEqual(JettonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(jettonSimpleSaleConfig.sellerAddress.toString());
    });

    it("should cancel by internal message", async () => {
        blockchain.now!! = jettonSimpleSaleConfig.validUntil;
        // console.log((await blockchain.getContract(jettonSimpleSale.address)).balance);
        transactionRes = await jettonSimpleSale.sendCancelSale(seller.getSender());
        jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.state).toEqual(JettonSimpleSale.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(jettonSimpleSaleConfig.sellerAddress.toString());
    });
    
    it("should make hot", async () => {
        transactionRes = await jettonSimpleSale.sendMakeHot(admin.getSender(), blockchain.now!! + ONE_DAY * 3 / 2);
        transactionRes = await jettonSimpleSale.sendMakeColored(admin.getSender(), blockchain.now!! + ONE_DAY * 2);
        jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.hotUntil).toEqual(blockchain.now!! + ONE_DAY * 3 / 2);
        expect(jettonSimpleSaleConfig.coloredUntil).toEqual(blockchain.now!! + ONE_DAY * 2);
    });
});

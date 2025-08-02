import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract, Treasury } from '@ton/sandbox';
import { Address, beginCell, Cell, contractAddress, Dictionary, toNano } from '@ton/core';
import { DeployData, DeployInfoValue, Marketplace, MarketplaceConfig, marketplaceConfigToCell, PromotionPricesValue, promotionPricesValueParser } from '../wrappers/Marketplace';
import { MarketplaceDeployer } from '../wrappers/MarketplaceDeployer';
import '@ton/test-utils';
import { compile, sleep } from '@ton/blueprint';
import { TonSimpleSale, TonSimpleSaleDeployData, TonSimpleSaleConfig, tonSimpleSaleConfigToCell } from '../wrappers/TonSimpleSale';
import { JettonSimpleSale, JettonSimpleSaleDeployData } from '../wrappers/JettonSimpleSale';
import { TonSimpleAuction, TonSimpleAuctionDeployData } from '../wrappers/TonSimpleAuction';
import { JettonSimpleAuction, JettonSimpleAuctionDeployData } from '../wrappers/JettonSimpleAuction';
import { Domain } from '../wrappers/Domain';

import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';

import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Addresses, COMMISSION_DIVIDER, Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes, Tons } from '../wrappers/helpers/constants';
import { TonMultipleSale, TonMultipleSaleDeployData } from '../wrappers/TonMultipleSale';
import { TonSimpleOffer, TonSimpleOfferDeployData } from '../wrappers/TonSimpleOffer';
// import { MultipleDomainsSwap, MultipleDomainsSwapDeployData } from '../wrappers/MultipleDomainsSwap';
import { stringValueParser } from '../wrappers/helpers/DefaultContract';
import { JettonSimpleOffer, JettonSimpleOfferDeployData } from '../wrappers/JettonSimpleOffer';
import { JettonMultipleSale, JettonMultipleSaleDeployData } from '../wrappers/JettonMultipleSale';
import { TgUsernamesCollectionConfig } from '../wrappers/TgUsernamesCollection';
import { TgUsernamesCollection } from '../wrappers/TgUsernamesCollection';
import { TonMultipleAuction, TonMultipleAuctionDeployData } from '../wrappers/TonMultipleAuction';
import { JettonMultipleAuction } from '../wrappers/JettonMultipleAuction';
import { MultipleOfferDeployData, MultipleOffer, domainInOfferValue } from '../wrappers/MultipleOffer';
import { getDeployFunctionCode } from '../wrappers/helpers/getDeployFunctionCode';
import { packStateInit } from '../wrappers/helpers/dnsUtils';


describe('Marketplace', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;

    let tgUsernamesCollectionCode: Cell;
    let tgUsernameCode: Cell;

    let marketplaceCode: Cell;
    let jettonSimpleSaleCode: Cell;
    // let multipleDomainsSwapCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;
    // let tonShoppingCartCode: Cell;
    let tonAuctionCode: Cell;
    let tonSimpleSaleCode: Cell;
    let tonMultipleSaleCode: Cell;
    let tonSimpleOfferCode: Cell;
    let jettonSimpleOfferCode: Cell;
    let jettonSimpleAuctionCode: Cell;
    let jettonMultipleSaleCode: Cell;
    let marketplaceDeployerCode: Cell;
    let tonMultipleAuctionCode: Cell;
    let jettonMultipleAuctionCode: Cell;
    let multipleOfferCode: Cell;

    let deployInfos: Dictionary<number, DeployInfoValue>;
    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');

        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        tgUsernamesCollectionCode = await compile('TgUsernamesCollection');
        tgUsernameCode = await compile('TgUsername');

        marketplaceDeployerCode = await compile('MarketplaceDeployer');
        marketplaceCode = await compile('Marketplace');
        
        tonSimpleOfferCode = await compile('TonSimpleOffer');
        jettonSimpleOfferCode = await compile('JettonSimpleOffer');
        multipleOfferCode = await compile('MultipleOffer');

        tonSimpleSaleCode = await compile('TonSimpleSale');
        jettonSimpleSaleCode = await compile('JettonSimpleSale');
        tonMultipleSaleCode = await compile('TonMultipleSale');
        jettonMultipleSaleCode = await compile('JettonMultipleSale');

        tonAuctionCode = await compile('TonSimpleAuction');
        jettonSimpleAuctionCode = await compile('JettonSimpleAuction');
        tonMultipleAuctionCode = await compile('TonMultipleAuction');
        jettonMultipleAuctionCode = await compile('JettonMultipleAuction');
        
        // tonShoppingCartCode = await compile('TonShoppingCart');
        // multipleDomainsSwapCode = await compile('MultipleDomainsSwap');
    }, 10000);

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<Marketplace>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;
    let leftDomainsDict: Dictionary<number, string>;
    let rightDomainsDict: Dictionary<number, string>;
    let domainsDict: Dictionary<Address, number>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let leftOwner: SandboxContract<TreasuryContract>;
    let rightOwner: SandboxContract<TreasuryContract>;

    let web3Minter: SandboxContract<JettonMinter>;
    let web3AdminWallet: SandboxContract<JettonWallet>;
    let web3SellerWallet: SandboxContract<JettonWallet>;
    let web3BuyerWallet: SandboxContract<JettonWallet>;
    let web3MarketplaceWallet: SandboxContract<JettonWallet>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtAdminWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtMarketplaceWallet: SandboxContract<JettonWallet>;

    let tgUsernamesCollectionConfig: TgUsernamesCollectionConfig;
    let tgUsernamesCollection: SandboxContract<TgUsernamesCollection>;

    const DOMAIN_NAMES = ["viqex.t.me", "test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton", "mxmxmx.ton"];
    
    let marketplaceConfig: MarketplaceConfig

    let transactionRes: SendMessageResult;
    const publicKey = Buffer.from("6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8", 'hex');
    const secretKey = Buffer.from("a697139dab71a6ec0e2abf3232c4ebe2ba5c383c18a0229e9e3705aacfa3d9c96580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8", 'hex');

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        
        blockchain.now = MIN_PRICE_START_TIME;
        domains = [];

        admin = await blockchain.treasury('admin');
        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');
        leftOwner = seller;
        rightOwner = buyer;

        web3Minter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("web3").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await web3Minter.sendDeploy(admin.getSender(), toNano("0.05"));
        await web3Minter.sendMint(admin.getSender(), seller.address, toNano(1000), toNano("0.2"), toNano("0.5"));
        await web3Minter.sendMint(admin.getSender(), buyer.address, toNano(1000), toNano("0.2"), toNano("0.5"));
        web3AdminWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(admin.address)));
        web3SellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(seller.address)));
        web3MarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(Addresses.MARKETPLACE_TESTS)));
        web3BuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(buyer.address)));
        
        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.2"), toNano("0.5"));
        usdtMarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(Addresses.MARKETPLACE_TESTS)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtBuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));


        // deploy DNS collection
        dnsCollection = blockchain.openContract(DnsCollection.createFromConfig({
            content: beginCell().endCell(),
            nftItemCode: domainCode,
        } as DnsCollectionConfig, dnsCollectionCode));

        // deploy tg usernames collection
        tgUsernamesCollectionConfig = {
            touched: true,
            subwalletId: 0,
            publicKey: 0x6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8n,
            content: beginCell().endCell(),
            itemCode: tgUsernameCode,
            fullDomain: "me\u0000t\u0000",
            royaltyParams: beginCell().storeUint(5, 16).storeUint(100, 16).storeAddress(admin.address).endCell()
        }
        tgUsernamesCollection = blockchain.openContract(TgUsernamesCollection.createFromConfig(tgUsernamesCollectionConfig, tgUsernamesCollectionCode));
        transactionRes = await tgUsernamesCollection.sendDeploy(admin.getSender(), toNano("0.05"));

        // deploy domains
        leftDomainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), stringValueParser());
        rightDomainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), stringValueParser());
        transactionRes = await dnsCollection.sendDeploy(admin.getSender(), toNano('0.05')); 
        for (let i = 0; i < DOMAIN_NAMES.length; ++i) {  // deploy domains
            const domainName = DOMAIN_NAMES[i];
            if (domainName.includes(".t.me")) {
                transactionRes = await tgUsernamesCollection.sendStartAuction(
                    admin.getSender(), domainName.slice(0, domainName.indexOf('.')), tgUsernamesCollectionConfig, secretKey, toNano("5")
                )
            }
            else {
                transactionRes = await dnsCollection.sendStartAuction(
                    admin.getSender(), domainName.slice(0, domainName.indexOf('.'))
                );
            }
            const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
            expect(transactionRes.transactions).toHaveTransaction({
                to: domainAddress,
                deploy: true,
                success: true
            })
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            blockchain.now += 60 * 60 + 1;  // end of the auction

            domains.push(domain);
            if (i < 2) {
                transactionRes = await domain.sendTransfer(admin.getSender(), leftOwner.address, admin.address);
                leftDomainsDict.set(i, domainName);
            } else {
                transactionRes = await domain.sendTransfer(admin.getSender(), rightOwner.address, admin.address);
                rightDomainsDict.set(i - 2, domainName);
            }
        }
        
        deployInfos = Dictionary.empty();

        deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, {
            dealCode: tonSimpleOfferCode,
            deployFunctionCode: getDeployFunctionCode('TonSimpleOffer'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: TonSimpleOfferDeployData.fromConfig(
                toNano('0.4'),    // minPrice
                400,            // commissionFactor (4%)
                toNano('50'),   // maxCommission
                300             // minDuration (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER, {
            dealCode: jettonSimpleOfferCode,
            deployFunctionCode: getDeployFunctionCode('JettonSimpleOffer'),
            deployType: Marketplace.DeployTypes.JETTON_TRANSFER,
            deployFee: toNano('0.05'),
            otherData: JettonSimpleSaleDeployData.fromConfig(
                2n * 10n ** 6n,    // minPriceUsdt
                400,               // commissionFactorUsdt (4%)
                300n * 10n ** 6n,  // maxCommissionUsdt
                300,               // minDuration (5 minutes)

                20n * 10n ** 3n,    // minPriceWeb3
                200,               // commissionFactorWeb3 (2%)
                3000n * 10n ** 3n, // maxCommissionWeb3 (5 minutes)
                300                // minDuration (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.MULTIPLE_OFFER, {
            dealCode: multipleOfferCode,
            deployFunctionCode: getDeployFunctionCode('MultipleOffer'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: MultipleOfferDeployData.fromConfig(
                400,               // commissionFactor (4%)
                200,               // web3CommissionFactor (2%)
            ),
        });

        deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_SALE, {
            dealCode: tonSimpleSaleCode,
            deployFunctionCode: getDeployFunctionCode('TonSimpleSale'),
            deployType: Marketplace.DeployTypes.NFT_TRANSFER,
            deployFee: toNano('0.05'),
            otherData: TonSimpleSaleDeployData.fromConfig(
                toNano('0.4'),  // minPrice
                400,            // commissionFactor (4%)
                toNano('50'),   // maxCommission
                300             // minDuration (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE, {
            dealCode: jettonSimpleSaleCode,
            deployFunctionCode: getDeployFunctionCode('JettonSimpleSale'),
            deployType: Marketplace.DeployTypes.NFT_TRANSFER,
            deployFee: toNano('0.05'),
            otherData: JettonSimpleSaleDeployData.fromConfig(
                2n * 10n ** 6n,    // minPriceUsdt
                400,               // commissionFactorUsdt (4%)
                300n * 10n ** 6n,  // maxCommissionUsdt
                300,               // minDuration (5 minutes)

                20n * 10n ** 3n,   // minPriceWeb3
                200,               // commissionFactorWeb3 (2%)
                3000n * 10n ** 3n, // minDuration (5 minutes)
                300                // minDuration (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, {
            dealCode: tonMultipleSaleCode,
            deployFunctionCode: getDeployFunctionCode('TonMultipleSale'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: TonMultipleSaleDeployData.fromConfig(
                toNano('0.4'),    // minPrice
                400,            // commissionFactor (4%)
                toNano('50'),   // maxCommission
                600             // minDuration (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, {
            dealCode: jettonMultipleSaleCode,
            deployFunctionCode: getDeployFunctionCode('JettonMultipleSale'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: JettonSimpleSaleDeployData.fromConfig(
                2n * 10n ** 6n,    // minPriceUsdt
                400,               // commissionFactorUsdt (4%)
                300n * 10n ** 6n,  // maxCommissionUsdt
                300,               // minDuration (5 minutes)

                20n * 10n ** 3n,    // minPriceWeb3
                200,               // commissionFactorWeb3 (2%)
                3000n * 10n ** 3n, // minDuration (5 minutes)
                300                // minDuration (5 minutes)
            ),
        });


        deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION, {
            dealCode: tonAuctionCode,
            deployFunctionCode: getDeployFunctionCode('TonSimpleAuction'),
            deployType: Marketplace.DeployTypes.NFT_TRANSFER,
            deployFee: toNano('0.05'),
            otherData: TonSimpleAuctionDeployData.fromConfig(
                toNano('0.4'),  // minPrice
                400,            // commissionFactor (4%)
                toNano('50'),   // maxCommission
                300             // minTimeIncrement (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_AUCTION, {
            dealCode: jettonSimpleAuctionCode,
            deployFunctionCode: getDeployFunctionCode('JettonSimpleAuction'),
            deployType: Marketplace.DeployTypes.NFT_TRANSFER,
            deployFee: toNano('0.05'),
            otherData: JettonSimpleAuctionDeployData.fromConfig(
                2n * 10n ** 6n,    // minPriceUsdt
                400,               // commissionFactorUsdt (4%)
                300n * 10n ** 6n,  // maxCommissionUsdt
                300,               // minTimeIncrement (5 minutes)

                20n * 10n ** 3n,   // minPriceWeb3
                200,               // commissionFactorWeb3 (2%)
                3000n * 10n ** 3n, // minDuration (5 minutes)
                300                // minTimeIncrement (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION, {
            dealCode: tonMultipleAuctionCode,
            deployFunctionCode: getDeployFunctionCode('TonMultipleAuction'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: TonMultipleAuctionDeployData.fromConfig(
                toNano('0.4'),  // minPrice
                400,            // commissionFactor (4%)
                toNano('50'),   // maxCommission
                300             // minTimeIncrement (5 minutes)
            ),
        });
        deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION, {
            dealCode: jettonMultipleAuctionCode,
            deployFunctionCode: getDeployFunctionCode('JettonMultipleAuction'),
            deployType: Marketplace.DeployTypes.SIMPLE,
            deployFee: toNano('0.05'),
            otherData: JettonSimpleAuctionDeployData.fromConfig(
                2n * 10n ** 6n,    // minPriceUsdt
                400,               // commissionFactorUsdt (4%)
                300n * 10n ** 6n,  // maxCommissionUsdt
                300,               // minTimeIncrement (5 minutes)
        
                20n * 10n ** 3n,   // minPriceWeb3
                200,               // commissionFactorWeb3 (2%)
                3000n * 10n ** 3n, // maxCommissionWeb3
                300                // minTimeIncrement (5 minutes)
            ),
        });


        // deployInfos.set(Marketplace.DeployOpCodes.MULTIPLE_DOMAINS_SWAP, {
        //     code: multipleDomainsSwapCode,
        //     deployFee: toNano('0.05'),
        //     otherData: MultipleDomainsSwapDeployData.fromConfig(
        //         toNano('0.5'),   // completionCommission
        //         600             // minDuration (5 minutes)
        //     ),
        // });
        

        let subscriptionsInfo = Dictionary.empty(Dictionary.Keys.Uint(8), Dictionary.Values.Dictionary(Dictionary.Keys.Uint(32), Dictionary.Values.BigUint(64)));
        let subscriptionLevelInfo = Dictionary.empty(Dictionary.Keys.Uint(32), Dictionary.Values.BigUint(64));
        subscriptionLevelInfo.set(30 * ONE_DAY, toNano('1'));
        subscriptionLevelInfo.set(ONE_YEAR, toNano('9'));
        subscriptionsInfo.set(1, subscriptionLevelInfo);

        let promotionPrices = Dictionary.empty(Dictionary.Keys.Uint(32), promotionPricesValueParser());
        promotionPrices.set(3 * ONE_DAY, {
            hotPrice: 3000n,
            coloredPrice: 6000n,
        });
        promotionPrices.set(7 * ONE_DAY, {
            hotPrice: 6000n,
            coloredPrice: 12000n,
        });
        promotionPrices.set(14 * ONE_DAY, {
            hotPrice: 10000n,
            coloredPrice: 20000n,
        });

        marketplaceConfig = {
            ownerAddress: admin.address,
            publicKey: 0x6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8n,
            deployInfos,
            
            userSubscriptions: undefined,
            subscriptionsInfo,

            moveUpSalePrice: 6000n,
            currentTopSale: Addresses.BURN,

            web3WalletAddress: web3MarketplaceWallet.address,
            
            collectedFeesTon: 0n,
            collectedFeesDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.BigVarUint(4)),

            promotionPrices,
        };
        let marketplaceDeployer = blockchain.openContract(MarketplaceDeployer.createFromConfig(4702601605n, marketplaceDeployerCode));
        transactionRes = await marketplaceDeployer.sendDeploy(admin.getSender(), toNano('0.05'), marketplaceCode, marketplaceConfigToCell(marketplaceConfig, true));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: marketplaceDeployer.address,
            deploy: true,
            success: true,
        });
        
        marketplace = blockchain.openContract(Marketplace.createFromAddress(marketplaceDeployer.address));
        // marketplaceConfig = await marketplace.getStorageData();
        // expect(marketplaceConfig.ownerAddress.toString()).toBe(admin.address.toString());
    }, 10000);

    /* OFFERS */

    it('should deploy ton simple offer', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER)!.otherData as TonSimpleOfferDeployData;
        let price = toNano('500');
        let validUntil = blockchain.now! + 300;
        let notifySeller = true;

        // Decline if price is too high
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(), 
            price, 
            Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, 
            TonSimpleOffer.deployPayload(price, validUntil, seller.address, DOMAIN_NAMES[0], notifySeller)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: marketplace.address,
            exitCode: Exceptions.OUT_OF_GAS,
        });

        // Decline if price is too low
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(), 
            price + toNano('0.5'), 
            Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, 
            TonSimpleOffer.deployPayload(deployData.minPrice - 1n, validUntil, seller.address, DOMAIN_NAMES[0], notifySeller)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: marketplace.address,
            exitCode: Exceptions.PRICE_TOO_LOW,
        });

        // Decline if valid until is too low
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(), 
            price + toNano('0.5'), 
            Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, 
            TonSimpleOffer.deployPayload(price, blockchain.now! + deployData.minDuration - 1, seller.address, DOMAIN_NAMES[0], notifySeller)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: marketplace.address,
            exitCode: Exceptions.INCORRECT_VALID_UNTIL,
        });

        // Accept
        let commission = price * BigInt(deployData.commissionFactor) / BigInt(COMMISSION_DIVIDER);
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(), 
            price + commission + toNano('0.1') * BigInt(notifySeller) + toNano('0.2'),  // 0.079 returns 
            Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, 
            TonSimpleOffer.deployPayload(price, validUntil, seller.address, DOMAIN_NAMES[0], notifySeller)
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let purchaseOfferAddress = transactionRes.transactions[2 + Number(notifySeller)].inMessage!.info.dest! as Address;
        let purchaseOffer = blockchain.openContract(TonSimpleOffer.createFromAddress(purchaseOfferAddress));
        let purchaseOfferConfig = await purchaseOffer.getStorageData();
        expect(purchaseOfferConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(purchaseOfferConfig.buyerAddress!.toString()).toEqual(buyer.address.toString());
        expect(purchaseOfferConfig.price).toEqual(price);
        expect(purchaseOfferConfig.validUntil).toEqual(validUntil);
        expect(purchaseOfferConfig.state).toEqual(TonSimpleOffer.STATE_ACTIVE);
    });

    it('should deploy jetton simple offer', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER)!.otherData as JettonSimpleOfferDeployData;
        let price = toNano('1');
        let commission = BigInt(deployData.commissionFactorUsdt) * price / BigInt(COMMISSION_DIVIDER);
        let validUntil = blockchain.now! + 300;
        let notifySeller = true;
        const initialBuyerBalance = await buyer.getBalance();
        const initialMarketplaceBalance = (await blockchain.getContract(marketplace.address)).balance;

        // deploy
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            price + commission,
            marketplace.address,
            buyer.address,
            toNano('0.185') + toNano('0.05') + toNano('0.1') + toNano('0.09'),  // deploy gas + jetton transfer + notify seller + fwd fees and compute fees
            Marketplace.deployDealWithJettonTransferPayload(buyer.address, Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER, JettonSimpleOffer.deployPayload(validUntil, seller.address, DOMAIN_NAMES[0], notifySeller)),
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: seller.address,
            body: beginCell().storeUint(0, 32).storeStringTail(`New offer on webdom.market! 1000 USDT for `).storeStringRefTail(DOMAIN_NAMES[0]).endCell(),
        });

        let purchaseOfferAddress = transactionRes.transactions[5 + Number(notifySeller)].inMessage!.info.dest! as Address;
        let purchaseOffer = blockchain.openContract(JettonSimpleOffer.createFromAddress(purchaseOfferAddress));
        let purchaseOfferConfig = await purchaseOffer.getStorageData();
        expect(purchaseOfferConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(purchaseOfferConfig.buyerAddress!.toString()).toEqual(buyer.address.toString());
        expect(purchaseOfferConfig.price).toEqual(price);
        expect(purchaseOfferConfig.validUntil).toEqual(validUntil);
        expect(purchaseOfferConfig.state).toEqual(JettonSimpleOffer.STATE_ACTIVE);
    })

    it('should deploy multiple offer correctly', async () => {
        // Get deploy data from marketplace config
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.MULTIPLE_OFFER)!.otherData as MultipleOfferDeployData;
        
        // Create a dictionary of domains for the merkle tree
        const domainsDict = Dictionary.empty(Dictionary.Keys.Address(), domainInOfferValue);
        
        // Add domains to the dictionary with different prices and valid times
        for (let i = 0; i < 3; i++) {
            const domainPrice = toNano(`${i + 1}`);
            const validUntil = blockchain.now! + ONE_DAY * (i + 1);
            
            domainsDict.set(domains[i].address, {
                price: domainPrice,
                validUntil: validUntil
            });
        }
        
        // Add a domain with web3 token payment
        domainsDict.set(domains[3].address, {
            price: 50000n,
            validUntil: blockchain.now! + ONE_DAY * 2,
            jettonInfo: {
                jettonWalletAddress: web3MarketplaceWallet.address,
                oneJetton: 1000n,
                jettonSymbol: "WEB3"
            }
        });
        
        // Calculate merkle root from the dictionary
        const dictCell = beginCell().storeDictDirect(domainsDict).endCell();
        const merkleRoot = BigInt('0x' + dictCell.hash().toString('hex'));
        
        // Deploy the multiple offer contract
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.MULTIPLE_OFFER,
            MultipleOffer.deployPayload(merkleRoot)
        );
        // Verify the deployment was successful
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        
        // Get the address of the deployed contract
        const multipleOfferAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        const multipleOffer = blockchain.openContract(MultipleOffer.createFromAddress(multipleOfferAddress));
        
        // Verify the contract configuration
        let multipleOfferConfig = await multipleOffer.getStorageData();
        
        expect(multipleOfferConfig.ownerAddress.toString()).toEqual(buyer.address.toString());
        expect(multipleOfferConfig.merkleRoot).toEqual(merkleRoot);
        expect(multipleOfferConfig.commissionFactor).toEqual(deployData.commissionFactor);
        expect(multipleOfferConfig.web3CommissionFactor).toEqual(deployData.web3CommissionFactor);

        // Fill up the contract balance with Web3 tokens
        transactionRes = await web3BuyerWallet.sendTransfer(
            buyer.getSender(),
            50000n,
            multipleOffer.address,
            buyer.address,
            toNano('0.15'),
            MultipleOffer.fillUpJettonBalancePayload(toNano('0.1'))
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode: (x) => Boolean(x) });
        
        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.jettonBalancesDict.get(multipleOfferConfig.web3WalletAddress!)).toEqual(50000n);
    });

    /* FIX PRICE SALES */

    it('should deploy ton simple sale', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_SALE)!.otherData as TonSimpleSaleDeployData;
        let price = toNano('5000');
        let validUntil = blockchain.now! + 300;
        
        // Decline if domain name is incorrect
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_SALE, 
                DOMAIN_NAMES[1],
                TonSimpleSale.deployPayload(price, validUntil),
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if price is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_SALE, 
                DOMAIN_NAMES[0],
                TonSimpleSale.deployPayload(toNano('0.19'), validUntil),
            ),
            toNano('0.5')
        );        
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if valid until is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_SALE, 
                DOMAIN_NAMES[0],
                TonSimpleSale.deployPayload(price, validUntil - 1),
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Deploy
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_SALE, 
                DOMAIN_NAMES[0],
                TonSimpleSale.deployPayload(price, validUntil),
            ),
            toNano('0.2')  // 0.059 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let fixPriceSaleAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(fixPriceSaleAddress.toString());
        let fixPriceSale = blockchain.openContract(TonSimpleSale.createFromAddress(fixPriceSaleAddress));

        let fixPriceSaleConfig = await fixPriceSale.getStorageData();
        expect(fixPriceSaleConfig.domainAddress!.toString()).toEqual(domains[0].address.toString());
        expect(fixPriceSaleConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(fixPriceSaleConfig.price).toEqual(price);
        expect(fixPriceSaleConfig.validUntil).toEqual(validUntil);
        expect(fixPriceSaleConfig.state).toEqual(TonSimpleSale.STATE_ACTIVE);
        expect(fixPriceSaleConfig.commission).toEqual(BigInt(Math.min(Number(price * BigInt(deployData.commissionFactor) / BigInt(COMMISSION_DIVIDER)), Number(deployData.maxCommission))));
    });
    
    it('should deploy jetton simple sale', async () => {
        let price = 100n * 10n ** 3n;
        let validUntil = blockchain.now! + 300;
        let isWeb3 = true;
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE)!.otherData as JettonSimpleSaleDeployData;

        // Deploy
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE, 
                DOMAIN_NAMES[0], 
                JettonSimpleSale.deployPayload(isWeb3, price, validUntil)
            ),
            toNano('0.3')  // 0.059 returns
        );

        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let jettonSimpleSaleAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(jettonSimpleSaleAddress.toString());
        let jettonSimpleSale = blockchain.openContract(JettonSimpleSale.createFromAddress(jettonSimpleSaleAddress));
        
        let jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.domainAddress!.toString()).toEqual(domains[0].address.toString());
        expect(jettonSimpleSaleConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(jettonSimpleSaleConfig.price).toEqual(price);
        expect(jettonSimpleSaleConfig.validUntil).toEqual(validUntil);
        expect(jettonSimpleSaleConfig.state).toEqual(JettonSimpleSale.STATE_ACTIVE);
        expect(jettonSimpleSaleConfig.commission).toEqual(BigInt(Math.min(Number(price * BigInt(deployData.commissionFactorWeb3) / BigInt(COMMISSION_DIVIDER)), Number(deployData.maxCommissionWeb3))));
        expect(jettonSimpleSaleConfig.jettonMinterAddress.toString()).toEqual(isWeb3 ? web3Minter.address.toString() : usdtMinter.address.toString());
        
        let saleJettonWalletAddress = jettonSimpleSaleConfig.jettonWalletAddress!;
        expect(saleJettonWalletAddress.toString()).toEqual((await web3Minter.getWalletAddress(jettonSimpleSale.address)).toString());
    });

    it('should deploy ton multiple sale', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_MULTIPLE_SALE)!.otherData as TonMultipleSaleDeployData;
        const domainAddresses = domains.map((x) => x.address);
        let price = toNano('500');
        let validUntil = blockchain.now! + 600;

        // Decline if price is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.5'), Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, 
            TonMultipleSale.deployPayload(domainAddresses, deployData.minPrice - 1n, validUntil)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.PRICE_TOO_LOW,
        });

        // Decline if valid until is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.5'), Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, 
            TonMultipleSale.deployPayload(domainAddresses, price, blockchain.now! + deployData.minDuration - 1)
        );        
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.INCORRECT_VALID_UNTIL,
        });

        // Accept
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.2'), // 0.093 returns
            Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, 
            TonMultipleSale.deployPayload(domainAddresses, price, validUntil)
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: seller.address,
            op: OpCodes.EXCESSES,
        });

        let multipleSaleAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        let multipleSale = blockchain.openContract(TonMultipleSale.createFromAddress(multipleSaleAddress));
        let multipleSaleConfig = await multipleSale.getStorageData();
        expect(multipleSaleConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(multipleSaleConfig.price).toEqual(price);
        expect(multipleSaleConfig.validUntil).toEqual(validUntil);
        expect(multipleSaleConfig.state).toEqual(TonMultipleSale.STATE_ACTIVE);
        expect(multipleSaleConfig.domainsTotal).toEqual(domains.length);
        for (let domain of domains) {
            expect(multipleSaleConfig.domainsDict.get(domain.address)).toBe(0);
        }
    });

    it('should deploy jetton multiple sale', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE)!.otherData as JettonMultipleSaleDeployData;
        const domainAddresses = domains.map((x) => x.address);
        let price = toNano('500');
        let validUntil = blockchain.now! + 600;
        const isWeb3 = false;

        // Decline if price is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.5'), Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, 
            JettonMultipleSale.deployPayload(isWeb3, domainAddresses, deployData.minPriceUsdt - 1n, validUntil)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.PRICE_TOO_LOW,
        });

        // Decline if valid until is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.5'), Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, 
            JettonMultipleSale.deployPayload(isWeb3, domainAddresses, price, blockchain.now! + deployData.minDurationWeb3 - 1)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.INCORRECT_VALID_UNTIL,
        });

        // Accept
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), toNano('0.2'), // 0.093 returns
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, 
            JettonMultipleSale.deployPayload(isWeb3, domainAddresses, price, validUntil)
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: seller.address,
            op: OpCodes.EXCESSES,
        });

        let multipleSaleAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        let multipleSale = blockchain.openContract(JettonMultipleSale.createFromAddress(multipleSaleAddress));
        let multipleSaleConfig = await multipleSale.getStorageData();
        expect(multipleSaleConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(multipleSaleConfig.price).toEqual(price);
        expect(multipleSaleConfig.validUntil).toEqual(validUntil);
        expect(multipleSaleConfig.state).toEqual(JettonMultipleSale.STATE_ACTIVE);
        expect(multipleSaleConfig.domainsTotal).toEqual(domains.length);

        for (let domain of domains) {
            expect(multipleSaleConfig.domainsDict.get(domain.address)).toBe(0);
        }
    });

    /* AUCTIONS */

    it('should deploy ton simple auction', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION)!.otherData as TonSimpleAuctionDeployData;
        let startTime = blockchain.now! + 600;
        let endTime = startTime + 430;
        let minBidValue = toNano('5');
        let maxBidValue = toNano('1000');
        let minBidIncrement = 1010;  // 10%
        let timeIncrement = 420;  // 7 min

        // Decline if end time is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    startTime + deployData.minTimeIncrement - 1, 
                    minBidValue, 
                    maxBidValue, 
                    minBidIncrement, 
                    timeIncrement,
                    false
                )
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if min bid is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    startTime, 
                    deployData.minPrice - 1n, 
                    maxBidValue, 
                    minBidIncrement, 
                    timeIncrement,
                    false
                )
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if max bid is incorrect
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    endTime, 
                    minBidValue, 
                    minBidValue, 
                    minBidIncrement, 
                    timeIncrement,
                    false
                )
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if min bid increment is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    endTime, 
                    minBidValue, 
                    maxBidValue, 
                    0, 
                    timeIncrement,
                    false
                )
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Decline if time increment is too low
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, null, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    endTime, 
                    minBidValue, 
                    maxBidValue, 
                    0, 
                    deployData.minTimeIncrement - 1,
                    false
                )
            ),
            toNano('0.5')
        );
        expect(transactionRes.transactions.length).toEqual(6);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(seller.address.toString());

        // Deploy
        let isDeferred = true;
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION,
                DOMAIN_NAMES[0],
                TonSimpleAuction.deployPayload(
                    startTime, 
                    endTime, 
                    minBidValue, 
                    maxBidValue, 
                    minBidIncrement, 
                    timeIncrement,
                    isDeferred
                )
            ),
            toNano('0.2')  // 0.075 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ 
            exitCode(x) { return Boolean(x) },
            actionResultCode(x) { return Boolean(x) },
        });

        let auctionAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(auctionAddress.toString());
        let auction = blockchain.openContract(TonSimpleAuction.createFromAddress(auctionAddress));
        let auctionConfig = await auction.getStorageData();
        expect(auctionConfig.domainAddress!.toString()).toEqual(domains[0].address.toString());
        expect(auctionConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(auctionConfig.startTime).toEqual(startTime);
        expect(auctionConfig.endTime).toEqual(endTime);
        expect(auctionConfig.minBidValue).toEqual(minBidValue);
        expect(auctionConfig.maxBidValue).toEqual(maxBidValue);
        expect(auctionConfig.minBidIncrement).toEqual(minBidIncrement);
        expect(auctionConfig.timeIncrement).toEqual(timeIncrement);
        expect(auctionConfig.isDeferred).toEqual(isDeferred);   
    });

    it('should deploy jetton simple auction', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_SIMPLE_AUCTION)!.otherData as JettonSimpleAuctionDeployData;
        let startTime = blockchain.now! + 600;
        let endTime = startTime + 430;
        let minBidValue = 50n * 10n ** 3n; 
        let maxBidValue = 100n * 10n ** 3n;
        let minBidIncrement = 1010;  // 10%
        let timeIncrement = 420;  // 7 min
        let isWeb3 = true;
        let isDeferred = true;
        // Deploy
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, Marketplace.DeployOpCodes.JETTON_SIMPLE_AUCTION, DOMAIN_NAMES[0],
                JettonSimpleAuction.deployPayload(isWeb3, startTime, endTime, minBidValue, maxBidValue, minBidIncrement, timeIncrement, isDeferred)
            ),
            toNano('0.25')  // 0.075 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ 
            exitCode(x) { return Boolean(x) },
            actionResultCode(x) { return Boolean(x) },
        });

        let auctionAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(auctionAddress.toString());
        let auction = blockchain.openContract(JettonSimpleAuction.createFromAddress(auctionAddress));
        let auctionConfig = await auction.getStorageData();
        expect(auctionConfig.domainAddress!.toString()).toEqual(domains[0].address.toString());
        expect(auctionConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(auctionConfig.startTime).toEqual(startTime);
        expect(auctionConfig.endTime).toEqual(endTime);
        expect(auctionConfig.minBidValue).toEqual(minBidValue);
        expect(auctionConfig.maxBidValue).toEqual(maxBidValue);
        expect(auctionConfig.minBidIncrement).toEqual(minBidIncrement);
        expect(auctionConfig.timeIncrement).toEqual(timeIncrement);
        expect(auctionConfig.commissionFactor).toEqual(deployData.commissionFactorWeb3);
        expect(auctionConfig.maxCommission).toEqual(deployData.maxCommissionWeb3);
        expect(auctionConfig.jettonMinterAddress.toString()).toEqual(isWeb3 ? web3Minter.address.toString() : usdtMinter.address.toString());
        expect(auctionConfig.isDeferred).toEqual(isDeferred);

        let auctionJettonWalletAddress = auctionConfig.jettonWalletAddress!;
        expect(auctionJettonWalletAddress.toString()).toEqual((await web3Minter.getWalletAddress(auction.address)).toString());

    });

    it('should deploy ton multiple auction', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION)!.otherData as TonSimpleAuctionDeployData;
        const domainAddresses = domains.map((x) => x.address);
        let startTime = blockchain.now! + 600;
        let endTime = startTime + 430;
        let minBidValue = toNano('5');
        let maxBidValue = toNano('1000');
        let minBidIncrement = 1050;  // 5% minimum increment
        let timeIncrement = 420;  // 7 min

        // Decline if end time is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(), 
            toNano('0.5'), 
            Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION, 
            TonMultipleAuction.deployPayload(
                domainAddresses,
                startTime,
                startTime + deployData.minTimeIncrement - 1,
                minBidValue,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.INCORRECT_TIME_RANGE
        });

        // Decline if min bid is too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.5'),
            Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION,
            TonMultipleAuction.deployPayload(
                domainAddresses,
                startTime,
                endTime,
                deployData.minPrice - 1n,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.PRICE_TOO_LOW
        });

        // Decline if max bid is incorrect
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.5'),
            Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION,
            TonMultipleAuction.deployPayload(
                domainAddresses,
                startTime,
                endTime,
                minBidValue,
                minBidValue - 1n,
                minBidIncrement,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: marketplace.address,
            exitCode: Exceptions.PRICE_TOO_LOW
        });

        // Deploy successfully
        let isDeferred = true;
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.2'),
            Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION,
            TonMultipleAuction.deployPayload(
                domainAddresses,
                startTime,
                endTime,
                minBidValue,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                isDeferred
            )
        );

        let auctionAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        let auction = blockchain.openContract(TonMultipleAuction.createFromAddress(auctionAddress));
        let auctionConfig = await auction.getStorageData();

        expect(auctionConfig.sellerAddress.toString()).toEqual(seller.address.toString());
        expect(auctionConfig.startTime).toEqual(startTime);
        expect(auctionConfig.endTime).toEqual(endTime);
        expect(auctionConfig.minBidValue).toEqual(minBidValue);
        expect(auctionConfig.maxBidValue).toEqual(maxBidValue);
        expect(auctionConfig.minBidIncrement).toEqual(minBidIncrement);
        expect(auctionConfig.timeIncrement).toEqual(timeIncrement);
        expect(auctionConfig.state).toEqual(TonMultipleAuction.STATE_ACTIVE);
        expect(auctionConfig.domainsTotal).toEqual(DOMAIN_NAMES.length);
        expect(auctionConfig.domainsReceived).toEqual(0);
        expect(auctionConfig.isDeferred).toEqual(isDeferred);

        // Verify commission settings
        expect(auctionConfig.commissionFactor).toEqual(deployData.commissionFactor);
        expect(auctionConfig.maxCommission).toEqual(deployData.maxCommission);
    });

    it('should deploy jetton multiple auction correctly', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION)!.otherData as JettonSimpleAuctionDeployData;
        const domainAddresses = domains.map((x) => x.address);
        const startTime = blockchain.now! + 600;
        const endTime = startTime + 3600; // 1 hour auction
        const minBidValue = 50n * 10n ** 3n;
        const maxBidValue = 100n * 10n ** 3n;
        const minBidIncrement = 1050; // 5% minimum increment
        const timeIncrement = 300; // 5 minutes extension
        
        // Test with Web3 tokens
        let isWeb3 = true;
        let isDeferred = true;
        let transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses,
                isWeb3,
                startTime,
                endTime,
                minBidValue,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                isDeferred
            )
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        const auctionAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        const auction = blockchain.openContract(JettonMultipleAuction.createFromAddress(auctionAddress));
        let config = await auction.getStorageData();

        // Verify basic configuration
        expect(config.state).toEqual(JettonMultipleAuction.STATE_ACTIVE);
        expect(config.sellerAddress.toString()).toEqual(seller.address.toString());
        expect(config.startTime).toEqual(startTime);
        expect(config.endTime).toEqual(endTime);
        expect(config.minBidValue).toEqual(minBidValue);
        expect(config.maxBidValue).toEqual(maxBidValue);
        expect(config.minBidIncrement).toEqual(minBidIncrement);
        expect(config.timeIncrement).toEqual(timeIncrement);
        expect(config.isDeferred).toEqual(isDeferred);

        // Verify Web3 specific settings
        expect(config.jettonMinterAddress.toString()).toEqual(web3Minter.address.toString());
        expect(config.commissionFactor).toEqual(deployData.commissionFactorWeb3);
        expect(config.maxCommission).toEqual(deployData.maxCommissionWeb3);

        // Verify domains configuration
        expect(config.domainsTotal).toEqual(DOMAIN_NAMES.length);
        expect(config.domainsReceived).toEqual(0);
        for (let domain of domains) {
            expect(config.domainsDict.get(domain.address)).toBe(0);
        }

        // Test with USDT tokens
        isWeb3 = false;
        isDeferred = false;
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses.slice(0, 2),
                isWeb3,
                startTime,
                endTime,
                minBidValue * 10n ** 3n,
                maxBidValue * 10n ** 3n,
                minBidIncrement,
                timeIncrement,
                isDeferred
            )
        );

        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        const usdtAuctionAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
        const usdtAuction = blockchain.openContract(JettonMultipleAuction.createFromAddress(usdtAuctionAddress));
        config = await usdtAuction.getStorageData();

        expect(config.jettonMinterAddress.toString()).toEqual(usdtMinter.address.toString());
        expect(config.commissionFactor).toEqual(deployData.commissionFactorUsdt);
        expect(config.maxCommission).toEqual(deployData.maxCommissionUsdt);
        expect(config.isDeferred).toEqual(isDeferred);
        // Transfer domains
        for (let domain of domains.slice(0, 2)) {
            await domain.sendTransfer(
                seller.getSender(),
                auctionAddress,
                seller.address,
                null,
                toNano('0.05')
            );
        }

        // Verify auction state after transfers
        config = await auction.getStorageData();
        expect(config.state).toEqual(JettonMultipleAuction.STATE_ACTIVE);
        expect(config.domainsReceived).toEqual(2);
        // expect(config.jettonWalletAddress?.toString()).toEqual(
        //     (await web3Minter.getWalletAddress(auction.address)).toString()
        // );
    });

    it('should handle jetton multiple auction error cases', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION)!.otherData as JettonSimpleAuctionDeployData;
        const domainAddresses = domains.map((x) => x.address);
        const startTime = blockchain.now! + 600;
        const endTime = startTime + 3600;
        const minBidValue = 50n * 10n ** 3n;
        const maxBidValue = 100n * 10n ** 3n;
        const minBidIncrement = 1050;
        const timeIncrement = 300;
        const isWeb3 = true;

        // Test invalid time range
        let transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses.slice(0, 2),
                isWeb3,
                startTime,
                startTime + deployData.minTimeIncrementWeb3 - 1,
                minBidValue,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            exitCode: Exceptions.INCORRECT_TIME_RANGE
        });

        // Test price too low
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses.slice(0, 2),
                isWeb3,
                startTime,
                endTime,
                deployData.minPriceWeb3 - 1n,
                maxBidValue,
                minBidIncrement,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            exitCode: Exceptions.PRICE_TOO_LOW
        });

        // Test invalid bid increment
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses.slice(0, 2),
                isWeb3,
                startTime,
                endTime,
                minBidValue,
                maxBidValue,
                1000,
                timeIncrement,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            exitCode: Exceptions.INCORRECT_BID_INCREMENT
        });

        // Test invalid time increment
        transactionRes = await marketplace.sendDeployDeal(
            seller.getSender(),
            toNano('0.3'),
            Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION,
            JettonMultipleAuction.deployPayload(
                domainAddresses.slice(0, 2),
                isWeb3,
                startTime,
                endTime,
                minBidValue,
                maxBidValue,
                minBidIncrement,
                deployData.minTimeIncrementWeb3 - 1,
                false
            )
        );
        expect(transactionRes.transactions).toHaveTransaction({
            exitCode: Exceptions.INCORRECT_TIME_INCREMENT
        });
    });

    /* ADMIN COMMANDS */

    it('should update code & data', async () => {
        const tonSimpleSaleConfig: TonSimpleSaleConfig = {
            domainAddress: domains[0].address,
            sellerAddress: seller.address,
            price: toNano('1000'),
            state: TonSimpleSale.STATE_ACTIVE,
            commission: toNano('100'),
            createdAt: blockchain.now!,
            lastRenewalTime: blockchain.now!,
            validUntil: blockchain.now! + 300,
            buyerAddress: null,
            domainName: DOMAIN_NAMES[0],
            hotUntil: blockchain.now! + 300,
        }
        transactionRes = await marketplace.sendChangeCode(admin.getSender(), tonSimpleSaleCode, tonSimpleSaleConfigToCell(tonSimpleSaleConfig));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: marketplace.address,
            success: true,
        });
        expect(transactionRes.transactions[1].outActions![0].type).toEqual('setCode');
        expect(transactionRes.transactions[1].outActions![1].type).toEqual('sendMsg');
        const tonSimpleSale = blockchain.openContract(TonSimpleSale.createFromAddress(marketplace.address));
        expect((await tonSimpleSale.getStorageData()).hotUntil).toEqual(tonSimpleSaleConfig.hotUntil);
    });

    it('should send any message', async () => {
        // without state init
        transactionRes = await marketplace.sendSendAnyMessage(
            admin.getSender(),
            toNano('0.05'),
            buyer.address,
            beginCell().storeUint(0, 32).storeStringTail(`Test`).endCell(),
            null,
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: buyer.address,
            body: beginCell().storeUint(0, 32).storeStringTail(`Test`).endCell(),
            value(x) {
                return x! > toNano('0.04') && x! < toNano('0.05');
            },
            success: true,
        });

        // with state init
        const stateInit = packStateInit(
            marketplaceDeployerCode,
            beginCell().storeUint(0, 128).endCell(),
        );
        const testAddress = contractAddress(0, { code: marketplaceDeployerCode, data: beginCell().storeUint(0, 128).endCell() });
        transactionRes = await marketplace.sendSendAnyMessage(
            admin.getSender(),
            toNano('0.05'),
            buyer.address,
            beginCell().storeUint(0, 32).storeStringTail(`Test`).endCell(),
            stateInit,
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: testAddress,
            body: beginCell().storeUint(0, 32).storeStringTail(`Test`).endCell(),
            value(x) {
                return x! > toNano('0.04') && x! < toNano('0.05');
            },
            initCode: marketplaceDeployerCode,
            initData: beginCell().storeUint(0, 128).endCell(),
            deploy: true
        });
    });

    it('should withdraw ton', async () => {
        await marketplace.sendFillUpBalance(buyer.getSender(), toNano('10'));
        transactionRes = await marketplace.sendWithdrawSomeTon(admin.getSender(), 1, toNano('1'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: admin.address,
            value(x) {
                return x! > toNano('9') && x! < toNano('9.1');
            },
            success: true,
        });
    });

    it('should withdraw jetton', async () => {
        await web3BuyerWallet.sendTransfer(buyer.getSender(), toNano('100'), marketplace.address, buyer.address, 0n, null);
        const prevAdminBalance = await web3AdminWallet.getJettonBalance();
        transactionRes = await marketplace.sendWithdrawJetton(admin.getSender(), web3MarketplaceWallet.address, toNano('50'), 1);
        expect(await web3AdminWallet.getJettonBalance()).toEqual(prevAdminBalance + toNano('50'));
    });

    it('should send nft', async () => {
        await domains[0].sendTransfer(seller.getSender(), marketplace.address, seller.address, null, 0n);
        transactionRes = await marketplace.sendWithdrawNft(admin.getSender(), domains[0].address, 1);
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(admin.address.toString());
    });

    /* OTHER TESTS */

    it('should apply discount to ton purchase offer', async () => {
        let deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER)!.otherData as TonSimpleOfferDeployData;
        let price = toNano('500');
        let commission = price * BigInt(deployData.commissionFactor) / BigInt(COMMISSION_DIVIDER);
        let validUntil = blockchain.now! + 300;
        let notifySeller = false;

        // Accept
        transactionRes = await marketplace.sendDeployDeal(
            buyer.getSender(), 
            price + commission + toNano('0.1') * BigInt(notifySeller) + toNano('0.2'),  // 0.079 returns 
            Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, 
            TonSimpleOffer.deployPayload(price, validUntil, seller.address, DOMAIN_NAMES[0], notifySeller),
            secretKey,
            blockchain.now!,
            COMMISSION_DIVIDER * 0.05  // 5%
        );
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let purchaseOfferAddress = transactionRes.transactions[2 + Number(notifySeller)].inMessage!.info.dest! as Address;
        let purchaseOffer = blockchain.openContract(TonSimpleOffer.createFromAddress(purchaseOfferAddress));
        let purchaseOfferConfig = await purchaseOffer.getStorageData();
        expect(purchaseOfferConfig.commission).toEqual(price * BigInt(deployData.commissionFactor) / BigInt(COMMISSION_DIVIDER) * 95n / 100n);
        expect(purchaseOfferConfig.sellerAddress!.toString()).toEqual(seller.address.toString());
        expect(purchaseOfferConfig.buyerAddress!.toString()).toEqual(buyer.address.toString());
        expect(purchaseOfferConfig.price).toEqual(price);
        expect(purchaseOfferConfig.validUntil).toEqual(validUntil);
        expect(purchaseOfferConfig.state).toEqual(TonSimpleOffer.STATE_ACTIVE);
    });

    it('should apply discount to ton fix price sale', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_SALE)!.otherData as TonSimpleSaleDeployData;
        let price = toNano('5000');
        let validUntil = blockchain.now! + 300;

        // Deploy
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(seller.address, Marketplace.DeployOpCodes.TON_SIMPLE_SALE, DOMAIN_NAMES[0], beginCell().storeCoins(price).storeUint(validUntil, 32).endCell(), secretKey, blockchain.now!, COMMISSION_DIVIDER * 0.05),
            toNano('0.2')  // 0.059 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let fixPriceSaleAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(fixPriceSaleAddress.toString());
        let fixPriceSale = blockchain.openContract(TonSimpleSale.createFromAddress(fixPriceSaleAddress));
        
        let fixPriceSaleConfig = await fixPriceSale.getStorageData();
        let commissionWithoutDiscount = BigInt(Math.min(Number(price * BigInt(deployData.commissionFactor) / BigInt(COMMISSION_DIVIDER)), Number(deployData.maxCommission)));
        expect(fixPriceSaleConfig.commission).toEqual(commissionWithoutDiscount * 95n / 100n);
    });

    it('should apply discount to web3 simple sale', async () => {
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE)!.otherData as JettonSimpleSaleDeployData;
        let price = toNano('500');
        let validUntil = blockchain.now! + 300;
        let isWeb3 = true;

        // Deploy
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(
                seller.address, 
                Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE, 
                DOMAIN_NAMES[0], 
                JettonSimpleSale.deployPayload(isWeb3, price, validUntil),
                secretKey,
                blockchain.now!,
                COMMISSION_DIVIDER * 0.5
            ),
            toNano('0.3')  // 0.059 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });

        let jettonSimpleSaleAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(jettonSimpleSaleAddress.toString());
        let jettonSimpleSale = blockchain.openContract(JettonSimpleSale.createFromAddress(jettonSimpleSaleAddress));
        
        let jettonSimpleSaleConfig = await jettonSimpleSale.getStorageData();
        expect(jettonSimpleSaleConfig.commission).toEqual(0n);
    });


    it('should buy subscription', async () => {
        const subscriptionPeriod1 = ONE_DAY * 30;
        const subscriptionPeriod2 = ONE_YEAR;
        const subscriptionPrice1 = toNano('1');
        const subscriptionPrice2 = toNano('9');
        
        transactionRes = await marketplace.sendBuySubscription(buyer.getSender(), 1, subscriptionPeriod1, subscriptionPrice1, 0);
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.userSubscriptions!.get(buyer.address)!.endTime).toEqual(blockchain.now! + subscriptionPeriod1);
        
        transactionRes = await marketplace.sendBuySubscription(seller.getSender(), 1, subscriptionPeriod2, subscriptionPrice2, 0);
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.userSubscriptions!.get(seller.address)!.endTime).toEqual(blockchain.now! + subscriptionPeriod2);

        blockchain.now = blockchain.now! + subscriptionPeriod1 * 2;
        transactionRes = await marketplace.sendBuySubscription(buyer.getSender(), 1, subscriptionPeriod1, subscriptionPrice1, 0);
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.userSubscriptions!.get(buyer.address)!.endTime).toEqual(blockchain.now! + subscriptionPeriod1);

        transactionRes = await marketplace.sendBuySubscription(seller.getSender(), 1, subscriptionPeriod1, subscriptionPrice1, 0);
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.userSubscriptions!.get(seller.address)!.endTime).toEqual(blockchain.now! + subscriptionPeriod2 - subscriptionPeriod1);
    });

    it('should promote sales', async () => {
        // Deploy fix price sale
        const deployData = marketplaceConfig.deployInfos.get(Marketplace.DeployOpCodes.TON_SIMPLE_SALE)!.otherData as TonSimpleSaleDeployData;
        let price = toNano('5000');
        let validUntil = blockchain.now! + 300;
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), marketplace.address, seller.address, 
            Marketplace.deployDealWithNftTransferPayload(seller.address, Marketplace.DeployOpCodes.TON_SIMPLE_SALE, DOMAIN_NAMES[0], beginCell().storeCoins(price).storeUint(validUntil, 32).endCell(), secretKey, blockchain.now!, COMMISSION_DIVIDER * 0.05),
            toNano('0.2')  // 0.059 returns
        );
        expect(transactionRes.transactions.length).toEqual(7);
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        let fixPriceSaleAddress = transactionRes.transactions[5].inMessage!.info.dest! as Address;
        expect((await domains[0].getStorageData()).ownerAddress!.toString()).toEqual(fixPriceSaleAddress.toString());
        let fixPriceSale = blockchain.openContract(TonSimpleSale.createFromAddress(fixPriceSaleAddress));
        

        // Make hot & colored
        let hotPeriod = marketplaceConfig.promotionPrices.keys()[0];
        let hotPrice = marketplaceConfig.promotionPrices.get(hotPeriod)!.hotPrice;
        let coloredPeriod = marketplaceConfig.promotionPrices.keys()[1];
        let coloredPrice = marketplaceConfig.promotionPrices.get(coloredPeriod)!.coloredPrice;

        transactionRes = await web3SellerWallet.sendTransfer(seller.getSender(), hotPrice, marketplace.address, seller.address, toNano("0.05"), Marketplace.makeHotTransferPayload(fixPriceSaleAddress, hotPeriod));
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        transactionRes = await web3SellerWallet.sendTransfer(seller.getSender(), coloredPrice, marketplace.address, seller.address, toNano("0.05"), Marketplace.makeColoredTransferPayload(fixPriceSaleAddress, coloredPeriod));
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        // console.log(transactionRes.transactions[5].vmLogs);
        let fixPriceSaleConfig = await fixPriceSale.getStorageData();
        expect(fixPriceSaleConfig.hotUntil).toEqual(blockchain.now! + hotPeriod);
        expect(fixPriceSaleConfig.coloredUntil).toEqual(blockchain.now! + coloredPeriod);

        // Move up sale
        transactionRes = await web3SellerWallet.sendTransfer(seller.getSender(), marketplaceConfig.moveUpSalePrice, marketplace.address, seller.address, toNano("0.05"), Marketplace.moveUpSaleTransferPayload(fixPriceSaleAddress));
        expect(transactionRes.transactions).not.toHaveTransaction({ success: false });
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.currentTopSale!.toString()).toEqual(fixPriceSaleAddress.toString());
        expect(marketplaceConfig.collectedFeesDict!.get(web3MarketplaceWallet.address)!).toEqual(hotPrice + coloredPrice + marketplaceConfig.moveUpSalePrice);
    });

    it("should accept fees", async () => {
        marketplaceConfig = await marketplace.getStorageData();
        await admin.send({
            value: toNano('0.1') + 2000000n,
            to: marketplace.address,
            body: beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
        })
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), 100n, marketplace.address, buyer.address, toNano('0.02'),
                                            beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell());
        transactionRes = await web3BuyerWallet.sendTransfer(buyer.getSender(), 200n, marketplace.address, buyer.address, toNano('0.02'),
                                            beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell());
        marketplaceConfig = await marketplace.getStorageData();
        expect(marketplaceConfig.collectedFeesTon).toEqual(toNano('0.1'));
        expect(marketplaceConfig.collectedFeesDict!.get(usdtMarketplaceWallet.address)!).toEqual(100n);
        expect(marketplaceConfig.collectedFeesDict!.get(web3MarketplaceWallet.address)!).toEqual(200n);
    });
});

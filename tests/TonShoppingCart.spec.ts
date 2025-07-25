import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { DomainInfoValue, domainInfoValueParser, ShoppingCartSwapInfo, TonShoppingCart, TonShoppingCartConfig } from '../wrappers/TonShoppingCart';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { MIN_PRICE_START_TIME, ONE_DAY, Tons } from '../wrappers/helpers/constants';
import { TonSimpleSale, TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import { createDedustPools } from './helpers/createDedustPools';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';
import { JettonSimpleSale, JettonSimpleSaleConfig } from '../wrappers/JettonSimpleSale';


describe('TonShoppingCart', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;
    let tonShoppingCartCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;
    let tonSimpleSaleCode: Cell;
    let jettonSimpleSaleCode: Cell;

    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');

        tonShoppingCartCode = await compile('TonShoppingCart');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        tonSimpleSaleCode = await compile('TonSimpleSale');
        jettonSimpleSaleCode = await compile('JettonSimpleSale');
    });

    let blockchain: Blockchain;

    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;
    let dnsCollection: SandboxContract<DnsCollection>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtAdminWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let web3Minter: SandboxContract<JettonMinter>;
    let web3AdminWallet: SandboxContract<JettonWallet>;
    let web3SellerWallet: SandboxContract<JettonWallet>;

    let fixPriceSales: Array<SandboxContract<TonSimpleSale | JettonSimpleSale>>;
    let domains: Array<SandboxContract<Domain>>;

    let DOMAIN_NAMES: Array<string> = [];
    let domainConfigs: Array<DomainConfig>;
    let transactionRes: SendMessageResult;

    let tonShoppingCart: SandboxContract<TonShoppingCart>;

    let tonShoppingCartConfig: TonShoppingCartConfig;

    beforeEach(async () => {
        const domainsCount = 100;
        for (let i = 0; i < domainsCount; ++i) {
            DOMAIN_NAMES.push(Math.random().toFixed(10).slice(2) + ".ton");
        }
        
        fixPriceSales = [];
        domains = [];
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;
        
        admin = await blockchain.treasury('admin');
        marketplace = admin;
        
        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');

        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(10000), toNano("0.21"), toNano("0.5"));
        await usdtMinter.sendMint(admin.getSender(), admin.address, toNano(10000), toNano("0.21"), toNano("0.5"));
        usdtAdminWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));

        web3Minter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("web3").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await web3Minter.sendDeploy(admin.getSender(), toNano("0.05"));
        await web3Minter.sendMint(admin.getSender(), buyer.address, toNano(10000), toNano("0.21"), toNano("0.5"));
        await web3Minter.sendMint(admin.getSender(), admin.address, toNano(10000), toNano("0.21"), toNano("0.5"));
        web3AdminWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(admin.address)));
        web3SellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(seller.address)));

        dnsCollection = blockchain.openContract(DnsCollection.createFromConfig({
            content: beginCell().endCell(),
            nftItemCode: domainCode,
        } as DnsCollectionConfig, dnsCollectionCode));
        
        const dedustData = await createDedustPools(admin, blockchain, usdtMinter.address, usdtAdminWallet, web3Minter.address, web3AdminWallet);

        let totalCost = 0n;
        let sellerProfitTon = 0n;
        let sellerProfitUsdt = 0n;
        let sellerProfitWeb3 = 0n;
        let marketplaceProfitTon = 0n;
        let marketplaceProfitUsdt = 0n;
        let marketplaceProfitWeb3 = 0n;
        
        let realPrice = 0n;

        let domainsDict: Dictionary<Address, DomainInfoValue> = Dictionary.empty(Dictionary.Keys.Address(), domainInfoValueParser());
        for (let i = 0; i < domainsCount; ++i) {  // deploy domains
            const domainName = DOMAIN_NAMES[i];
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
            
            let domainPrice = (toNano('1') + BigInt(Math.floor(Number(toNano('10')) * Math.random()))) / 10n;
            realPrice += domainPrice;

            let saleContract: SandboxContract<TonSimpleSale | JettonSimpleSale>;
            let swapInfo: ShoppingCartSwapInfo | null = null;
            if (i % 3 == 0) {
                let fixPriceSaleConfig: TonSimpleSaleConfig = {
                    domainAddress,
                    sellerAddress: seller.address,
                    price: domainPrice,
                    state: TonSimpleSale.STATE_UNINIT,
                    commission: domainPrice / 10n,
                    createdAt: blockchain.now,
                    lastRenewalTime: blockchain.now,
                    validUntil: blockchain.now + ONE_DAY * 365,
                    buyerAddress: null,
                    domainName: domainName
                }
                sellerProfitTon += domainPrice - domainPrice / 10n;
                marketplaceProfitTon += domainPrice / 10n;
                domainPrice += TonSimpleSale.PURCHASE;
                saleContract = blockchain.openContract(TonSimpleSale.createFromConfig(fixPriceSaleConfig, tonSimpleSaleCode));
                totalCost += domainPrice + TonShoppingCart.PURCHASE + toNano('0.01');
            }
            else {
                let minterAddress: Address;
                if (i % 3 == 1) {
                    minterAddress = usdtMinter.address;
                    sellerProfitUsdt += domainPrice - domainPrice / 10n;
                    marketplaceProfitUsdt += domainPrice / 10n;
                    swapInfo = {
                        swapAmount: domainPrice * 11n / 10n,
                        poolAddress: dedustData.usdtTonPool.address,
                        requiredGas: JettonSimpleSale.PURCHASE + TonShoppingCart.PURCHASE
                    }
                }
                else {
                    minterAddress = web3Minter.address;
                    sellerProfitWeb3 += domainPrice - domainPrice / 10n;
                    marketplaceProfitWeb3 += domainPrice / 10n;
                    swapInfo = {
                        swapAmount: domainPrice * 11n / 10n,
                        poolAddress: dedustData.web3TonPool.address,
                        requiredGas: JettonSimpleSale.PURCHASE
                    }
                }
                let fixPriceSaleConfig: JettonSimpleSaleConfig = {
                    domainAddress,
                    sellerAddress: seller.address,
                    jettonMinterAddress: minterAddress,
                    price: domainPrice,
                    state: TonSimpleSale.STATE_UNINIT,
                    lastRenewalTime: blockchain.now,
                    createdAt: blockchain.now,
                    buyerAddress: null,
                    validUntil: blockchain.now + ONE_DAY * 365,
                    domainName: domainName,
                    commission: domainPrice / 10n,
                }
                saleContract = blockchain.openContract(JettonSimpleSale.createFromConfig(fixPriceSaleConfig, jettonSimpleSaleCode));
                totalCost += swapInfo!!.swapAmount + swapInfo!!.requiredGas + TonShoppingCart.PURCHASE + toNano('0.11');
            }
            transactionRes = await saleContract.sendDeploy(admin.getSender(), toNano('0.04'));
            // printTransactionFees(transactionRes.transactions);
            transactionRes = await domain.sendTransfer(seller.getSender(), saleContract.address, seller.address);
            // printTransactionFees(transactionRes.transactions);
            fixPriceSales.push(saleContract);
            domains.push(domain);
            domainsDict.set(domainAddress, {transferred: false, saleContractAddress: saleContract.address, price: domainPrice, swapInfo: swapInfo});
        }
        
        
        tonShoppingCartConfig = {
            ownerAddress: buyer.address,
            state: TonShoppingCart.STATE_UNINIT,
            domainsDict,
            commission: toNano("0.1"),
            domainsLeft: domains.length
        }
        totalCost += TonShoppingCart.DEPLOY + tonShoppingCartConfig.commission;
        tonShoppingCart = blockchain.openContract(TonShoppingCart.createFromConfig(tonShoppingCartConfig, tonShoppingCartCode));
        
        let buyerBalance = await buyer.getBalance();
        let sellerBalance = await seller.getBalance();
        transactionRes = await tonShoppingCart.sendDeploy(buyer.getSender(), totalCost);
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonShoppingCart.address,
            to: buyer.address,
            body: beginCell().storeUint(0, 32).storeStringTail("Purchase completed").endCell()
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonShoppingCart.address,
            to: marketplace.address,
            value: tonShoppingCartConfig.commission
        })
        for (let domain of domains) {   
            let domainConfig = await domain.getStorageData();
            expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address!!.toString());
        }
        expect(transactionRes.transactions).not.toHaveTransaction({
            exitCode(x) {return Boolean(x) ;}
        });
        
        expect(await (await blockchain.getContract(tonShoppingCart.address)).balance).toEqual(0n);
        // Траты газа за покупку n доменов (без свапов): 1 -> 0.046; 2 -> 0.073; 3 -> 0.1; 4 -> 0.13; 5 -> 0.1574; 50 -> ~1.4; 100: ~2.83
        // Траты газа за покупку n доменов (только свапы): 1 -> 0.17; 2 -> 0.35; 3 -> 0.57; 4 -> 0.8; 5 -> 1.04; 50 -> ~10.18; 100: ~20.03
        // console.log(Number(- await buyer.getBalance() + buyerBalance - sellerProfit - marketplaceProfit - tonShoppingCartConfig.commission) / 1e9);
        expect(sellerProfitTon - toNano('0.001') <= await seller.getBalance() - sellerBalance && await seller.getBalance() - sellerBalance <= sellerProfitTon + toNano('0.039') * BigInt(domains.length)).toBeTruthy();
        
        expect(await usdtSellerWallet.getJettonBalance()).toEqual(sellerProfitUsdt);
        expect(await web3SellerWallet.getJettonBalance()).toEqual(sellerProfitWeb3);

        const buyerBalanceChange = buyerBalance - await buyer.getBalance();
        console.log("Domains count:", domainsCount, "\nBlockchain fees:", Number(buyerBalanceChange - realPrice - tonShoppingCartConfig.commission) / 1e9, "TON");
    });
    
    it('should work :)', async () => {
        // the check is done inside beforeEach
        // blockchain and tonShoppingCart are ready to use
    });
});

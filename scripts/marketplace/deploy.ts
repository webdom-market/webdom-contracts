import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { DeployInfoValue, promotionPricesValueParser, Marketplace, MarketplaceConfig, marketplaceConfigToCell } from '../../wrappers/Marketplace';
import { MarketplaceDeployer } from '../../wrappers/MarketplaceDeployer';
import { compile, NetworkProvider } from '@ton/blueprint';
import { TonSimpleSaleDeployData } from '../../wrappers/TonSimpleSale';
import { TonSimpleAuctionDeployData } from '../../wrappers/TonSimpleAuction';
import { TonMultipleSaleDeployData } from '../../wrappers/TonMultipleSale';
import { TonSimpleOfferDeployData } from '../../wrappers/TonSimpleOffer';
import {  DomainSwapDeployData } from '../../wrappers/DomainSwap';
import fs from 'fs';
import { ONE_DAY, ONE_YEAR } from '../../wrappers/helpers/constants';
import { Addresses } from '../../wrappers/helpers/constants';
import { JettonSimpleAuctionDeployData } from '../../wrappers/JettonSimpleAuction';
import { JettonSimpleSaleDeployData } from '../../wrappers/JettonSimpleSale';
import { JettonMinter } from '../../wrappers/JettonMinter';
import { getDeployFunctionCode } from '../../wrappers/helpers/getDeployFunctionCode';
import { TonMultipleAuctionDeployData } from '../../wrappers/TonMultipleAuction';
import { MultipleOfferDeployData } from '../../wrappers/MultipleOffer';


export async function run(provider: NetworkProvider) {
    const contractCode = Cell.fromBoc(fs.readFileSync('/Users/arkadiystena/Desktop/webdom/webdom-contracts/contracts/marketplace/vanity-address.cell'))[0];
    const salt = Buffer.from('9cbafdbf209ae1174b696544314d27f0d1fe7916c64ca9099c21cbb3cad1a7b0', 'hex');
    const owner = Address.parseFriendly('UQCovSj8c8Ik1I-RZt7dbIOEulYe-MfJ2SN5eMhxwfACvp7x').address
    const contractData = beginCell().storeUint(0, 5).storeAddress(owner).storeBuffer(salt).endCell(); 
    const marketplaceDeployer = provider.open(MarketplaceDeployer.createFromData(contractCode, contractData));
    console.log('Marketplace address', marketplaceDeployer.address);

    let deployInfos: Dictionary<number, DeployInfoValue> = Dictionary.empty();

    deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, {
        dealCode: await compile('TonSimpleOffer'),
        deployFunctionCode: getDeployFunctionCode('TonSimpleOffer'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: TonSimpleOfferDeployData.fromConfig(
            toNano('0.4'),  // minPrice
            400,            // commissionFactor (4%)
            toNano('200'),  // maxCommission
            300             // minDuration (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER, {
        dealCode: await compile('JettonSimpleOffer'),
        deployFunctionCode: getDeployFunctionCode('JettonSimpleOffer'),
        deployType: Marketplace.DeployTypes.JETTON_TRANSFER,
        deployFee: toNano('0.05'),
        otherData: JettonSimpleSaleDeployData.fromConfig(
            2n * 10n ** 6n,    // minPriceUsdt
            400,               // commissionFactorUsdt (4%)
            800n * 10n ** 6n,  // maxCommissionUsdt
            300,               // minDuration (5 minutes)

            20n * 10n ** 3n,    // minPriceWeb3
            200,               // commissionFactorWeb3 (2%)
            8000n * 10n ** 3n, // maxCommissionWeb3
            300                // minDuration (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.MULTIPLE_OFFER, {
        dealCode: await compile('MultipleOffer'),
        deployFunctionCode: getDeployFunctionCode('MultipleOffer'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: MultipleOfferDeployData.fromConfig(
            400,               // commissionFactor (4%)
            200,               // web3CommissionFactor (2%)
        ),
    });

    deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_SALE, {
        dealCode: await compile('TonSimpleSale'),
        deployFunctionCode: getDeployFunctionCode('TonSimpleSale'),
        deployType: Marketplace.DeployTypes.NFT_TRANSFER,
        deployFee: toNano('0.0'),
        otherData: TonSimpleSaleDeployData.fromConfig(
            toNano('0.4'),  // minPrice
            400,            // commissionFactor (4%)
            toNano('200'),  // maxCommission
            300             // minDuration (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE, {
        dealCode: await compile('JettonSimpleSale'),
        deployFunctionCode: getDeployFunctionCode('JettonSimpleSale'),
        deployType: Marketplace.DeployTypes.NFT_TRANSFER,
        deployFee: toNano('0.0'),
        otherData: JettonSimpleSaleDeployData.fromConfig(
            2n * 10n ** 6n,    // minPriceUsdt
            400,               // commissionFactorUsdt (4%)
            800n * 10n ** 6n,  // maxCommissionUsdt
            300,               // minDuration (5 minutes)

            20n * 10n ** 3n,   // minPriceWeb3
            200,               // commissionFactorWeb3 (2%)
            8000n * 10n ** 3n, // minDuration (5 minutes)
            300                // minDuration (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, {
        dealCode: await compile('TonMultipleSale'),
        deployFunctionCode: getDeployFunctionCode('TonMultipleSale'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: TonMultipleSaleDeployData.fromConfig(
            toNano('0.4'),    // minPrice
            400,            // commissionFactor (4%)
            toNano('200'),   // maxCommission
            600             // minDuration (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, {
        dealCode: await compile('JettonMultipleSale'),
        deployFunctionCode: getDeployFunctionCode('JettonMultipleSale'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: JettonSimpleSaleDeployData.fromConfig(
            2n * 10n ** 6n,    // minPriceUsdt
            400,               // commissionFactorUsdt (4%)
            800n * 10n ** 6n,  // maxCommissionUsdt
            300,               // minDuration (5 minutes)

            20n * 10n ** 3n,    // minPriceWeb3
            200,               // commissionFactorWeb3 (2%)
            8000n * 10n ** 3n, // minDuration (5 minutes)
            300                // minDuration (5 minutes)
        ),
    });


    deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION, {
        dealCode: await compile('TonSimpleAuction'),
        deployFunctionCode: getDeployFunctionCode('TonSimpleAuction'),
        deployType: Marketplace.DeployTypes.NFT_TRANSFER,
        deployFee: toNano('0.0'),
        otherData: TonSimpleAuctionDeployData.fromConfig(
            toNano('0.4'),  // minPrice
            400,            // commissionFactor (4%)
            toNano('50'),   // maxCommission
            300             // minTimeIncrement (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_AUCTION, {
        dealCode: await compile('JettonSimpleAuction'),
        deployFunctionCode: getDeployFunctionCode('JettonSimpleAuction'),
        deployType: Marketplace.DeployTypes.NFT_TRANSFER,
        deployFee: toNano('0.0'),
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
        dealCode: await compile('TonMultipleAuction'),
        deployFunctionCode: getDeployFunctionCode('TonMultipleAuction'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: TonMultipleAuctionDeployData.fromConfig(
            toNano('0.4'),  // minPrice
            400,            // commissionFactor (4%)
            toNano('200'),  // maxCommission
            300             // minTimeIncrement (5 minutes)
        ),
    });
    deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION, {
        dealCode: await compile('JettonMultipleAuction'),
        deployFunctionCode: getDeployFunctionCode('JettonMultipleAuction'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: JettonSimpleAuctionDeployData.fromConfig(
            2n * 10n ** 6n,    // minPriceUsdt
            400,               // commissionFactorUsdt (4%)
            800n * 10n ** 6n,  // maxCommissionUsdt
            300,               // minTimeIncrement (5 minutes)
    
            20n * 10n ** 3n,   // minPriceWeb3
            200,               // commissionFactorWeb3 (2%)
            8000n * 10n ** 3n, // maxCommissionWeb3
            300                // minTimeIncrement (5 minutes)
        ),
    });

    deployInfos.set(Marketplace.DeployOpCodes.DOMAIN_SWAP, {
        dealCode: await compile('DomainSwap'),
        deployFunctionCode: getDeployFunctionCode('DomainSwap'),
        deployType: Marketplace.DeployTypes.SIMPLE,
        deployFee: toNano('0.05'),
        otherData: DomainSwapDeployData.fromConfig(
            toNano('0.5'),   // completionCommission
            600              // minDuration (10 minutes)
        ),
    });
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

    const marketplaceConfig = {
        ownerAddress: owner,
        publicKey: 0xe98d001ef7371d99c374f9986ce74dcebaa7ee455ee00f1db8d0631405af8bdfn,
        deployInfos,
        
        userSubscriptions: undefined,
        subscriptionsInfo,

        moveUpSalePrice: 6000n,
        currentTopSale: Address.parse("EQAxIjlIAtkNTKQ9dU7GTkf17aFrXaUMrhE6cvxDDpGOEr9l"),

        web3WalletAddress: Address.parse("EQDSSsVhJGk6BtTMeHwlyxcCrpYySCkEVJQ3OwDYBBgns5ja"),
        
        collectedFeesTon: 0n,
        collectedFeesDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.BigVarUint(4)),

        promotionPrices,
    };

    const transactionRes = await marketplaceDeployer.sendDeploy(provider.sender(), toNano('0.05'), await compile('Marketplace'), marketplaceConfigToCell(marketplaceConfig, false));
}
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { TonSimpleSale, TonSimpleSaleDeployData } from '../../wrappers/TonSimpleSale';
import { compile, NetworkProvider } from '@ton/blueprint';
import { deployInfoValueParser, Marketplace, marketplaceConfigToCell, subscriptionInfoValueParser, userSubscriptionValueParser } from '../../wrappers/Marketplace';
import { Addresses, ONE_DAY, ONE_YEAR } from '../../wrappers/helpers/constants';
import { Domain } from '../../wrappers/Domain';
import { TonSimpleAuctionDeployData } from '../../wrappers/TonSimpleAuction';
import { TonMultipleSaleDeployData } from '../../wrappers/TonMultipleSale';
import { TonSimpleOfferDeployData } from '../../wrappers/TonSimpleOffer';
import { DomainSwap, DomainSwapDeployData } from '../../wrappers/DomainSwap';
import { JettonSimpleAuctionDeployData } from '../../wrappers/JettonSimpleAuction';
import { JettonSimpleSaleDeployData } from '../../wrappers/JettonSimpleSale';
import { JettonSimpleOfferDeployData } from '../../wrappers/JettonSimpleOffer';
import { TonMultipleAuctionDeployData } from '../../wrappers/TonMultipleAuction';
import { JettonMultipleAuctionDeployData } from '../../wrappers/JettonMultipleAuction';
import { MultipleOfferDeployData } from '../../wrappers/MultipleOffer';
import { getDeployFunctionCode } from '../../wrappers/helpers/getDeployFunctionCode';

export async function run(provider: NetworkProvider) {
    let marketplace = provider.open(Marketplace.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM")));
    const marketplaceConfig = await marketplace.getStorageData();
    // marketplaceConfig.deployInfos = Dictionary.empty(Dictionary.Keys.Uint(32), deployInfoValueParser());
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, {
    //     dealCode: await compile('TonSimpleOffer'),
    //     deployFunctionCode: getDeployFunctionCode('TonSimpleOffer'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: TonSimpleOfferDeployData.fromConfig(
    //         toNano('0.4'),  // minPrice
    //         400,            // commissionFactor (4%)
    //         toNano('200'),  // maxCommission
    //         300             // minDuration (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER, {
    //     dealCode: await compile('JettonSimpleOffer'),
    //     deployFunctionCode: getDeployFunctionCode('JettonSimpleOffer'),
    //     deployType: Marketplace.DeployTypes.JETTON_TRANSFER,
    //     deployFee: toNano('0.05'),
    //     otherData: JettonSimpleSaleDeployData.fromConfig(
    //         2n * 10n ** 6n,    // minPriceUsdt
    //         400,               // commissionFactorUsdt (4%)
    //         800n * 10n ** 6n,  // maxCommissionUsdt
    //         300,               // minDuration (5 minutes)

    //         20n * 10n ** 3n,    // minPriceWeb3
    //         200,               // commissionFactorWeb3 (2%)
    //         8000n * 10n ** 3n, // maxCommissionWeb3
    //         300                // minDuration (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.MULTIPLE_OFFER, {
    //     dealCode: await compile('MultipleOffer'),
    //     deployFunctionCode: getDeployFunctionCode('MultipleOffer'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: MultipleOfferDeployData.fromConfig(
    //         400,               // commissionFactor (4%)
    //         200,               // web3CommissionFactor (2%)
    //     ),
    // });

    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_SALE, {
    //     dealCode: await compile('TonSimpleSale'),
    //     deployFunctionCode: getDeployFunctionCode('TonSimpleSale'),
    //     deployType: Marketplace.DeployTypes.NFT_TRANSFER,
    //     deployFee: toNano('0.0'),
    //     otherData: TonSimpleSaleDeployData.fromConfig(
    //         toNano('0.4'),  // minPrice
    //         400,            // commissionFactor (4%)
    //         toNano('200'),  // maxCommission
    //         300             // minDuration (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_SALE, {
    //     dealCode: await compile('JettonSimpleSale'),
    //     deployFunctionCode: getDeployFunctionCode('JettonSimpleSale'),
    //     deployType: Marketplace.DeployTypes.NFT_TRANSFER,
    //     deployFee: toNano('0.0'),
    //     otherData: JettonSimpleSaleDeployData.fromConfig(
    //         2n * 10n ** 6n,    // minPriceUsdt
    //         400,               // commissionFactorUsdt (4%)
    //         800n * 10n ** 6n,  // maxCommissionUsdt
    //         300,               // minDuration (5 minutes)

    //         20n * 10n ** 3n,   // minPriceWeb3
    //         200,               // commissionFactorWeb3 (2%)
    //         8000n * 10n ** 3n, // minDuration (5 minutes)
    //         300                // minDuration (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.TON_MULTIPLE_SALE, {
    //     dealCode: await compile('TonMultipleSale'),
    //     deployFunctionCode: getDeployFunctionCode('TonMultipleSale'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: TonMultipleSaleDeployData.fromConfig(
    //         toNano('0.4'),    // minPrice
    //         400,            // commissionFactor (4%)
    //         toNano('200'),   // maxCommission
    //         600             // minDuration (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_SALE, {
    //     dealCode: await compile('JettonMultipleSale'),
    //     deployFunctionCode: getDeployFunctionCode('JettonMultipleSale'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: JettonSimpleSaleDeployData.fromConfig(
    //         2n * 10n ** 6n,    // minPriceUsdt
    //         400,               // commissionFactorUsdt (4%)
    //         800n * 10n ** 6n,  // maxCommissionUsdt
    //         300,               // minDuration (5 minutes)

    //         20n * 10n ** 3n,    // minPriceWeb3
    //         200,               // commissionFactorWeb3 (2%)
    //         8000n * 10n ** 3n, // minDuration (5 minutes)
    //         300                // minDuration (5 minutes)
    //     ),
    // });


    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.TON_SIMPLE_AUCTION, {
    //     dealCode: await compile('TonSimpleAuction'),
    //     deployFunctionCode: getDeployFunctionCode('TonSimpleAuction'),
    //     deployType: Marketplace.DeployTypes.NFT_TRANSFER,
    //     deployFee: toNano('0.0'),
    //     otherData: TonSimpleAuctionDeployData.fromConfig(
    //         toNano('0.4'),  // minPrice
    //         400,            // commissionFactor (4%)
    //         toNano('50'),   // maxCommission
    //         300             // minTimeIncrement (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_AUCTION, {
    //     dealCode: await compile('JettonSimpleAuction'),
    //     deployFunctionCode: getDeployFunctionCode('JettonSimpleAuction'),
    //     deployType: Marketplace.DeployTypes.NFT_TRANSFER,
    //     deployFee: toNano('0.0'),
    //     otherData: JettonSimpleAuctionDeployData.fromConfig(
    //         2n * 10n ** 6n,    // minPriceUsdt
    //         400,               // commissionFactorUsdt (4%)
    //         300n * 10n ** 6n,  // maxCommissionUsdt
    //         300,               // minTimeIncrement (5 minutes)

    //         20n * 10n ** 3n,   // minPriceWeb3
    //         200,               // commissionFactorWeb3 (2%)
    //         3000n * 10n ** 3n, // minDuration (5 minutes)
    //         300                // minTimeIncrement (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.TON_MULTIPLE_AUCTION, {
    //     dealCode: await compile('TonMultipleAuction'),
    //     deployFunctionCode: getDeployFunctionCode('TonMultipleAuction'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: TonMultipleAuctionDeployData.fromConfig(
    //         toNano('0.4'),  // minPrice
    //         400,            // commissionFactor (4%)
    //         toNano('200'),  // maxCommission
    //         300             // minTimeIncrement (5 minutes)
    //     ),
    // });
    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.JETTON_MULTIPLE_AUCTION, {
    //     dealCode: await compile('JettonMultipleAuction'),
    //     deployFunctionCode: getDeployFunctionCode('JettonMultipleAuction'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: JettonSimpleAuctionDeployData.fromConfig(
    //         2n * 10n ** 6n,    // minPriceUsdt
    //         400,               // commissionFactorUsdt (4%)
    //         800n * 10n ** 6n,  // maxCommissionUsdt
    //         300,               // minTimeIncrement (5 minutes)
    
    //         20n * 10n ** 3n,   // minPriceWeb3
    //         200,               // commissionFactorWeb3 (2%)
    //         8000n * 10n ** 3n, // maxCommissionWeb3
    //         300                // minTimeIncrement (5 minutes)
    //     ),
    // });

    // marketplaceConfig.deployInfos.set(Marketplace.DeployOpCodes.DOMAIN_SWAP, {
    //     dealCode: await compile('DomainSwap'),
    //     deployFunctionCode: getDeployFunctionCode('DomainSwap'),
    //     deployType: Marketplace.DeployTypes.SIMPLE,
    //     deployFee: toNano('0.05'),
    //     otherData: DomainSwapDeployData.fromConfig(
    //         toNano('0.5'),   // completionCommission
    //         600              // minDuration (10 minutes)
    //     ),
    // });

    // marketplaceConfig.web3WalletAddress = Address.parse("EQATHY4Nh6P5pw7HIHgKLYID9jo75anaTf8TzRnsUgvRj62n");
    const code = await compile('Marketplace');
    const data = marketplaceConfigToCell(marketplaceConfig, false);
    await marketplace.sendChangeCode(provider.sender(), code, null);
}
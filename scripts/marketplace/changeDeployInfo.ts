import { Address, beginCell, Dictionary, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { compile, NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { deployInfoValueParser, Marketplace } from '../../wrappers/Marketplace';
import { getDeployFunctionCode } from '../../wrappers/helpers/getDeployFunctionCode';
import { JettonSimpleSaleDeployData } from '../../wrappers/JettonSimpleSale';
import { TonSimpleOfferDeployData } from '../../wrappers/TonSimpleOffer';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(Marketplace.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM")));
    // const marketplaceConfig = await contract.getStorageData();
    // const deployInfos = marketplaceConfig.deployInfos;

    const updatesDict = Dictionary.empty(Dictionary.Keys.Uint(32), deployInfoValueParser());
    updatesDict.set(Marketplace.DeployOpCodes.TON_SIMPLE_OFFER, {
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
    updatesDict.set(Marketplace.DeployOpCodes.JETTON_SIMPLE_OFFER, {
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

    await contract.sendUpdateDeployInfo(provider.sender(), updatesDict);
}   
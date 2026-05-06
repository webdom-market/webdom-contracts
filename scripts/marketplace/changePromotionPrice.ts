import { Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Marketplace } from '../../wrappers/Marketplace';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(
        Marketplace.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM"))
    );

    const promotionPrices = (await contract.getStorageData()).promotionPrices;

    console.log(promotionPrices)
    promotionPrices.set(259200, {
        hotPrice: 60000n,
        coloredPrice: 120_000n,
    });
    promotionPrices.set(604800, {
        hotPrice: 120_000n,
        coloredPrice: 240_000n,
    });
    promotionPrices.set(1209600, {
        hotPrice: 200000n,
        coloredPrice: 400000n,
    });
    await contract.sendChangePromotionPrice(provider.sender(), promotionPrices);
}

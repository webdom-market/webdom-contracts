import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { deployInfoValueParser, Marketplace, subscriptionInfoValueParser, userSubscriptionValueParser } from '../../wrappers/Marketplace';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(Marketplace.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM")));
    const subscriptionsInfo = (await contract.getStorageData()).subscriptionsInfo;
    const sub = subscriptionsInfo!.get(1)!;
    sub.set(2592000, 2000000000n);
    sub.set(31622400, 18000000000n);
    subscriptionsInfo!.set(1, sub);
    await contract.sendChangeSubscriptionsInfo(provider.sender(), subscriptionsInfo!);
}   
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { deployInfoValueParser, Marketplace, userSubscriptionValueParser } from '../../wrappers/Marketplace';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(Marketplace.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM")));

    await contract.sendChangeMoveUpPrice(provider.sender(), 20_000n);
}   
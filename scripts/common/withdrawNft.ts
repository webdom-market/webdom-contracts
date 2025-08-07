import { Address, beginCell, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { Domain } from '../../wrappers/Domain';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(TonSimpleSale.createFromAddress(Address.parse("EQD7-a6WPtb7w5VgoUfHJmMvakNFgitXPk3sEM8Gf_WEBDOM")));
    await contract.sendWithdrawNft(provider.sender(), Address.parse("EQBmW6aKDgDrtxn5fJR7ATLEfb-_gYcupWaKNmiUUQEOLkCs"), 0);
}   
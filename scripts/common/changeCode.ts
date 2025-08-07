import { Address, beginCell, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { compile, NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { JettonWallet } from '../../wrappers/JettonWallet';
import { MultipleOffer } from '../../wrappers/MultipleOffer';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(MultipleOffer.createFromAddress(Address.parse("EQC2qPLXDYlN9_-ilgR5wVIoHyxZ0mNsaH8XfNBZ6dScEIKR")));
    await contract.sendChangeCode(provider.sender(), await compile('MultipleOffer'), null);
}   
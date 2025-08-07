import { Address, beginCell, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(TonSimpleSale.createFromAddress(Address.parse("EQA7QIKU3j1ipe88gg8euLxKupXEjc_czkigjw9mpZ5qXT8N")));
    await contract.sendWithdrawJetton(provider.sender(), Address.parse("EQA7kw5lt_rOhn9DbY8S-0rv3ThIq1MgaXFqHOKRme2ibToi"), 15n * 10n ** 4n, 0);
}   
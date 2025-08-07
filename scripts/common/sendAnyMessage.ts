import { Address, beginCell, toNano } from '@ton/core';
import { Addresses, OpCodes, Tons } from '../../wrappers/helpers/constants';
import { NetworkProvider } from '@ton/blueprint';
import { DefaultContract } from '../../wrappers/helpers/DefaultContract';
import { TonSimpleAuction } from '../../wrappers/TonSimpleAuction';
import { TonSimpleSale } from '../../wrappers/TonSimpleSale';
import { JettonWallet } from '../../wrappers/JettonWallet';

export async function run(provider: NetworkProvider) {
    const contract = provider.open(TonSimpleSale.createFromAddress(Address.parse("EQAqJC5IMDr5g5HVdKrNunKri7eckKNLas8Wqn7udtvQkMeU")));
    await contract.sendSendAnyMessage(provider.sender(), toNano('0.04'), Address.parse("EQCDnHdJmVgDM8mrew6FdJTGKNNhUbqB5gCqDxRDZULotg-I"), 
                                        JettonWallet.transferMessage(42n * 10n ** 5n, Address.parse("UQCovSj8c8Ik1I-RZt7dbIOEulYe-MfJ2SN5eMhxwfACvp7x"),
                                        Address.parse("UQCovSj8c8Ik1I-RZt7dbIOEulYe-MfJ2SN5eMhxwfACvp7x"), 1n, null));
}   
import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode } from '@ton/core';
import { getMinPrice } from './helpers/dnsUtils';


export type DnsCollectionConfig = {
    content: Cell;
    nftItemCode: Cell;
};

export function dnsCollectionConfigToCell(config: DnsCollectionConfig): Cell {
    return beginCell()
        .storeRef(config.content)
        .storeRef(config.nftItemCode)
    .endCell();
}

export class DnsCollection implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new DnsCollection(address);
    }

    static createFromConfig(config: DnsCollectionConfig, code: Cell, workchain = 0) {
        const data = dnsCollectionConfigToCell(config);
        const init = { code, data };
        return new DnsCollection(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(0x370fec51, 32).storeUint(0, 64).endCell(),
        });
    }

    async sendStartAuction(provider: ContractProvider, via: Sender, domain: string) {
        if (domain.endsWith('.ton')) {
            domain = domain.slice(0, -4);
        }
        await provider.internal(via, {
            value: getMinPrice(domain.length),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(0, 32).storeStringTail(domain).endCell(),
        });
    }
}
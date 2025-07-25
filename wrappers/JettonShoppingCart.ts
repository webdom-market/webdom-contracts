import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type JettonShoppingCartConfig = {};

export function jettonShoppingCartConfigToCell(config: JettonShoppingCartConfig): Cell {
    return beginCell().endCell();
}

export class JettonShoppingCart implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new JettonShoppingCart(address);
    }

    static createFromConfig(config: JettonShoppingCartConfig, code: Cell, workchain = 0) {
        const data = jettonShoppingCartConfigToCell(config);
        const init = { code, data };
        return new JettonShoppingCart(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}

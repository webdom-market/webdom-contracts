import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export class MarketplaceDeployer implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new MarketplaceDeployer(address);
    }

    static createFromConfig(ownerAddress: Address, param: number | bigint, code: Cell, workchain = 0) {
        const data = beginCell().storeUint(0, 5).storeAddress(ownerAddress).storeUint(param, 256).endCell();
        return new MarketplaceDeployer(contractAddress(workchain, { code, data }), { code, data });
    }
    
    static createFromData(code: Cell, data: Cell, workchain = 0) {
        const init = { code, data };
        return new MarketplaceDeployer(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint, code: Cell, data: Cell) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeRef(code).storeRef(data).endCell(),
        });
    }

    async sendDeploy2(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            // bounce: false,
            body: beginCell().endCell(),
        });
    }
}

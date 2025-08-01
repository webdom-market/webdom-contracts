import { beginCell, Cell } from "@ton/core";
import { Address, contractAddress } from "@ton/core";
import { Contract, ContractProvider, Sender, SendMode } from "@ton/ton";

export class TestConts implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new TestConts(address);
    }

    static create(code: Cell, workchain = 0) {
        const data = beginCell().endCell();
        const init = { code, data };
        return new TestConts(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
        });
    }

    async getDeployFunctionCell(provider: ContractProvider): Promise<string> {
        const {stack} = await provider.get('getDeployFunctionCell', []);
        const res = stack.readCell();
        return res.toBoc().toString('hex');
    }
}


import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode } from '@ton/core';
import { getMinPrice } from './helpers/dnsUtils';
import { sign } from '@ton/crypto';


export type TgUsernamesCollectionConfig = {
    touched?: boolean;
    subwalletId: number;
    publicKey: bigint;
    content: Cell;
    itemCode: Cell;
    fullDomain: string;
    royaltyParams: Cell;
};

export function tgUsernamesCollectionConfigToCell(config: TgUsernamesCollectionConfig): Cell {
    return beginCell()
        .storeBit(config.touched ?? true)
        .storeUint(config.subwalletId ?? 81467, 32)
        .storeUint(config.publicKey, 256)
        .storeRef(config.content)
        .storeRef(config.itemCode)
        .storeRef(
            beginCell()
                .storeUint(config.fullDomain.length, 8)
                .storeStringTail(config.fullDomain)
            .endCell()
        )
        .storeRef(config.royaltyParams)
    .endCell();
}

export class TgUsernamesCollection implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new TgUsernamesCollection(address);
    }

    static createFromConfig(config: TgUsernamesCollectionConfig, code: Cell, workchain = 0) {
        const data = tgUsernamesCollectionConfigToCell(config);
        const init = { code, data };
        return new TgUsernamesCollection(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(0, 32).storeStringTail("#topup").endCell(),
        });
    }

    async sendStartAuction(provider: ContractProvider, 
                           via: Sender,
                           username: string,
                           collectionConfig: TgUsernamesCollectionConfig, 
                           secretKey: Buffer, 
                           value: bigint) {
        const msgToSign = beginCell()
            .storeUint(collectionConfig.subwalletId, 32)
            .storeUint(0, 32)
            .storeInt(-1, 32)
            .storeUint(username.length, 8)
            .storeStringTail(username)
            .storeRef(beginCell().endCell())
            .storeRef(
                beginCell()
                    .storeAddress(via.address)
                    .storeCoins(value)
                    .storeCoins(value * 10n)
                    .storeUint(5, 8)
                    .storeUint(300, 32)
                    .storeUint(300, 32)
                .endCell()
            )
            .storeBit(0)
        .endCell();
        const signature = sign(msgToSign.hash(), secretKey);

        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                    .storeUint(0x4637289a, 32)
                    .storeBuffer(signature)
                    .storeSlice(msgToSign.beginParse())
                .endCell(),
        });
    }
}
import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, DictionaryValue, Sender, SendMode, toNano } from '@ton/core';
import { DefaultContract } from './helpers/DefaultContract';


export type ShoppingCartSwapInfo = {
    swapAmount: bigint
    poolAddress: Address
    requiredGas: bigint
}

export function shoppingCartSwapInfoToCell(swapInfo: ShoppingCartSwapInfo | null): Cell | null {
    if (swapInfo === null) {
        return null;
    }
    return beginCell()
            .storeCoins(swapInfo.swapAmount)
            .storeAddress(swapInfo.poolAddress)
            .storeCoins(swapInfo.requiredGas)
        .endCell();
}

export function shoppingCartSwapInfoFromCell(cell: Cell | null): ShoppingCartSwapInfo | null {
    if (cell === null) {
        return null;
    }
    let slice = cell.beginParse();
    return {swapAmount: slice.loadCoins(), poolAddress: slice.loadAddress(), requiredGas: slice.loadCoins()};
}

export type DomainInfoValue = {
    transferred: boolean
    saleContractAddress: Address
    price: bigint
    swapInfo: ShoppingCartSwapInfo | null
};

export function domainInfoValueParser(): DictionaryValue<DomainInfoValue> {
    return {
        serialize: (src, buidler) => {
            buidler.storeBit(src.transferred).storeAddress(src.saleContractAddress).storeCoins(src.price).storeMaybeRef(shoppingCartSwapInfoToCell(src.swapInfo)).endCell();
        },
        parse: (src) => {
            return {transferred: src.loadBit(), saleContractAddress: src.loadAddress(), price: src.loadCoins(), swapInfo: shoppingCartSwapInfoFromCell(src.loadMaybeRef())};
        }
    }
}


export type TonShoppingCartConfig = {
    ownerAddress: Address
    state: number
    domainsDict: Dictionary<Address, DomainInfoValue>
    commission: bigint
    domainsLeft: number
};

export function tonShoppingCartConfigToCell(config: TonShoppingCartConfig): Cell {
    return beginCell()
            .storeAddress(config.ownerAddress)
            .storeUint(config.state, 1)
            .storeDict(config.domainsDict, Dictionary.Keys.Address(), domainInfoValueParser())
            .storeCoins(config.commission)
            .storeUint(config.domainsLeft, 8)
        .endCell();
}

export class TonShoppingCart extends DefaultContract {
    static readonly PURCHASE = toNano('0.05');
    static readonly DEPLOY = toNano('0.03');
    static readonly STATE_UNINIT = 0;
    static readonly STATE_ACTIVE = 1;

    static createFromAddress(address: Address) {
        return new TonShoppingCart(address);
    }

    static createFromConfig(config: TonShoppingCartConfig, code: Cell, workchain = 0) {
        const data = tonShoppingCartConfigToCell(config);
        const init = { code, data };
        return new TonShoppingCart(contractAddress(workchain, init), init);
    }

    async getStorageData(provider: ContractProvider): Promise<TonShoppingCartConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        return {
            ownerAddress: stack.readAddress(),
            state: stack.readNumber(),
            domainsDict: ((c: Cell) => c.beginParse().loadDictDirect(Dictionary.Keys.Address(), domainInfoValueParser()))(stack.readCell()),
            commission: stack.readBigNumber(),
            domainsLeft: stack.readNumber()
        }
    }
}

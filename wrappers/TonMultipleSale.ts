import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { TonSimpleSaleDeployData } from './TonSimpleSale';
import { domainInListValueParser } from './JettonMultipleSale';


export type TonMultipleSaleConfig = {
    sellerAddress: Address;
    domainsDict: Dictionary<Address, number>;
    domainsTotal: number;
    domainsReceived: number;
    price: bigint;
    state: number;
    commission: bigint;
    createdAt: number;
    lastRenewalTime: number;
    validUntil: number;
    buyerAddress: Address | null;
    tonsToReserve: number;
    hotUntil?: number;
    coloredUntil?: number;
};


export class TonMultipleSaleDeployData extends TonSimpleSaleDeployData {
}


export function multipleTonSaleConfigToCell(config: TonMultipleSaleConfig): Cell {
    return beginCell()
            .storeAddress(config.sellerAddress)
            .storeDict(config.domainsDict, Dictionary.Keys.Address(), Dictionary.Values.Uint(1))
            .storeUint(config.domainsTotal, 8)
            .storeUint(config.domainsReceived, 8)

            .storeCoins(config.price)
            .storeCoins(config.commission)
            
            .storeUint(config.state, 2)
            .storeUint(config.createdAt, 32)
            .storeUint(config.lastRenewalTime, 32)
            .storeUint(config.validUntil, 32)
            
            .storeAddress(config.buyerAddress)
            
            .storeUint(config.hotUntil ?? 0, 32)
            .storeUint(config.coloredUntil ?? 0, 32)
        .endCell();
}

export class TonMultipleSale extends DefaultContract {
    static TON_PURCHASE = 80000000n; 
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new TonMultipleSale(address);
    }

    static createFromConfig(config: TonMultipleSaleConfig, code: Cell, workchain = 0) {
        const data = multipleTonSaleConfigToCell(config);
        const init = { code, data };
        return new TonMultipleSale(contractAddress(workchain, init), init);
    }

    static deployPayload(domainsList: Array<Address>, price: bigint, validUntil: number) {
        let domainsDict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        for (let domainAddress of domainsList) {
            domainsDict.set(domainAddress, false);
        }
        return beginCell()
            .storeDict(domainsDict)
            .storeCoins(price)
            .storeUint(validUntil, 32)
        .endCell();
    }

    async sendPurchase(provider: ContractProvider, via: Sender, price: bigint, domainsNumber: number, queryId: number = 0) {
        await provider.internal(via, {
            value: price + TonMultipleSale.TON_PURCHASE * BigInt(domainsNumber),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell()
        });
    }

    async sendChangePrice(provider: ContractProvider, via: Sender, newPrice: bigint, newValidUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.CHANGE_PRICE, 32).storeUint(queryId, 64).storeCoins(newPrice).storeUint(newValidUntil, 32).endCell()
        });
    }

    async sendCancelSale(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell()
        });
    }

    async sendRenewDomain(provider: ContractProvider, via: Sender, domainsNumber: number, queryId: number = 0) {
        await provider.internal(via, {
            value: Tons.RENEW_REQUEST + Tons.RENEW_DOMAIN * BigInt(domainsNumber),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64).storeBit(0).endCell()
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }


    async getStorageData(provider: ContractProvider): Promise<TonMultipleSaleConfig> {
        const {stack} = await provider.get('get_storage_data', []);
        let sellerAddress = stack.readAddress();
        let domainsDict = stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        let domainsTotal = stack.readNumber();
        let domainsReceived = stack.readNumber();
        let state = stack.readNumber();
        let price = stack.readBigNumber();
        return {
            sellerAddress: sellerAddress,
            domainsDict: domainsDict,
            domainsTotal: domainsTotal,
            domainsReceived: domainsReceived,
            state: state,
            price: price,
            commission: stack.readBigNumber() * price /BigInt(COMMISSION_DIVIDER),
            createdAt: stack.readNumber(),
            lastRenewalTime: stack.readNumber(),
            validUntil: stack.readNumber(),
            buyerAddress: stack.readAddressOpt(),
            tonsToReserve: stack.readNumber(),
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
        }
    }
}

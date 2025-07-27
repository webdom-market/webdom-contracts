import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';

export class TonSimpleSaleDeployData extends DeployData {
    minPrice: bigint;
    commissionFactor: number;
    maxCommission: bigint;
    minDuration: number;

    constructor(data: Slice) {  
        super(data);
        this.minPrice = data.loadCoins();
        this.commissionFactor = data.loadUint(16);
        this.maxCommission = data.loadCoins();
        this.minDuration = data.loadUint(32);
    }

    static fromConfig(minPrice: bigint, commissionFactor: number, maxCommission: bigint, minDuration: number): TonSimpleSaleDeployData {
        return new TonSimpleSaleDeployData(beginCell().storeCoins(minPrice).storeUint(commissionFactor, 16).storeCoins(maxCommission).storeUint(minDuration, 32).endCell().beginParse());
    }
}

export function domainToNotification(domainName: string): Cell {
    return beginCell().storeUint(0, 32).storeStringTail("Domain " + domainName + " was sold on webdom.market").endCell();
}

export function notificationToDomain(notification: Cell): string {
    const ns = notification.beginParse();
    return ns.skip(32).loadStringTail().slice(7, -22);
}


export type TonSimpleSaleConfig = {
    domainAddress: Address;
    sellerAddress: Address;
    price: bigint;
    state: number;
    commission: bigint;
    createdAt: number;
    lastRenewalTime: number;
    validUntil: number;
    buyerAddress: Maybe<Address>;
    domainName: string;
    hotUntil?: number;
    coloredUntil?: number;
};

export function tonSimpleSaleConfigToCell(config: TonSimpleSaleConfig): Cell {
    return beginCell()
        .storeAddress(config.domainAddress)
        .storeAddress(config.sellerAddress)
        .storeCoins(config.price)
        .storeUint(config.state, 2)
        .storeCoins(config.commission)
        .storeUint(config.createdAt, 32)
        .storeUint(config.lastRenewalTime, 32)
        .storeUint(config.validUntil, 32)
        .storeMaybeRef(config.buyerAddress ? beginCell().storeAddress(config.buyerAddress).endCell() : null)
        .storeRef(beginCell().storeStringTail(config.domainName).endCell())
        .storeUint(config.hotUntil ?? 0, 32)
        .storeUint(config.coloredUntil ?? 0, 32)
    .endCell();
}

export class TonSimpleSale extends DefaultContract {
    static PURCHASE = 70000000n; 
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;
    
    static createFromAddress(address: Address) {
        return new TonSimpleSale(address);
    }

    static createFromConfig(config: TonSimpleSaleConfig, code: Cell, workchain = 0) {
        const data = tonSimpleSaleConfigToCell(config);
        const init = { code, data };
        return new TonSimpleSale(contractAddress(workchain, init), init);
    }

    async sendPurchase(provider: ContractProvider, via: Sender, price: bigint, queryId: number = 0) {
        await provider.internal(via, {
            value: price + TonSimpleSale.PURCHASE,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell()
        });
    }

    static deployPayload(price: bigint, validUntil: number) {
        return beginCell().storeCoins(price).storeUint(validUntil, 32).endCell();
    }

    static changePriceMessage(newPrice: bigint, newValidUntil: number, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.CHANGE_PRICE, 32).storeUint(queryId, 64).storeCoins(newPrice).storeUint(newValidUntil, 32).endCell();
    }

    async sendChangePrice(provider: ContractProvider, via: Sender, newPrice: bigint, newValidUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleSale.changePriceMessage(newPrice, newValidUntil, queryId)
        });
    }

    static cancelSaleMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell();
    }

    async sendCancelSale(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleSale.cancelSaleMessage(queryId)
        });
    }

    static makeHotMessage(validUntil: number, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.MAKE_HOT, 32).storeUint(queryId, 64).storeUint(validUntil, 32).endCell();
    }
    
    async sendMakeHot(provider: ContractProvider, via: Sender, validUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.02'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleSale.makeHotMessage(validUntil, queryId)
        });
    }

    static makeColoredMessage(validUntil: number, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.MAKE_COLORED, 32).storeUint(queryId, 64).storeUint(validUntil, 32).endCell();
    }

    async sendMakeColored(provider: ContractProvider, via: Sender, validUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.02'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleSale.makeColoredMessage(validUntil, queryId)
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }
    
    static renewDomainMessage(queryId: number = 0, newValidUntil: number = 0) {
        let tmp = beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64);
        if (newValidUntil > 0) {
            tmp.storeBit(1).storeUint(newValidUntil, 32);
        }
        else {
            tmp.storeBit(0);
        }
        return tmp.endCell();
    }

    async sendRenewDomain(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: Tons.RENEW_REQUEST + Tons.RENEW_DOMAIN,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleSale.renewDomainMessage(queryId)
        });
    }

    async getStorageData(provider: ContractProvider): Promise<TonSimpleSaleConfig> {
        const {stack} = await provider.get('get_storage_data', []);
        let sellerAddress = stack.readAddress();
        let domainsDict = stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        stack.skip(2);
        let state = stack.readNumber();
        let price = stack.readBigNumber();
        let res = {
            domainAddress: domainsDict.keys()[0],
            sellerAddress: sellerAddress,
            state: state,
            price: price,
            commission: stack.readBigNumber() * price / BigInt(COMMISSION_DIVIDER),
            createdAt: stack.readNumber(),
            lastRenewalTime: stack.readNumber(),
            validUntil: stack.readNumber(),
            buyerAddress: stack.readAddressOpt(),
            domainName: stack.readCell().beginParse().loadStringTail(),
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
        }
        return res;
    }
}

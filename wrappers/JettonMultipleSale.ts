import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, DictionaryValue, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { JettonSimpleSaleDeployData } from './JettonSimpleSale';
import { TonMultipleSaleConfig } from './TonMultipleSale';
import { Maybe } from '@ton/core/dist/utils/maybe';


export function domainInListValueParser(): DictionaryValue<{isTg: boolean, domain: string}> {
    return {
        serialize: (src, buidler) => {
            buidler.storeBit(src.isTg).storeStringTail(src.domain).endCell();
        },
        parse: (src) => {
            let isTg = src.loadBit();
            let domain = src.loadStringTail();
            return {isTg, domain};
        }
    }
}


export type JettonMultipleSaleConfig = {
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
    hotUntil?: number;
    coloredUntil?: number;
    jettonMinterAddress: Address;
    jettonWalletAddress: Maybe<Address>;
    tonsToReserve: number;
};


export class JettonMultipleSaleDeployData extends JettonSimpleSaleDeployData {
}


export function multipleJettonSaleConfigToCell(config: JettonMultipleSaleConfig): Cell {
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
            
            .storeAddress(config.jettonWalletAddress)
            
            .storeUint(config.hotUntil ?? 0, 32)
            .storeUint(config.coloredUntil ?? 0, 32)
            .storeRef(beginCell().storeAddress(config.buyerAddress).endCell())
            .storeRef(beginCell().storeAddress(config.jettonMinterAddress).endCell())
        .endCell();
}

export class JettonMultipleSale extends DefaultContract {
    static TON_PURCHASE = 60000000n; 
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new JettonMultipleSale(address);
    }

    static createFromConfig(config: JettonMultipleSaleConfig, code: Cell, workchain = 0) {
        const data = multipleJettonSaleConfigToCell(config);
        const init = { code, data };
        return new JettonMultipleSale(contractAddress(workchain, init), init);
    }

    static deployPayload(isWeb3: boolean, domainsList: Array<string>, price: bigint, validUntil: number) {
        let domainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), domainInListValueParser());
        for (let i = 0; i < domainsList.length; i++) {
            let domain = domainsList[i];
            let isTg = domain.includes(".t.me");
            domainsDict.set(i, {isTg, domain: domain.slice(0, domain.indexOf('.'))});
        }
        return beginCell()
            .storeBit(isWeb3)
            .storeDict(domainsDict)
            .storeCoins(price)
            .storeUint(validUntil, 32)
        .endCell();
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

    async getStorageData(provider: ContractProvider): Promise<JettonMultipleSaleConfig> {
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
            jettonWalletAddress: stack.readAddress(),
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
            jettonMinterAddress: stack.readAddress(),
        }
    }
}

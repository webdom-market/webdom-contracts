import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { OpCodes } from './helpers/constants';
import { DefaultContract } from './helpers/DefaultContract';
import { DeployData } from './Marketplace';
import { domainInListValueParser } from './JettonMultipleSale';

export class MultipleDomainsSwapDeployData extends DeployData {
    completionCommission: bigint; 
    minDuration: number;

    constructor(data: Slice) {  
        super(data);
        this.completionCommission = data.loadCoins();
        this.minDuration = data.loadUint(32);
    }

    static fromConfig(completionCommission: bigint, minDuration: number): MultipleDomainsSwapDeployData {
        return new MultipleDomainsSwapDeployData(beginCell().storeCoins(completionCommission).storeUint(minDuration, 32).endCell().beginParse());
    }
}

export type MultipleDomainsSwapConfig = {
    leftOwnerAddress: Address;
    leftDomainsTotal: number;
    leftDomainsReceived: number;
    leftDomainsDict: Dictionary<Address, boolean>;
    leftPaymentTotal: bigint;
    leftPaymentReceived: bigint;

    rightOwnerAddress: Address;
    rightDomainsTotal: number;
    rightDomainsReceived: number;
    rightDomainsDict: Dictionary<Address, boolean>;
    rightPaymentTotal: bigint;
    rightPaymentReceived: bigint;

    state: number;
    createdAt: number;
    validUntil: number;
    lastActionTime: number;
    commission: bigint;
    needsAlert: boolean;
    cancelledByLeft?: boolean;
};

export function multipleDomainsSwapConfigToCell(config: MultipleDomainsSwapConfig): Cell {
    return beginCell()
            .storeRef(
                beginCell()
                    .storeAddress(config.leftOwnerAddress)
                    .storeUint(config.leftDomainsTotal, 8)
                    .storeUint(config.leftDomainsReceived, 8)
                    .storeDict(config.leftDomainsDict)
                    .storeCoins(config.leftPaymentTotal)
                    .storeCoins(config.leftPaymentReceived)
                .endCell()
            )
            .storeRef(
                beginCell()
                    .storeAddress(config.rightOwnerAddress)
                    .storeUint(config.rightDomainsTotal, 8)
                    .storeUint(config.rightDomainsReceived, 8)
                    .storeDict(config.rightDomainsDict)
                    .storeCoins(config.rightPaymentTotal)
                    .storeCoins(config.rightPaymentReceived)
                .endCell()
            )
            .storeUint(config.state, 2)
            .storeUint(config.createdAt, 32)
            .storeUint(config.validUntil, 32)
            .storeUint(config.lastActionTime, 32)
            .storeCoins(config.commission)
            .storeBit(config.needsAlert)
            .storeBit(config.cancelledByLeft ?? false)
        .endCell();
}

export class MultipleDomainsSwap extends DefaultContract {
    static STATE_WAITING_FOR_LEFT = 0;
    static STATE_WAITING_FOR_RIGHT = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;
    static ADD_DOMAIN_TONS = toNano('0.045');

    static createFromAddress(address: Address) {
        return new MultipleDomainsSwap(address);
    }

    static createFromConfig(config: MultipleDomainsSwapConfig, code: Cell, workchain = 0) {
        const data = multipleDomainsSwapConfigToCell(config);
        const init = { code, data };
        return new MultipleDomainsSwap(contractAddress(workchain, init), init);
    }

    static deployPayload(leftDomainsList: Array<string>, leftPaymentTotal: bigint, rightOwnerAddress: Address, rightDomainsList: Array<string>, rightPaymentTotal: bigint, validUntil: number, needsAlert: boolean) {
        let leftDomainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), domainInListValueParser());
        for (let i = 0; i < leftDomainsList.length; i++) {
            let domain = leftDomainsList[i];
            let isTg = domain.includes(".t.me");
            leftDomainsDict.set(i, {isTg, domain: domain.slice(0, domain.indexOf('.'))});
        }
        let rightDomainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), domainInListValueParser());
        for (let i = 0; i < rightDomainsList.length; i++) {
            let domain = rightDomainsList[i];
            let isTg = domain.includes(".t.me");
            rightDomainsDict.set(i, {isTg, domain: domain.slice(0, domain.indexOf('.'))});
        }
        return beginCell()
            .storeDict(leftDomainsDict)
            .storeCoins(leftPaymentTotal)
            .storeAddress(rightOwnerAddress)
            .storeDict(rightDomainsDict)
            .storeCoins(rightPaymentTotal)
            .storeUint(validUntil, 32)
            .storeBit(needsAlert)
        .endCell();
    }

    async sendAddPayment(provider: ContractProvider, via: Sender, value: bigint, queryId: number = 0) {
        await provider.internal(via, {
            value: value + toNano("0.01"),
            body: beginCell().endCell(),
        });
    }

    async sendCancelDeal(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.1"),
            body: beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell(),
        });
    }

    async sendChangeValidUntil(provider: ContractProvider, via: Sender, validUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.01"),
            body: beginCell().storeUint(OpCodes.CHANGE_VALID_UNTIL, 32).storeUint(queryId, 64).storeUint(validUntil, 32).endCell(),
        });
    }

    async getStorageData(provider: ContractProvider): Promise<MultipleDomainsSwapConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        return {
            leftOwnerAddress: stack.readAddress(),
            leftDomainsDict: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Bool()),
            leftDomainsTotal: stack.readNumber(),
            leftDomainsReceived: stack.readNumber(),
            leftPaymentTotal: stack.readBigNumber(),
            leftPaymentReceived: stack.readBigNumber(),
            
            rightOwnerAddress: stack.readAddress(),
            rightDomainsDict: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Bool()),
            rightDomainsTotal: stack.readNumber(),
            rightDomainsReceived: stack.readNumber(),
            rightPaymentTotal: stack.readBigNumber(),
            rightPaymentReceived: stack.readBigNumber(),

            state: stack.readNumber(),
            createdAt: stack.readNumber(),
            validUntil: stack.readNumber(),
            lastActionTime: stack.readNumber(),
            commission: stack.readBigNumber(),
            needsAlert: stack.readBoolean(),
            cancelledByLeft: stack.readBoolean(),
        };
    }
}

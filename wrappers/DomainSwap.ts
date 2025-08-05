import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { OpCodes } from './helpers/constants';
import { DefaultContract } from './helpers/DefaultContract';
import { DeployData } from './Marketplace';
import { domainInListValueParser } from './JettonMultipleSale';

export class DomainSwapDeployData extends DeployData {
    completionCommission: bigint; 
    minDuration: number;

    constructor(data: Slice) {  
        super(data);
        this.completionCommission = data.loadCoins();
        this.minDuration = data.loadUint(32);
    }

    static fromConfig(completionCommission: bigint, minDuration: number): DomainSwapDeployData {
        return new DomainSwapDeployData(beginCell().storeCoins(completionCommission).storeUint(minDuration, 32).endCell().beginParse());
    }
}

export type DomainSwapConfig = {
    leftParticipantAddress: Address;
    leftDomainsTotal: number;
    leftDomainsReceived: number;
    leftDomainsDict: Dictionary<Address, boolean>;
    leftPaymentTotal: bigint;
    leftPaymentReceived: bigint;

    rightParticipantAddress: Address;
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

export function domainSwapConfigToCell(config: DomainSwapConfig): Cell {
    return beginCell()
            .storeAddress(config.leftParticipantAddress)
            .storeRef(
                beginCell()
                    .storeUint(config.leftDomainsTotal, 8)
                    .storeUint(config.leftDomainsReceived, 8)
                    .storeDict(config.leftDomainsDict)
                    .storeCoins(config.leftPaymentTotal)
                    .storeCoins(config.leftPaymentReceived)
                .endCell()
            )
            .storeAddress(config.rightParticipantAddress)
            .storeRef(
                beginCell()
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

export class DomainSwap extends DefaultContract {
    static STATE_WAITING_FOR_LEFT = 0;
    static STATE_WAITING_FOR_RIGHT = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;
    static ADD_DOMAIN_TONS = toNano('0.05');

    static createFromAddress(address: Address) {
        return new DomainSwap(address);
    }

    static createFromConfig(config: DomainSwapConfig, code: Cell, workchain = 0) {
        const data = domainSwapConfigToCell(config);
        const init = { code, data };
        return new DomainSwap(contractAddress(workchain, init), init);
    }

    static deployPayload(leftDomainsList: Array<Address>, leftPaymentTotal: bigint, rightParticipantAddress: Address, rightDomainsList: Array<Address>, rightPaymentTotal: bigint, validUntil: number, needsAlert: boolean) {
        let leftDomainsDict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        for (let addr of leftDomainsList) {
            leftDomainsDict.set(addr, false);
        }
        let rightDomainsDict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        for (let addr of rightDomainsList) {
            rightDomainsDict.set(addr, false);
        }
        return beginCell()
            .storeDict(leftDomainsDict)
            .storeCoins(leftPaymentTotal)
            .storeAddress(rightParticipantAddress)
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

    async getStorageData(provider: ContractProvider): Promise<DomainSwapConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        return {
            leftParticipantAddress: stack.readAddress(),
            leftDomainsDict: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Bool()),
            leftDomainsTotal: stack.readNumber(),
            leftDomainsReceived: stack.readNumber(),
            leftPaymentTotal: stack.readBigNumber(),
            leftPaymentReceived: stack.readBigNumber(),
            
            rightParticipantAddress: stack.readAddress(),
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

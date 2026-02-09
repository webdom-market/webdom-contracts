import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, ONE_DAY, OpCodes, Tons } from './helpers/constants';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';

export class JettonSimpleSaleDeployData extends DeployData {
    minPriceUsdt: bigint;
    minPriceWeb3: bigint;
    commissionFactorUsdt: number;
    commissionFactorWeb3: number;
    maxCommissionUsdt: bigint;
    maxCommissionWeb3: bigint;
    minDurationUsdt: number;
    minDurationWeb3: number;

    constructor(data: Slice) {  
        super(data);

        this.minPriceUsdt = data.loadCoins();
        this.commissionFactorUsdt = data.loadUint(16);
        this.maxCommissionUsdt = data.loadCoins();
        this.minDurationUsdt = data.loadUint(32);
        
        let web3Data = data.loadRef().beginParse();
        this.minPriceWeb3 = web3Data.loadCoins();
        this.commissionFactorWeb3 = web3Data.loadUint(16);
        this.maxCommissionWeb3 = web3Data.loadCoins();
        this.minDurationWeb3 = web3Data.loadUint(32);
    }

    static fromConfig(minPriceUsdt: bigint, commissionFactorUsdt: number, maxCommissionUsdt: bigint, minDurationUsdt: number, minPriceWeb3: bigint, commissionFactorWeb3: number, maxCommissionWeb3: bigint, minDurationWeb3: number): JettonSimpleSaleDeployData {
        return new JettonSimpleSaleDeployData(
            beginCell()
                .storeCoins(minPriceUsdt)
                .storeUint(commissionFactorUsdt, 16)
                .storeCoins(maxCommissionUsdt)
                .storeUint(minDurationUsdt, 32)
                .storeRef(  // web3 data
                    beginCell()
                        .storeCoins(minPriceWeb3)
                        .storeUint(commissionFactorWeb3, 16)
                        .storeCoins(maxCommissionWeb3)
                        .storeUint(minDurationWeb3, 32)
                    .endCell()
                )
            .endCell().beginParse()
        );
    }
}


export type JettonSimpleSaleConfig = {
    domainAddress: Address;
    sellerAddress: Address;
    jettonWalletAddress?: Maybe<Address>;
    price: bigint;
    state: number;

    jettonMinterAddress: Address;
    commission: bigint;
    createdAt: number;
    lastRenewalTime: number;
    validUntil: number;
    buyerAddress: Maybe<Address>;
    domainName: string;
    isTgUsername?: boolean;
    hotUntil?: number;
    coloredUntil?: number;
    autoRenewCooldown?: number;
    autoRenewIterations?: number;
};

export function jettonSimpleSaleConfigToCell(config: JettonSimpleSaleConfig): Cell {
    const autoRenewCooldown = config.autoRenewCooldown ?? ONE_DAY * 365;
    const autoRenewIterations = config.autoRenewIterations ?? 0;
    return beginCell()
        .storeAddress(config.jettonWalletAddress)
        .storeAddress(config.sellerAddress)
        .storeCoins(config.price)
        .storeUint(config.state, 2)
        .storeCoins(config.commission)
        .storeUint(config.createdAt, 32)
        .storeUint(config.lastRenewalTime, 32)
        .storeUint(config.validUntil, 32)
        .storeRef(beginCell().storeStringTail(config.domainName).endCell())
        .storeBit(config.isTgUsername ?? false)
        .storeUint(config.hotUntil ?? 0, 32)
        .storeUint(config.coloredUntil ?? 0, 32)
        .storeRef(
            beginCell()
                .storeAddress(config.domainAddress)
                .storeAddress(config.jettonMinterAddress)
                .storeAddress(config.buyerAddress)
                .storeUint(autoRenewCooldown, 32)
                .storeUint(autoRenewIterations, 8)
            .endCell()
        )
        .endCell();
}

export class JettonSimpleSale extends DefaultContract {
    static PURCHASE = toNano('0.225'); 
    static AUTORENEW_STORAGE_PER_YEAR = 35000000n;
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;
    
    static createFromAddress(address: Address) {
        return new JettonSimpleSale(address);
    }

    static createFromConfig(config: JettonSimpleSaleConfig, code: Cell, workchain = 0) {
        const data = jettonSimpleSaleConfigToCell(config);
        const init = { code, data };
        return new JettonSimpleSale(contractAddress(workchain, init), init);
    }

    static deployPayload(
        isWeb3: boolean,
        price: bigint,
        validUntil: number,
        autoRenewCooldown: number = ONE_DAY * 365,
        autoRenewIterations: number = 0,
    ) {
        let payload = beginCell().storeBit(isWeb3).storeCoins(price).storeUint(validUntil, 32);
        if (autoRenewIterations > 0 || autoRenewCooldown !== ONE_DAY * 365) {
            payload = payload
                .storeUint(autoRenewCooldown, 32)
                .storeUint(autoRenewIterations, 8);
        }
        return payload.endCell();
    }

    static changePriceMessage(newPrice: bigint, newValidUntil: number, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.CHANGE_PRICE, 32).storeUint(queryId, 64).storeCoins(newPrice).storeUint(newValidUntil, 32).endCell();
    }

    async sendChangePrice(provider: ContractProvider, via: Sender, newPrice: bigint, newValidUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonSimpleSale.changePriceMessage(newPrice, newValidUntil, queryId)
        });
    }

    static cancelSaleMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell();
    }

    async sendCancelSale(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonSimpleSale.cancelSaleMessage(queryId)
        });
    }

    async sendMakeHot(provider: ContractProvider, via: Sender, validUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.02'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.MAKE_HOT, 32).storeUint(queryId, 64).storeUint(validUntil, 32).endCell()
        });
    }

    async sendMakeColored(provider: ContractProvider, via: Sender, validUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.02'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.MAKE_COLORED, 32).storeUint(queryId, 64).storeUint(validUntil, 32).endCell()
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }

    async sendRenewDomain(provider: ContractProvider, via: Sender, queryId: number = 0, newValidUntil?: number) {
        let msg = beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64);
        if (newValidUntil != null) {
            msg = msg.storeBit(1).storeUint(newValidUntil, 32);
        } else {
            msg = msg.storeBit(0);
        }
        await provider.internal(via, {
            value: Tons.RENEW_REQUEST + Tons.RENEW_DOMAIN,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: msg.endCell()
        });
    }

    static setAutoRenewParamsMessage(
        autoRenewCooldown: number,
        autoRenewIterations: number,
        queryId: number = 0,
        newValidUntil: number = 0,
    ) {
        let msg = beginCell()
            .storeUint(OpCodes.SET_AUTORENEW_PARAMS, 32)
            .storeUint(queryId, 64)
            .storeUint(autoRenewCooldown, 32)
            .storeUint(autoRenewIterations, 8);
        if (newValidUntil > 0) {
            msg = msg.storeBit(1).storeUint(newValidUntil, 32);
        } else {
            msg = msg.storeBit(0);
        }
        return msg.endCell();
    }

    async sendSetAutoRenewParams(
        provider: ContractProvider,
        via: Sender,
        autoRenewCooldown: number,
        autoRenewIterations: number,
        queryId: number = 0,
        newValidUntil: number = 0,
        value: bigint = Tons.AUTORENEW_TOPUP_GAS_BUFFER + Tons.MIN_EXCESS + BigInt(autoRenewIterations) *
            (JettonSimpleSale.AUTORENEW_STORAGE_PER_YEAR + Tons.AUTORENEW_TX_PER_ITER + Tons.AUTORENEW_MARKETPLACE_FEE),
    ) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonSimpleSale.setAutoRenewParamsMessage(autoRenewCooldown, autoRenewIterations, queryId, newValidUntil)
        });
    }

    async sendExternalTriggerAutoRenew(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.TRIGGER_AUTORENEW, 32).storeUint(queryId, 64).endCell());
    }

    async getStorageData(provider: ContractProvider): Promise<JettonSimpleSaleConfig> {
        const {stack} = await provider.get('get_storage_data', []);
        let sellerAddress = stack.readAddress();
        let domainsDict = stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        stack.skip(2);
        let state = stack.readNumber();
        let price = stack.readBigNumber();
        return {
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
            isTgUsername: stack.readBoolean(),
            jettonWalletAddress: stack.readAddressOpt(),
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
            autoRenewCooldown: stack.readNumber(),
            autoRenewIterations: stack.readNumber(),
            jettonMinterAddress: stack.readAddress(),
        }
    }
}

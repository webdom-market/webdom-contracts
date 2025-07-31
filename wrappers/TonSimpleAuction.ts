import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { OpCodes, Tons } from './helpers/constants';
import { notificationToDomain } from './TonSimpleSale';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';


export class TonSimpleAuctionDeployData extends DeployData {
    minPrice: bigint;
    commissionFactor: number;
    maxCommission: bigint;
    minTimeIncrement: number;

    constructor(data: Slice) {  
        super(data);
        this.minPrice = data.loadCoins();
        this.commissionFactor = data.loadUint(16);
        this.maxCommission = data.loadCoins();
        this.minTimeIncrement = data.loadUint(32);
    }

    static fromConfig(minPrice: bigint, commissionFactor: number, maxCommission: bigint, minTimeIncrement: number): TonSimpleAuctionDeployData {
        return new TonSimpleAuctionDeployData(beginCell().storeCoins(minPrice).storeUint(commissionFactor, 16).storeCoins(maxCommission).storeUint(minTimeIncrement, 32).endCell().beginParse());
    }
}


export type TonSimpleAuctionConfig = {
    domainAddress: Address;
    sellerAddress: Address;
    minBidValue: bigint;
    maxBidValue: bigint;
    minBidIncrement: number;
    timeIncrement: number;
    commissionFactor: number;

    state: number;
    isDeferred: boolean;
    startTime: number;
    endTime: number;
    lastDomainRenewalTime: number;
    lastBidValue: bigint;
    lastBidTime: number;
    lastBidderAddress: Maybe<Address>;
    domainName: string;

    maxCommission: bigint;

    hotUntil?: number;
    coloredUntil?: number;
};

export function outbidNotificationToDomain(notification: Cell): string {
    const ns = notification.beginParse();
    return ns.skip(32).loadStringTail().slice(12, -44);
}

export function tonSimpleAuctionConfigToCell(config: TonSimpleAuctionConfig): Cell {
    return beginCell()
        .storeUint(config.state, 2)
        .storeBit(config.isDeferred)

        .storeUint(config.startTime, 32)
        .storeUint(config.endTime, 32)
        .storeUint(config.lastDomainRenewalTime, 32)
        
        .storeCoins(config.lastBidValue)
        .storeUint(config.lastBidTime, 32)
        .storeAddress(config.lastBidderAddress)

        .storeRef(beginCell().storeStringTail(config.domainName).endCell())

        .storeUint(config.hotUntil ?? 0, 32)
        .storeUint(config.coloredUntil ?? 0, 32)

        .storeAddress(config.sellerAddress)
        .storeUint(config.minBidValue, 64)
        .storeUint(config.minBidIncrement, 12)
        .storeUint(config.timeIncrement, 32)
        .storeUint(config.commissionFactor, 16)
        
        .storeRef(
            beginCell()
                .storeAddress(config.domainAddress)
                .storeCoins(config.maxBidValue)
                .storeUint(config.maxCommission, 64)
            .endCell()
        )
    .endCell();
}


export class TonSimpleAuction extends DefaultContract {
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new TonSimpleAuction(address);
    }

    static createFromConfig(config: TonSimpleAuctionConfig, code: Cell, workchain = 0) {
        const data = tonSimpleAuctionConfigToCell(config);
        const init = { code, data };
        return new TonSimpleAuction(contractAddress(workchain, init), init);
    }

    static deployPayload(startTime: number, endTime: number, minBidValue: bigint, maxBidValue: bigint, minBidIncrement: number, timeIncrement: number, isDeferred: boolean) {
        return beginCell()
                    .storeBit(isDeferred)
                    .storeUint(startTime, 32)
                    .storeUint(endTime, 32)
                    .storeCoins(minBidValue)
                    .storeCoins(maxBidValue)
                    .storeUint(minBidIncrement, 12)
                    .storeUint(timeIncrement, 32)
                .endCell();
    }
    
    async sendPlaceBid(provider: ContractProvider, via: Sender, value: bigint, queryId: number = 0) {
        await provider.internal(via, {
            value: value + Tons.END_TON_AUCTION + Tons.NOTIFY_BIDDER + toNano("0.035"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    static stopAuctionMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.STOP_AUCTION, 32).storeUint(queryId, 64).endCell();
    }

    async sendStopAuction(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.03"),
            body: TonSimpleAuction.stopAuctionMessage(queryId),
        });
    }

    static renewDomainMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64).endCell();
    }

    async sendRenewDomain(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.025"),
            body: TonSimpleAuction.renewDomainMessage(queryId),
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }

    async getStorageData(provider: ContractProvider): Promise<TonSimpleAuctionConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        let sellerAddress = stack.readAddress();
        let domainsDict = stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        stack.skip(2);
        return {
            sellerAddress: sellerAddress,
            domainAddress: domainsDict.keys()[0],
            state: stack.readNumber(),
            maxBidValue: stack.readBigNumber(),
            commissionFactor: stack.readNumber(),
            startTime: stack.readNumber(),
            lastDomainRenewalTime: stack.readNumber(),
            endTime: stack.readNumber(),
            lastBidderAddress: stack.readAddressOpt(),
            minBidValue: stack.readBigNumber(),
            minBidIncrement: stack.readNumber(),
            timeIncrement: stack.readNumber(),
            lastBidValue: stack.readBigNumber(),
            lastBidTime: stack.readNumber(),
            domainName: stack.readCell().beginParse().loadStringTail(),
            maxCommission: stack.readBigNumber(),

            isDeferred: stack.readBoolean(),
            
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
        };
    }
}

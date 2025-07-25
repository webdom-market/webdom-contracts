import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { TonSimpleSaleDeployData } from './TonSimpleSale';
import { domainInListValueParser } from './JettonMultipleSale';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { TonSimpleAuctionDeployData } from './TonSimpleAuction';


export type TonMultipleAuctionConfig = {
    sellerAddress: Address;
    domainsDict: Dictionary<Address, number>;
    domainsTotal: number;
    domainsReceived: number;

    minBidValue: bigint;
    maxBidValue: bigint;
    minBidIncrement: number;
    timeIncrement: number;
    commissionFactor: number;
    maxCommission: bigint;

    state: number;
    startTime: number;
    endTime: number;
    lastDomainRenewalTime: number;
    lastBidValue: bigint;
    lastBidTime: number;
    lastBidderAddress: Maybe<Address>;
    
    tonsToEndAuction: bigint;

    isDeferred: boolean;

    hotUntil?: number;
    coloredUntil?: number;
};


export class TonMultipleAuctionDeployData extends TonSimpleAuctionDeployData {
}


export function multipleTonSaleConfigToCell(config: TonMultipleAuctionConfig): Cell {
    return beginCell()
            .storeUint(config.state, 2)
            .storeBit(config.isDeferred)

            .storeUint(config.startTime, 32)
            .storeUint(config.endTime, 32)
            .storeUint(config.lastDomainRenewalTime, 32)

            .storeCoins(config.lastBidValue)
            .storeUint(config.lastBidTime, 32)
            .storeAddress(config.lastBidderAddress)

            .storeDict(config.domainsDict)
            .storeUint(config.domainsTotal, 8)
            .storeUint(config.domainsReceived, 8)

            .storeCoins(0)
            .storeUint(config.hotUntil ?? 0, 32)
            .storeUint(config.coloredUntil ?? 0, 32)

            .storeRef(
                beginCell()
                    .storeAddress(config.sellerAddress)

                    .storeCoins(config.minBidValue)
                    .storeCoins(config.maxBidValue)
                    .storeUint(config.minBidIncrement, 12)
                    .storeUint(config.timeIncrement, 32)

                    .storeUint(config.commissionFactor, 16)
                    .storeCoins(config.maxCommission)
                    .storeCoins(config.tonsToEndAuction)
                .endCell()
            )
        .endCell();
}

export class TonMultipleAuction extends DefaultContract {
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new TonMultipleAuction(address);
    }

    static createFromConfig(config: TonMultipleAuctionConfig, code: Cell, workchain = 0) {
        const data = multipleTonSaleConfigToCell(config);
        const init = { code, data };
        return new TonMultipleAuction(contractAddress(workchain, init), init);
    }

    static deployPayload(domainsList: Array<string>, startTime: number, endTime: number, minBidValue: bigint, maxBidValue: bigint, minBidIncrement: number, timeIncrement: number, isDeferred: boolean) {
        let domainsDict = Dictionary.empty(Dictionary.Keys.Uint(8), domainInListValueParser());
        for (let i = 0; i < domainsList.length; i++) {
            let domain = domainsList[i];
            let isTg = domain.includes(".t.me");
            domainsDict.set(i, {isTg, domain: domain.slice(0, domain.indexOf('.'))});
        }
        return beginCell()
                .storeDict(domainsDict)
                .storeBit(isDeferred)
                .storeUint(startTime, 32)
                .storeUint(endTime, 32)
                .storeCoins(minBidValue)
                .storeCoins(maxBidValue)
                .storeUint(minBidIncrement, 12)
                .storeUint(timeIncrement, 32)
            .endCell();
    }

    static getTonsToEndAuction(domainsNumber: number) {
        return (Tons.NFT_TRANSFER + Tons.PURCHASE_NOTIFICATION + toNano('0.005')) * BigInt(domainsNumber) + toNano('0.015');
    }

    async sendPurchase(provider: ContractProvider, via: Sender, price: bigint, domainsNumber: number, queryId: number = 0) {
        await provider.internal(via, {
            value: price + TonMultipleAuction.getTonsToEndAuction(domainsNumber),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell()
        });
    }

    async sendPlaceBid(provider: ContractProvider, via: Sender, value: bigint, domainsNumber: number, queryId: number = 0) {
        await provider.internal(via, {
            value: value + TonMultipleAuction.getTonsToEndAuction(domainsNumber) + Tons.NOTIFY_BIDDER,
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
            body: TonMultipleAuction.stopAuctionMessage(queryId),
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
            body: beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64).endCell()
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }


    async getStorageData(provider: ContractProvider): Promise<TonMultipleAuctionConfig> {
        const {stack} = await provider.get('get_storage_data', []);
        return {
            sellerAddress: stack.readAddress(),
            domainsDict: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(1)),
            domainsTotal: stack.readNumber(),
            domainsReceived: stack.readNumber(),
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

            maxCommission: stack.readBigNumber(),
            tonsToEndAuction: stack.readBigNumber(),

            isDeferred: stack.readBoolean(),
            
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
        }
    }
}

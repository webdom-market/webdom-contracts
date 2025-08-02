import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { OpCodes, Tons } from './helpers/constants';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { TonMultipleAuction } from './TonMultipleAuction';
import { domainInListValueParser } from './JettonMultipleSale';
import { JettonSimpleAuctionDeployData } from './JettonSimpleAuction';

export class JettonMultipleAuctionDeployData extends JettonSimpleAuctionDeployData {}

export type JettonMultipleAuctionConfig = {
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

    jettonWalletAddress?: Maybe<Address>;
    jettonMinterAddress: Address;

    state: number;
    startTime: number;
    endTime: number;
    lastDomainRenewalTime: number;
    lastBidValue: bigint;
    lastBidTime: number;
    lastBidderAddress: Maybe<Address>;

    isDeferred: boolean;

    hotUntil?: number;
    coloredUntil?: number;
};

export function jettonMultipleAuctionConfigToCell(config: JettonMultipleAuctionConfig): Cell {
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

        .storeUint(config.hotUntil ?? 0, 32)
        .storeUint(config.coloredUntil ?? 0, 32)

        .storeAddress(config.sellerAddress)

        .storeUint(config.minBidValue, 64)
        .storeUint(config.minBidIncrement, 12)
        .storeUint(config.timeIncrement, 32)
        .storeUint(config.commissionFactor, 16)

        .storeRef(
            beginCell()
                .storeAddress(config.jettonWalletAddress)
                .storeAddress(config.jettonMinterAddress)
                .storeCoins(config.maxBidValue)
                .storeUint(config.maxCommission, 64)
            .endCell()
        )
    .endCell();
}

export class JettonMultipleAuction extends DefaultContract {
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new JettonMultipleAuction(address);
    }

    static createFromConfig(config: JettonMultipleAuctionConfig, code: Cell, workchain = 0) {
        const data = jettonMultipleAuctionConfigToCell(config);
        const init = { code, data };
        return new JettonMultipleAuction(contractAddress(workchain, init), init);
    }

    static deployPayload(domainsList: Array<Address>, isWeb3: boolean, startTime: number, endTime: number, minBidValue: bigint, maxBidValue: bigint, minBidIncrement: number, timeIncrement: number, isDeferred: boolean) {
        let domainsDict = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        for (let domainAddress of domainsList) {
            domainsDict.set(domainAddress, false);
        }
        return beginCell()
                .storeBit(isWeb3)
                .storeBit(isDeferred)
                .storeUint(startTime, 32)
                .storeUint(endTime, 32)
                .storeDict(domainsDict)
                .storeCoins(minBidValue)
                .storeCoins(maxBidValue)
                .storeUint(minBidIncrement, 12)
                .storeUint(timeIncrement, 32)
            .endCell();
    }

    static getTonsToEndAuction(domainsNumber: number) {
        return (Tons.NFT_TRANSFER + Tons.PURCHASE_NOTIFICATION + toNano('0.01')) * BigInt(domainsNumber) + toNano('0.01') + Tons.JETTON_TRANSFER * 2n;
    }

    async sendStopAuction(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.03"),
            body: TonMultipleAuction.stopAuctionMessage(queryId),
        });
    }

    async sendRenewDomain(provider: ContractProvider, via: Sender, domainsNumber: number, queryId: number = 0) {
        await provider.internal(via, {
            value: Tons.RENEW_REQUEST + Tons.RENEW_DOMAIN * BigInt(domainsNumber),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(OpCodes.RENEW_DOMAIN, 32).storeUint(queryId, 64).storeBit(0).endCell()
        });
    }

    async getStorageData(provider: ContractProvider): Promise<JettonMultipleAuctionConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        let res: JettonMultipleAuctionConfig = {
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

            jettonWalletAddress: stack.readAddressOpt(),
            isDeferred: stack.readBoolean(),
            
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),

            jettonMinterAddress: stack.readAddress(),
        };
        return res;
    }
}

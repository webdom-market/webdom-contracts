import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { OpCodes, Tons } from './helpers/constants';
import { notificationToDomain } from './TonSimpleSale';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { SandboxContract } from '@ton/sandbox';
import { JettonWallet } from './JettonWallet';
import { TonSimpleAuction } from './TonSimpleAuction';


export class JettonSimpleAuctionDeployData extends DeployData {
    minPriceUsdt: bigint;
    commissionFactorUsdt: number;
    maxCommissionUsdt: bigint;
    minTimeIncrementUsdt: number;

    minPriceWeb3: bigint;
    commissionFactorWeb3: number;
    maxCommissionWeb3: bigint;
    minTimeIncrementWeb3: number;

    constructor(data: Slice) {  
        super(data);
        this.minPriceUsdt = data.loadCoins();
        this.commissionFactorUsdt = data.loadUint(16);
        this.maxCommissionUsdt = data.loadCoins();
        this.minTimeIncrementUsdt = data.loadUint(32);

        let web3Data = data.loadRef().beginParse();
        this.minPriceWeb3 = web3Data.loadCoins();
        this.commissionFactorWeb3 = web3Data.loadUint(16);
        this.maxCommissionWeb3 = web3Data.loadCoins();
        this.minTimeIncrementWeb3 = web3Data.loadUint(32);
    }

    static fromConfig(minPriceUsdt: bigint, commissionFactorUsdt: number, maxCommissionUsdt: bigint, minTimeIncrementUsdt: number, minPriceWeb3: bigint, commissionFactorWeb3: number, maxCommissionWeb3: bigint, minTimeIncrementWeb3: number): JettonSimpleAuctionDeployData {
        return new JettonSimpleAuctionDeployData(
            beginCell()
                .storeCoins(minPriceUsdt)
                .storeUint(commissionFactorUsdt, 16)
                .storeCoins(maxCommissionUsdt)
                .storeUint(minTimeIncrementUsdt, 32)
                .storeRef(  // web3 data
                    beginCell()
                        .storeCoins(minPriceWeb3)
                        .storeUint(commissionFactorWeb3, 16)
                        .storeCoins(maxCommissionWeb3)
                        .storeUint(minTimeIncrementWeb3, 32)
                    .endCell()
                )
            .endCell().beginParse()
        );
    }
}


export type JettonSimpleAuctionConfig = {
    domainAddress: Address;
    sellerAddress: Address;
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
    domainName: string;

    isDeferred: boolean;

    hotUntil?: number;
    coloredUntil?: number;
};

export function outbidNotificationToDomain(notification: Cell): string {
    const ns = notification.beginParse();
    const str = ns.skip(32).loadStringTail();
    return str.slice(12, str.length - 44);
}

export function jettonSimpleAuctionConfigToCell(config: JettonSimpleAuctionConfig): Cell {
    return beginCell()
        .storeUint(config.state, 2)
        .storeBit(config.isDeferred)
        .storeUint(config.startTime, 32)
        .storeUint(config.endTime, 32)
        .storeUint(config.lastDomainRenewalTime, 32)

        .storeCoins(config.lastBidValue)
        .storeUint(config.lastBidTime, 32)
        .storeAddress(config.lastBidderAddress)
        
        .storeRef(beginCell().storeUint(0, 32).storeStringTail("Your bid on " + config.domainName + " was outbid by another user on webdom.market").endCell())
        .storeRef(beginCell().storeUint(0, 32).storeStringTail("Domain " + config.domainName + " was sold on webdom.market").endCell())
        
        .storeUint(config.hotUntil ?? 0, 32)
        .storeUint(config.coloredUntil ?? 0, 32)
        .storeAddress(config.jettonWalletAddress)

        .storeRef(
            beginCell()
                .storeAddress(config.domainAddress)
                .storeAddress(config.sellerAddress)
                .storeAddress(config.jettonMinterAddress)
                .storeRef(
                    beginCell()
                        .storeCoins(config.minBidValue)
                        .storeCoins(config.maxBidValue)
                        .storeUint(config.minBidIncrement, 12)
                        .storeUint(config.timeIncrement, 32)

                        .storeUint(config.commissionFactor, 16)
                        .storeCoins(config.maxCommission)
                    .endCell()
                )
            .endCell()
        )
    .endCell();
}


export class JettonSimpleAuction extends DefaultContract {
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new JettonSimpleAuction(address);
    }

    static createFromConfig(config: JettonSimpleAuctionConfig, code: Cell, workchain = 0) {
        const data = jettonSimpleAuctionConfigToCell(config);
        const init = { code, data };
        return new JettonSimpleAuction(contractAddress(workchain, init), init);
    }

    static deployPayload(isWeb3: boolean, startTime: number, endTime: number, minBidValue: bigint, maxBidValue: bigint, minBidIncrement: number, timeIncrement: number, isDeferred: boolean) {
        return beginCell()
                    .storeBit(isWeb3)
                    .storeBit(isDeferred)
                    .storeUint(startTime, 32)
                    .storeUint(endTime, 32)
                    .storeCoins(minBidValue)
                    .storeCoins(maxBidValue)
                    .storeUint(minBidIncrement, 12)
                    .storeUint(timeIncrement, 32)
                .endCell();
    }

    async sendStopAuction(provider: ContractProvider, via: Sender, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.03"),
            body: TonSimpleAuction.stopAuctionMessage(queryId),
        });
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

    async getStorageData(provider: ContractProvider): Promise<JettonSimpleAuctionConfig> {
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
            domainName: outbidNotificationToDomain(stack.readCell()),
            maxCommission: (stack.readCellOpt() ?? 1) ? stack.readBigNumber() : toNano("99999"),

            jettonWalletAddress: stack.readAddressOpt(),
            isDeferred: stack.readBoolean(),
            hotUntil: stack.readNumber(),
            coloredUntil: stack.readNumber(),
            
            jettonMinterAddress: stack.readAddress(),
        };
    }
}

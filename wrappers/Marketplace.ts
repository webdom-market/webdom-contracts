import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, DictionaryValue, Sender, SendMode, Slice, toNano } from '@ton/core';
import { Addresses, ONE_DAY, OpCodes } from './helpers/constants';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DefaultContract } from './helpers/DefaultContract';
import { sign } from '@ton/crypto';

export class DeployData {
    raw: Cell;

    fromSlice(data: Slice) {
        
    }
    constructor(data: Slice) {
        this.raw = data.asCell();
        this.fromSlice(data);
    }
}

export type DeployInfoValue = {
    code: Cell;
    deployFee: bigint;
    otherData: DeployData;
};

export function deployInfoValueParser(): DictionaryValue<DeployInfoValue> {
    return {
        serialize: (src, buidler) => {
            buidler.storeRef(src.code).storeCoins(src.deployFee).storeSlice(src.otherData.raw.beginParse()).endCell();
        },
        parse: (src) => {
            const code = src.loadRef();
            const deployFee = src.loadCoins();
            const otherData = new DeployData(src);
            return {code, deployFee, otherData};
        }
    }
}

export type UserSubscriptionValue = {
    level: number;
    endTime: number;
};

export function userSubscriptionValueParser(): DictionaryValue<UserSubscriptionValue> {
    return {
        serialize: (src, buidler) => {
            buidler.storeUint(src.level, 8).storeUint(src.endTime, 32).endCell();
        },
        parse: (src) => {
            const level = src.loadUint(8);
            const endTime = src.loadUint(32);
            return { level, endTime };
        }
    }
}

export function subscriptionInfoValueParser(): DictionaryValue<Dictionary<number, bigint>> {
    return {
        serialize: (src, buidler) => {
            buidler.storeDict(src, Dictionary.Keys.Uint(32), Dictionary.Values.BigUint(64)).endCell();
        },
        parse: (src) => {
            return src.loadDict(Dictionary.Keys.Uint(32), Dictionary.Values.BigUint(64));
        }
    }
}


export type HotPricesValue = {
    hotPrice: bigint;
    coloredPrice: bigint;
};

export function hotPricesValueParser(): DictionaryValue<HotPricesValue> {
    return {
        serialize: (src, buidler) => {
            buidler.storeUint(src.hotPrice, 64).storeUint(src.coloredPrice, 64).endCell();
        },
        parse: (src) => {
            const hotPrice = BigInt(src.loadUint(64));
            const coloredPrice = BigInt(src.loadUint(64));
            return { hotPrice, coloredPrice };
        }
    }
}

export type MarketplaceConfig = {
    ownerAddress: Address;
    publicKey: bigint;
    deployInfos: Dictionary<number, DeployInfoValue>;
    
    userSubscriptions?: Dictionary<Address, UserSubscriptionValue>;
    subscriptionsInfo?: Dictionary<number, Dictionary<number, bigint>>;
    
    moveUpSalePrice: bigint;
    currentTopSale: Address;
    
    usdtWalletAddress: Address;
    web3WalletAddress: Address;

    collectedFeesTon: bigint;
    collectedFeesUsdt: bigint;
    collectedFeesWeb3: bigint;

    hotPrices: Dictionary<number, HotPricesValue>;
};

export function marketplaceConfigToCell(config: MarketplaceConfig): Cell {
    return beginCell()
        .storeAddress(config.ownerAddress)
        .storeUint(config.publicKey, 256)
        .storeDict(config.deployInfos, Dictionary.Keys.Uint(32), deployInfoValueParser())
        
        .storeDict(config.userSubscriptions, Dictionary.Keys.Address(), userSubscriptionValueParser())
        .storeDict(config.subscriptionsInfo, Dictionary.Keys.Uint(8), subscriptionInfoValueParser())
        
        .storeCoins(config.moveUpSalePrice)
        .storeAddress(config.currentTopSale)
        
        .storeRef(
            beginCell()
                .storeAddress(config.usdtWalletAddress)
                .storeAddress(config.web3WalletAddress)
                .storeCoins(config.collectedFeesTon)
                .storeCoins(config.collectedFeesUsdt)
                .storeCoins(config.collectedFeesWeb3)
                .storeDict(config.hotPrices, Dictionary.Keys.Uint(32), hotPricesValueParser())
            .endCell()
        )
    .endCell();
}

export class Marketplace extends DefaultContract {
    static readonly DeployOpCodes = {
        TON_FIX_PRICE_SALE: 0x763e023f & 0x0fffffff,
        TON_MULTIPLE_SALE: 0xbee2b108 & 0x0fffffff,
        MULTIPLE_DOMAINS_SWAP: 0xc29adb98 & 0x0fffffff,
        TON_SIMPLE_AUCTION: 0x48615374 & 0x0fffffff,
        TON_SIMPLE_OFFER: 0x1572efe4 & 0x0fffffff,
        JETTON_SIMPLE_OFFER: 0x08be756f & 0x0fffffff,
        MULTIPLE_OFFER: 0x97cb2a7a & 0x0fffffff,
        JETTON_SIMPLE_SALE: 0xd3f7025d & 0x0fffffff,
        JETTON_SIMPLE_AUCTION: 0x2ef72bde & 0x0fffffff,
        JETTON_MULTIPLE_SALE: 0xe32bc1bb & 0x0fffffff,
        TON_MULTIPLE_AUCTION: 0x54363e21 & 0x0fffffff,
        JETTON_MULTIPLE_AUCTION: 0x3630619a & 0x0fffffff,
    };
    
    static createFromAddress(address: Address) {
        return new Marketplace(address);
    }

    static createFromConfig(config: MarketplaceConfig, code: Cell, workchain = 0) {
        const data = marketplaceConfigToCell(config);
        const init = { code, data };
        return new Marketplace(contractAddress(workchain, init), init);
    }
    
    static deployDealWithJettonTransferPayload(senderAddress: Address, opCode: number, deployPayload: Cell, secretKey?: Buffer, signTime?: number, commissionDiscount: number = 0) {
        let discountCell = null;
        if (commissionDiscount > 0) {
            let tmp2 = beginCell()
                    .storeUint(signTime ?? Math.floor(Date.now() / 1000), 32)
                    .storeAddress(senderAddress)
                    .storeUint(commissionDiscount, 16)
            let signature = sign(tmp2.endCell().hash(), secretKey!!);
            discountCell = tmp2.storeRef(beginCell().storeBuffer(signature).endCell()).endCell();
        }
        return beginCell().storeUint(opCode, 32).storeMaybeRef(discountCell).storeSlice(deployPayload.beginParse()).endCell();
    }

    static deployDealWithNftTransferPayload(senderAddress: Address, opCode: number, domainName: string, deployPayload: Cell, secretKey?: Buffer, signTime?: number, commissionDiscount: number = 0) {
        let discountCell = null;
        if (commissionDiscount > 0) {
            let tmp2 = beginCell()
                    .storeUint(signTime ?? Math.floor(Date.now() / 1000), 32)
                    .storeAddress(senderAddress)
                    .storeUint(commissionDiscount, 16)
            let signature = sign(tmp2.endCell().hash(), secretKey!!);
            discountCell = tmp2.storeRef(beginCell().storeBuffer(signature).endCell()).endCell();
        }
        let domainZone = domainName.slice(domainName.indexOf('.'));
        let isTgUsername = domainZone == ".t.me";
        domainName = domainName.slice(0, domainName.indexOf('.'));
        return beginCell().storeUint(opCode, 32).storeBit(isTgUsername).storeStringRefTail(domainName).storeMaybeRef(discountCell).storeSlice(deployPayload.beginParse()).endCell();
    }

    async sendDeployDeal(provider: ContractProvider, via: Sender, value: bigint, opCode: number, deployPayload: Cell, 
                         secretKey?: Buffer, signTime?: number, commissionDiscount: number = 0, queryId: number = 0) {
        let discountCell = null;
        if (commissionDiscount > 0) {
            let tmp = beginCell()
                .storeUint(signTime ?? Math.floor(Date.now() / 1000), 32)
                .storeAddress(via.address!!)
                .storeUint(commissionDiscount, 16)
            let signature = sign(tmp.endCell().hash(), secretKey!!);
            discountCell = tmp.storeRef(beginCell().storeBuffer(signature).endCell()).endCell();
        }
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(opCode, 32).storeUint(queryId, 64).storeMaybeRef(discountCell).storeSlice(deployPayload.beginParse()).endCell(),
            bounce: true,
        });
    }

    static makeHotTransferPayload(saleAddress: Address, period: number) {
        return beginCell().storeUint(OpCodes.MAKE_HOT, 32).storeAddress(saleAddress).storeUint(period, 32).endCell();
    }

    static makeColoredTransferPayload(saleAddress: Address, period: number) {
        return beginCell().storeUint(OpCodes.MAKE_COLORED, 32).storeAddress(saleAddress).storeUint(period, 32).endCell();
    }

    static moveUpSaleTransferPayload(saleAddress: Address, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.MOVE_UP_SALE, 32).storeAddress(saleAddress).storeUint(queryId, 64).endCell();
    }

    static buySubscriptionMessage(subscriptionLevel: number, subscriptionPeriod: number, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.BUY_SUBSCRIPTION, 32).storeUint(queryId, 64).storeUint(subscriptionLevel, 8).storeUint(subscriptionPeriod, 32).endCell();
    }

    async sendBuySubscription(provider: ContractProvider, via: Sender, subscriptionLevel: number, subscriptionPeriod: number, subscriptionPrice: bigint, queryId: number = 0) {
        await provider.internal(via, {
            value: subscriptionPrice + toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: Marketplace.buySubscriptionMessage(subscriptionLevel, subscriptionPeriod, queryId),
            bounce: true,
        });
    }

    
    async getStorageData(provider: ContractProvider): Promise<MarketplaceConfig> {
        const { stack } = await provider.get('get_storage_data', []);

        return {
            ownerAddress: stack.readAddress(),
            publicKey: stack.readBigNumber(),
            deployInfos: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Uint(32), deployInfoValueParser()),
            
            userSubscriptions: beginCell().storeMaybeRef(stack.readCellOpt()).asSlice().loadDict(Dictionary.Keys.Address(), userSubscriptionValueParser()),
            subscriptionsInfo: beginCell().storeMaybeRef(stack.readCellOpt()).asSlice().loadDict(Dictionary.Keys.Uint(8), subscriptionInfoValueParser()),
            
            moveUpSalePrice: stack.readBigNumber(),
            currentTopSale: stack.readAddress(),

            usdtWalletAddress: stack.readAddress(), 
            web3WalletAddress: stack.readAddress(),

            collectedFeesTon: stack.readBigNumber(),
            collectedFeesUsdt: stack.readBigNumber(),
            collectedFeesWeb3: stack.readBigNumber(),

            hotPrices: stack.readCell().beginParse().loadDictDirect(Dictionary.Keys.Uint(32), hotPricesValueParser()),
        };
    }
}
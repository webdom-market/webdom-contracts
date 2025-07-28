import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { TonSimpleSaleDeployData } from './TonSimpleSale';

export type TonSimpleOfferConfig = {
    domainAddress: Address;
    price: bigint;
    state: number;
    commission: bigint;
    createdAt: number;
    sellerPrice: bigint;
    validUntil: number;
    buyerAddress: Address;
    sellerAddress: Maybe<Address>;
    domainName: string;
    cancelledBySeller?: boolean;
};

export class TonSimpleOfferDeployData extends TonSimpleSaleDeployData {
}


export function tonSimpleOfferConfigToCell(config: TonSimpleOfferConfig): Cell {
    return beginCell()
            .storeUint(config.state, 2)
            .storeCoins(config.price)
            .storeCoins(config.commission)
            .storeUint(config.validUntil, 32)
            .storeMaybeRef(config.sellerAddress ? beginCell().storeAddress(config.sellerAddress).endCell() : null)
            .storeBit(config.cancelledBySeller ?? 0)
            .storeCoins(0)
            .storeUint(config.createdAt, 32)
            .storeAddress(config.domainAddress)
            .storeAddress(config.buyerAddress)
            .storeStringRefTail(config.domainName)
            .storeBit(0)
        .endCell();
}

export class TonSimpleOffer extends DefaultContract {
    static DECLINE_REWARD = Tons.DECLINE_REWARD ;
    static STATE_NOT_INITIALIZED = 0;
    static STATE_ACTIVE = 1;
    static STATE_COMPLETED = 2;
    static STATE_CANCELLED = 3;

    static createFromAddress(address: Address) {
        return new TonSimpleOffer(address);
    }

    static createFromConfig(config: TonSimpleOfferConfig, code: Cell, workchain = 0) {
        const data = tonSimpleOfferConfigToCell(config);
        const init = { code, data };
        return new TonSimpleOffer(contractAddress(workchain, init), init);
    }

    static deployPayload(price: bigint, validUntil: number, sellerAddress: Address, domainName: string, notifySeller: boolean = true) {
        let domainZone = domainName.slice(domainName.indexOf('.')); 
        let isTgUsername = domainZone == ".t.me";
        let domainNameWithoutZone = domainName.slice(0, domainName.indexOf('.'));
        return beginCell()
                    .storeBit(isTgUsername)
                    .storeCoins(price)
                    .storeUint(validUntil, 32)
                    .storeAddress(sellerAddress)
                    .storeBit(notifySeller)
                    .storeStringRefTail(domainNameWithoutZone)
                .endCell();
    }

    static counterProposePayload(newPrice: bigint, notifyBuyer: boolean) {
        return beginCell().storeUint(OpCodes.COUNTERPROPOSE, 32).storeCoins(newPrice).storeBit(notifyBuyer).endCell();
    }

    static cancelOfferMessage(queryId: number = 0, cancellationComment?: string) {
        let body = beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId ?? 0, 64);
        if (cancellationComment) {
            body = body.storeStringTail(cancellationComment);
        }
        return body.endCell();
    }

    async sendCancelOffer(provider: ContractProvider, via: Sender, cancellationComment?: string, queryId?: number) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleOffer.cancelOfferMessage(queryId, cancellationComment)
        });
    }

    static changePriceMessage(queryId: number = 0, newPrice: bigint, newValidUntil: number, notifySeller: boolean) {
        return beginCell().storeUint(OpCodes.CHANGE_PRICE, 32).storeUint(queryId, 64).storeCoins(newPrice).storeUint(newValidUntil, 32).storeBit(notifySeller).endCell();
    }

    async sendChangePrice(provider: ContractProvider, via: Sender, oldPrice: bigint, oldCommission: bigint, newPrice: bigint, newValidUntil: number, notifySeller: boolean, queryId: number = 0, needPayFee: boolean = true) {
        const newCommission = (newPrice * oldCommission) / oldPrice;
        await provider.internal(via, {
            value: newPrice - oldPrice + newCommission - oldCommission + toNano('0.07') * (notifySeller ? 2n : 1n) + (needPayFee ? toNano('0.05') : 0n),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleOffer.changePriceMessage(queryId, newPrice, newValidUntil, notifySeller)
        });
    }

    static counterproposeMessage(newPrice: bigint, notifyBuyer: boolean, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.COUNTERPROPOSE, 32).storeUint(queryId, 64).storeCoins(newPrice).storeBit(notifyBuyer).endCell();
    }

    async sendCounterpropose(provider: ContractProvider, via: Sender, newPrice: bigint, notifyBuyer: boolean, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.07') + (notifyBuyer ? toNano('0.1') : 0n),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleOffer.counterproposeMessage(newPrice, notifyBuyer, queryId)
        });
    }
    static changeValidUntilMessage(queryId: number = 0, newValidUntil: number) {
        return beginCell().storeUint(OpCodes.CHANGE_VALID_UNTIL, 32).storeUint(queryId, 64).storeUint(newValidUntil, 32).endCell();
    }

    async sendChangeValidUntil(provider: ContractProvider, via: Sender, newValidUntil: number, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: TonSimpleOffer.changeValidUntilMessage(queryId, newValidUntil)
        });
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }

    async getStorageData(provider: ContractProvider): Promise<TonSimpleOfferConfig> {
        const { stack } = await provider.get('get_storage_data', []);
        let sellerAddress = stack.readAddressOpt();
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
            validUntil: stack.readNumber() + stack.readNumber(),  // 0 + validUntil
            buyerAddress: stack.readAddress(),
            domainName: stack.readCell().beginParse().loadStringTail(),
            cancelledBySeller: (stack.readNumber() == -1),
            sellerPrice: stack.readBigNumber()
        } 
    }
}

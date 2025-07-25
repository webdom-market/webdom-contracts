import { Address, beginCell, Builder, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, Slice, toNano } from '@ton/core';
import { COMMISSION_DIVIDER, OpCodes, Tons } from './helpers/constants';
import { DeployData } from './Marketplace';
import { DefaultContract } from './helpers/DefaultContract';
import { domainInListValueParser } from './JettonMultipleSale';
import { sign } from '@ton/crypto';

export class MultipleOfferDeployData extends DeployData {
    commissionFactor: number;
    web3CommissionFactor: number;

    constructor(data: Slice) {  
        super(data);
        this.commissionFactor = data.loadUint(16);
        this.web3CommissionFactor = data.loadUint(16);
    }

    static fromConfig(commissionFactor: number, web3CommissionFactor: number): MultipleOfferDeployData {
        return new MultipleOfferDeployData(beginCell().storeUint(commissionFactor, 16).storeUint(web3CommissionFactor, 16).endCell().beginParse());
    }
}

export interface DomainInOfferInfo {
    price: bigint;
    validUntil: number;
    jettonInfo?: {
        jettonWalletAddress: Address;
        oneJetton: bigint;
        jettonSymbol: string;
    }
}


export const domainInOfferValue = {
    serialize: (src: DomainInOfferInfo, builder: Builder) => {
        builder = builder.storeCoins(src.price).storeUint(src.validUntil, 32);
        if (src.jettonInfo) {
            const {jettonWalletAddress, oneJetton, jettonSymbol} = src.jettonInfo;
            builder = builder.storeBit(true).storeAddress(jettonWalletAddress).storeCoins(oneJetton).storeStringTail(jettonSymbol);
        }
        else {
            builder = builder.storeBit(false)
        }
        return builder;
    },
    parse: (src: Slice) => {
        const domainInOffer: DomainInOfferInfo = {
            price: src.loadCoins(),
            validUntil: src.loadUint(32),
        };
        if (src.loadBit()) {
            domainInOffer.jettonInfo = {
                jettonWalletAddress: src.loadAddress(),
                oneJetton: src.loadCoins(),
                jettonSymbol: src.loadStringTail()
            }
        }
        return domainInOffer;
    }
}


export type MultipleOfferConfig = {
    ownerAddress: Address;
    merkleRoot: bigint;
    soldNftsDict: Dictionary<Address, number>;
    jettonBalancesDict: Dictionary<Address, bigint>;
    publicKey: bigint;
    commissionFactor: number;
    web3CommissionFactor: number;
    web3WalletAddress?: Address;
};


export function multipleTonOfferConfigToCell(config: MultipleOfferConfig): Cell {
    return beginCell()
            .storeAddress(config.ownerAddress)
            .storeUint(config.merkleRoot, 256)
            .storeDict(config.soldNftsDict)
            .storeDict(config.jettonBalancesDict)
            .storeRef(beginCell().storeUint(config.publicKey, 256).endCell())
            .storeUint(config.commissionFactor, 16)
            .storeUint(config.web3CommissionFactor, 16)
            .storeUint(0, 2)
        .endCell();
}


export class MultipleOffer extends DefaultContract {
    static STATE_UNINIT = 0;
    static STATE_ACTIVE = 1;

    static createFromAddress(address: Address) {
        return new MultipleOffer(address);
    }

    static createFromConfig(config: MultipleOfferConfig, code: Cell, workchain = 0) {
        const data = multipleTonOfferConfigToCell(config);
        const init = { code, data };
        return new MultipleOffer(contractAddress(workchain, init), init);
    }

    static deployMessage(merkleRoot: bigint, web3WalletAddress: Address, commissionFactor: number, web3CommissionFactor: number) {
        return beginCell()
            .storeUint(merkleRoot, 256)
            .storeUint(commissionFactor, 16)
            .storeUint(web3CommissionFactor, 16)
            .storeAddress(web3WalletAddress)
        .endCell();
    }

    static deployPayload(merkleRoot: bigint) {
        return beginCell()
            .storeUint(merkleRoot, 256)
        .endCell();
    }

    static changeDataPayload(merkleRoot: bigint, signTime: number, contractAddress: Address, privateKey: Buffer, queryId: number = 0) {
        let updateInfo = beginCell()
                    .storeUint(signTime, 32)
                    .storeAddress(contractAddress)
                    .storeUint(merkleRoot, 256)
        const signature = sign(updateInfo.endCell().hash(), privateKey);
        return beginCell()
            .storeUint(OpCodes.SET_NEW_DATA, 32)
            .storeUint(queryId, 64)
            .storeRef(updateInfo)
            .storeRef(beginCell().storeBuffer(signature).endCell())
        .endCell();
    }

    static sellNftPayload(nftAddress: Address, entriesDict: Dictionary<Address, DomainInOfferInfo>) {
        return entriesDict.generateMerkleProof([nftAddress]);
    }

    static withdrawTonPayload(amount: bigint, queryId: number = 0) {
        return beginCell()
            .storeUint(OpCodes.WITHDRAW_TON, 32)
            .storeUint(queryId, 64)
            .storeCoins(amount)
        .endCell();
    }

    static fillUpJettonBalancePayload(tonAmountToReserve: bigint, queryId: number = 0) {
        if (tonAmountToReserve > 0n) {
            return beginCell().storeBit(true).storeCoins(tonAmountToReserve).endCell();
        }
        return beginCell().storeBit(false).endCell();
    }

    async sendChangeData(provider: ContractProvider, via: Sender, merkleRoot: bigint, signTime: number, contractAddress: Address, privateKey: Buffer, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: MultipleOffer.changeDataPayload(merkleRoot, signTime, contractAddress, privateKey, queryId),
        });
    }


    async sendWithdrawTonAmount(provider: ContractProvider, via: Sender, amount: bigint) {
        await provider.internal(via, {
            value: toNano('0.01'),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: MultipleOffer.withdrawTonPayload(amount),
        });
    }


    async getStorageData(provider: ContractProvider): Promise<MultipleOfferConfig> {
        const {stack} = await provider.get('get_storage_data', []);
        const res: MultipleOfferConfig =  {
            ownerAddress: stack.readAddress(),
            merkleRoot: stack.readBigNumber(),
            publicKey: stack.readBigNumber(),
            commissionFactor: stack.readNumber(),
            web3CommissionFactor: stack.readNumber(),
            soldNftsDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(32)),
            jettonBalancesDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.BigUint(256)),
        }
        const soldNftsCell = stack.readCellOpt();
        if (soldNftsCell) {
            res.soldNftsDict = soldNftsCell.beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.Uint(32));
        }
        const jettonBalancesCell = stack.readCellOpt();
        if (jettonBalancesCell) {
            res.jettonBalancesDict = jettonBalancesCell.beginParse().loadDictDirect(Dictionary.Keys.Address(), Dictionary.Values.BigVarUint(4));
        }
        res.web3WalletAddress = stack.readAddress();
        return res;
    }
}

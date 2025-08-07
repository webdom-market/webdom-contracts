import { Contract, ContractProvider, Sender, Address, beginCell, SendMode, Cell, toNano, DictionaryValue } from "@ton/core";
import { OpCodes } from "./constants";
import { Maybe } from "@ton/core/dist/utils/maybe";

export function stringValueParser(): DictionaryValue<string> {
    return {
        serialize: (src, buidler) => {
            buidler.storeStringTail(src);
        },
        parse: (src) => {
            return src.loadStringTail();
        }
    }
}

export class DefaultContract implements Contract {

    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}
    
    static createFromAddress(address: Address) {
        return new DefaultContract(address);
    }

    static fillUpBalanceMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.FILL_UP_BALANCE, 32).storeUint(queryId, 64).endCell();
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint, deployPayload?: Cell) {
        let body = beginCell().storeSlice(DefaultContract.fillUpBalanceMessage(0).asSlice());
        if (deployPayload) {
            body.storeSlice(deployPayload.asSlice());
        }
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: body.endCell(),
        });
    }
    
    async sendFillUpBalance(provider: ContractProvider, via: Sender, value: bigint, queryId: number = 0) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.fillUpBalanceMessage(queryId),
        });
    }

    async sendMessageWithComment(provider: ContractProvider, via: Sender, value: bigint, comment: string) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().storeUint(0, 32).storeStringTail(comment).endCell(),
        });
    }

    static withdrawSomeTonMessage(queryId: number = 0, reserveAmount: bigint) {
        return beginCell().storeUint(OpCodes.WITHDRAW_TON, 32).storeUint(queryId, 64).storeCoins(reserveAmount).endCell();
    }
    
    async sendWithdrawSomeTon(provider: ContractProvider, via: Sender, queryId: number = 0, reserveAmount: bigint) {
        await provider.internal(via, {
            value: toNano("0.01"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.withdrawSomeTonMessage(queryId, reserveAmount),
        });
    }

    static withdrawTonMessage(tonsToReserve: bigint = 0n, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.WITHDRAW_TON, 32).storeUint(queryId, 64).storeCoins(tonsToReserve).endCell();
    }

    async sendWithdrawTon(provider: ContractProvider, via: Sender, tonsToReserve: bigint = 0n, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.01"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.withdrawTonMessage(tonsToReserve, queryId),
        });
    }

    static withdrawJettonMessage(jettonWalletAddress: Address, amount: bigint, queryId: number = 0) {
        return beginCell()
                    .storeUint(OpCodes.WITHDRAW_JETTON, 32)
                    .storeUint(queryId, 64)
                    .storeAddress(jettonWalletAddress)
                    .storeCoins(amount)
                .endCell()
    }

    async sendWithdrawJetton(provider: ContractProvider, via: Sender, jettonWalletAddress: Address, amount: bigint, queryId: number = 0) {
            await provider.internal(via, {
                value: toNano("0.06"),
                sendMode: SendMode.PAY_GAS_SEPARATELY,
                body: DefaultContract.withdrawJettonMessage(jettonWalletAddress, amount, queryId),
        });
    }

    static withdrawNftMessage(nftAddress: Address, queryId: number = 0) {
        return beginCell()
                    .storeUint(OpCodes.WITHDRAW_NFT, 32)
                    .storeUint(queryId, 64)
                    .storeAddress(nftAddress)
                .endCell()
    }
    
    async sendWithdrawNft(provider: ContractProvider, via: Sender, nftAddress: Address, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.06"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.withdrawNftMessage(nftAddress, queryId),
        });
    }

    static setCodeMessage(code: Maybe<Cell>, data: Maybe<Cell>, queryId: number = 0) {
        return beginCell()
                    .storeUint(OpCodes.SET_CODE, 32)
                    .storeUint(queryId, 64)
                    .storeMaybeRef(code)
                    .storeMaybeRef(data)
            .endCell();
    }

    async sendChangeCode(provider: ContractProvider, via: Sender, code: Maybe<Cell>, data: Maybe<Cell>, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.02"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.setCodeMessage(code, data, queryId),
        });
    }

    static sendAnyMessageMessage(toAddress: Address, payload: Cell, stateInit: Maybe<Cell> = null, queryId: number = 0, messageMode: number = 64) {
        let res = beginCell().storeUint(OpCodes.SEND_ANY_MESSAGE, 32).storeUint(queryId ?? 0, 64).storeAddress(toAddress).storeRef(payload ?? beginCell().endCell()).storeMaybeRef(stateInit);
        if (messageMode) {
            res.storeBit(true);
            res.storeUint(messageMode, 8);
        } else {
            res.storeBit(false);
        }
        return res.endCell();
    }

    async sendSendAnyMessage(provider: ContractProvider, via: Sender, value: bigint, toAddress: Address, payload: Cell, stateInit: Maybe<Cell> = null, queryId: number = 0, messageMode: number = 64) {
        await provider.internal(via, {
            value: value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.sendAnyMessageMessage(toAddress, payload, stateInit, queryId, messageMode),
        })
    }

    async sendSendSendAnyMessage(provider: ContractProvider, via: Sender, value: bigint, senderAddress: Address, toAddress: Address, payload: Cell, stateInit: Maybe<Cell> = null, queryId: number = 0, messageMode: number = 64) {
        await provider.internal(via, {
            value: value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: DefaultContract.sendAnyMessageMessage(senderAddress, DefaultContract.sendAnyMessageMessage(toAddress, payload, stateInit, queryId, messageMode), null, queryId, 64),
        })
    }

    async sendExternalCancel(provider: ContractProvider, queryId: number = 0) {
        await provider.external(beginCell().storeUint(OpCodes.CANCEL_DEAL, 32).storeUint(queryId, 64).endCell());
    }

    async getStorageData(provider: ContractProvider): Promise<any> {
        throw new Error("Method not implemented.");
    }
}
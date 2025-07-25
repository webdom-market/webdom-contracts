import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode, toNano } from '@ton/core';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { OpCodes } from './helpers/constants';

export type JettonWalletConfig = {};

export function jettonWalletConfigToCell(config: JettonWalletConfig): Cell {
    return beginCell().endCell();
}

export class JettonWallet implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new JettonWallet(address);
    }

    static createFromConfig(config: JettonWalletConfig, code: Cell, workchain = 0) {
        const data = jettonWalletConfigToCell(config);
        const init = { code, data };
        return new JettonWallet(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    async getJettonBalance(provider: ContractProvider) {
        let state = await provider.getState();
        if (state.state.type !== 'active') {
            return 0n;
        }
        let res = await provider.get('get_wallet_data', []);
        return res.stack.readBigNumber();
    }

    static transferMessage(jetton_amount: bigint, 
                            toAddress: Address,
                            responseAddress: Address,
                            forwardTonAmount: bigint,
                            forwardPayload: Maybe<Cell>,
                            queryId?: number) {
                                
        return beginCell()
                    .storeUint(OpCodes.TRANSFER_JETTON, 32)
                    .storeUint(queryId ?? 0, 64)
                    .storeCoins(jetton_amount)
                    .storeAddress(toAddress)
                    .storeAddress(responseAddress)
                    .storeBit(0)
                    .storeCoins(forwardTonAmount)
                    .storeMaybeRef(forwardPayload)
                .endCell();
    }

    async sendTransfer(provider: ContractProvider,
                        via: Sender,
                        jettonAmount: bigint, 
                        toAddress: Address,
                        responseAddress:Address,
                        forwardTonAmount: bigint,
                        forwardPayload?: Maybe<Cell>) {
        await provider.internal(via, {
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonWallet.transferMessage(jettonAmount, toAddress, responseAddress, forwardTonAmount, forwardPayload),
            value: toNano('0.05') + forwardTonAmount
        });
    }

    static transferNotificationMessage(jettonAmount: bigint, fromAddress: Address, forwardPayload?: Maybe<Cell>, queryId?: number) {
        return beginCell()
                    .storeUint(OpCodes.TRANSFER_NOTIFICATION, 32)
                    .storeUint(queryId ?? 0, 64)
                    .storeCoins(jettonAmount)
                    .storeAddress(fromAddress)
                    .storeMaybeRef(forwardPayload)
                .endCell();
    }

    static parseTransferNotificationMessage(cell: Cell) {
        const parsed = cell.beginParse();
        const opCode = parsed.loadUint(32);
        if (opCode != OpCodes.TRANSFER_NOTIFICATION) {
            throw new Error('Invalid op code');
        }
        const queryId = parsed.loadUint(64);
        const jettonAmount = parsed.loadCoins();
        const fromAddress = parsed.loadAddress();
        const forwardPayload = parsed.loadMaybeRef();
        return { queryId, jettonAmount, fromAddress, forwardPayload };
    }
    
    /*
      burn#595f07bc query_id:uint64 amount:(VarUInteger 16)
                    response_destination:MsgAddress custom_payload:(Maybe ^Cell)
                    = InternalMsgBody;
    */
    static burnMessage(jetton_amount: bigint,
                       responseAddress:Address,
                       customPayload: Cell) {
        return beginCell()
                    .storeUint(OpCodes.BURN_JETTON, 32)
                    .storeUint(0, 64)
                    .storeCoins(jetton_amount).storeAddress(responseAddress)
                    .storeMaybeRef(customPayload)
               .endCell();
    }

    async sendBurn(provider: ContractProvider, via: Sender, value: bigint,
                          jetton_amount: bigint,
                          responseAddress:Address,
                          customPayload: Cell) {
        await provider.internal(via, {
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonWallet.burnMessage(jetton_amount, responseAddress, customPayload),
            value:value
        });

    }
    /*
      withdraw_tons#107c49ef query_id:uint64 = InternalMsgBody;
    */
    static withdrawTonsMessage() {
        return beginCell().storeUint(0x6d8e5e3c, 32).storeUint(0, 64).endCell();
    }

    async sendWithdrawTons(provider: ContractProvider, via: Sender) {
        await provider.internal(via, {
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonWallet.withdrawTonsMessage(),
            value:toNano('0.1')
        });

    }
    /*
      withdraw_jettons#10 query_id:uint64 wallet:MsgAddressInt amount:Coins = InternalMsgBody;
    */
    static withdrawJettonsMessage(from:Address, amount:bigint) {
        return beginCell().storeUint(0x768a50b2, 32).storeUint(0, 64) // op, queryId
                          .storeAddress(from)
                          .storeCoins(amount)
                          .storeMaybeRef(null)
               .endCell();
    }

    async sendWithdrawJettons(provider: ContractProvider, via: Sender, from:Address, amount:bigint) {
        await provider.internal(via, {
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: JettonWallet.withdrawJettonsMessage(from, amount),
            value:toNano('0.1')
        });

    }
}

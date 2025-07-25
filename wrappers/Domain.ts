import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode, toNano } from '@ton/core';
import { getAddressByDomainName, getIndexByDomainName, getMinPrice } from './helpers/dnsUtils';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { OpCodes } from './helpers/constants';

export type DomainConfig = {
    name?: string;
    index: bigint;
    ownerAddress?: Address;
    dnsCollectionAddress: Address;
    lastRenewalTime?: number;
    init?: boolean;
};

export function domainConfigToCell(config: DomainConfig): Cell {
    return beginCell()
        .storeUint(config.index, 256)
        .storeAddress(config.dnsCollectionAddress)
    .endCell();
}

export class Domain implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new Domain(address);
    }

    static createFromConfig(config: DomainConfig, code: Cell, workchain = 0) {
        const data = domainConfigToCell(config);
        const init = { code, data };
        return new Domain(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    static transferMessage(newOwner: Address, responseAddress: Maybe<Address> = null, 
                          forwardPayload: Maybe<Cell> = null, forwardAmount: bigint = 0n, queryId: number = 0) {
        return beginCell()
            .storeUint(OpCodes.TRANSFER_NFT, 32)
            .storeUint(queryId, 64)
            .storeAddress(newOwner)
            .storeAddress(responseAddress)
            .storeBit(false) // no custom payload
            .storeCoins(forwardAmount)
            .storeMaybeRef(forwardPayload)
        .endCell();
    }

    async sendTransfer(provider: ContractProvider, via: Sender, newOwner: Address, responseAddress: Maybe<Address> = null, 
                      forwardPayload: Maybe<Cell> = null, forwardAmount: bigint = 0n, queryId: number = 0, additionalGas: bigint = 0n) {
        await provider.internal(via, {
            value: toNano("0.03") + forwardAmount + additionalGas,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: Domain.transferMessage(newOwner, responseAddress, forwardPayload, forwardAmount, queryId)
        });
    }

    static startAuctionMessage(queryId: number = 0) {
        return beginCell().storeUint(OpCodes.DNS_BALANCE_RELEASE, 32).storeUint(queryId, 64).endCell();
    }

    async sendStartAuction(provider: ContractProvider, via: Sender, domain: string, queryId: number = 0) {
        await provider.internal(via, {
            value: getMinPrice(domain.length),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: Domain.startAuctionMessage(queryId)
        });
    }

    static changeContentMessage(content: Cell, queryId: number = 0) {
        return beginCell().storeUint(OpCodes.EDIT_CONTENT, 32).storeUint(queryId, 64).storeRef(content).endCell();
    }
    
    async sendChangeContent(provider: ContractProvider, via: Sender, content: Cell, queryId: number = 0) {
        await provider.internal(via, {
            value: toNano("0.01"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: Domain.changeContentMessage(content, queryId)
        });
    }

    static ownershipAssignedMessage(queryId: number = 0, fromAddress: Address, forwardPayload?: Cell) {
        return beginCell()
            .storeUint(OpCodes.OWNERSHIP_ASSIGNED, 32)
            .storeUint(queryId, 64)
            .storeAddress(fromAddress)
            .storeMaybeRef(forwardPayload)
        .endCell();
    }

    static parseOwnershipAssignedMessage(cell: Cell) {
        const parsed = cell.beginParse()
        const opCode = parsed.loadUint(32);
        if (opCode != OpCodes.OWNERSHIP_ASSIGNED) {
            throw new Error('Invalid op code');
        }
        const queryId = parsed.loadUint(64);
        const fromAddress = parsed.loadAddress();
        const forwardPayload = parsed.loadMaybeRef();
        return { queryId, fromAddress, forwardPayload };
    }

    async getStorageData(provider: ContractProvider): Promise<DomainConfig> {
        let { stack: stack_1 } = await provider.get('get_nft_data', []);
        let res: any = {
            init: stack_1.readBoolean(),
            index: stack_1.readBigNumber(),
            dnsCollectionAddress: stack_1.readAddress(),
            ownerAddress: stack_1.readAddress()
        };

        try {
            let {stack: stack_2} = await provider.get('get_domain', []);
            res.name = stack_2.readString() + '.ton';
            let {stack: stack_3} = await provider.get('get_last_fill_up_time', []);
            res.lastRenewalTime = stack_3.readNumber();
        } catch (e) {
            let {stack: stack_2} = await provider.get('get_telemint_token_name', []);
            res.name = stack_2.readString() + ".t.me";
        }
        
        return res;
    }
}
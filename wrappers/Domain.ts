import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Dictionary, Sender, SendMode, toNano } from '@ton/core';
import { getAddressByDomainName, getIndexByDomainName, getMinPrice } from './helpers/dnsUtils';
import { Maybe } from '@ton/core/dist/utils/maybe';
import { OpCodes } from './helpers/constants';

// DNS record category keys = sha256 of the category name (kept in sync with webdom-front Domain.ts).
export const DnsRecordType = {
    linkedWallet: 105311596331855300602201538317979276640056460191511695660591596829410056223515n,
    linkedTonSite: 113837984718866553357015413641085683664993881322709313240352703269157551621118n,
    linkedTonStorage: 33305727148774590499946634090951755272001978043137765208040544350030765946327n,
    picture: 20315478796101526927034168858260897194377925503629377592419468163308831956119n,
    image: 43884663033947008978309661017057008345326326811558777475113826163084742639165n,
    description: 90922719342317012409671596374183159143637506542604000676488204638996496437508n,
    links: 108089919688644910349473043874437213641876104892722189538558092237626533583083n,
} as const;

/**
 * Encodes a UTF-8 string into a `dns_text#1eda` value cell (chunked TL-B), identical to the
 * webdom-front encoder. First chunk inline (≤123 bytes), each next chunk in its own ref (≤126 bytes).
 */
export function createTextRecordCell(text: string): Cell {
    const data = Buffer.from(text, 'utf8');
    const FIRST_CHUNK_MAX = 123;
    const CHUNK_MAX = 126;
    const lengths: number[] = [];
    let remaining = data.length;
    while (remaining > 0) {
        const take = Math.min(remaining, lengths.length === 0 ? FIRST_CHUNK_MAX : CHUNK_MAX);
        lengths.push(take);
        remaining -= take;
    }
    const root = beginCell().storeUint(0x1eda, 16).storeUint(lengths.length, 8);
    if (lengths.length === 0) return root.endCell();
    let offset = data.length;
    let next: Cell | undefined;
    for (let i = lengths.length - 1; i >= 1; i--) {
        offset -= lengths[i];
        const chunk = beginCell().storeUint(lengths[i], 8).storeBuffer(data.subarray(offset, offset + lengths[i]));
        if (next) chunk.storeRef(next);
        next = chunk.endCell();
    }
    root.storeUint(lengths[0], 8).storeBuffer(data.subarray(0, lengths[0]));
    if (next) root.storeRef(next);
    return root.endCell();
}

/** Value cell for a `wallet` record (`dns_smc_address#9fd3`). */
export function createWalletRecordCell(walletAddress: Address): Cell {
    return beginCell().storeUint(0x9fd3, 16).storeAddress(walletAddress).storeUint(0, 8).endCell();
}

/**
 * Builds the marketplace `dnsRecordsDict` (key 256 -> value ref) from a map of record-type -> value
 * cell. Use `createTextRecordCell` / `createWalletRecordCell` to build the values. Only put
 * domain-agnostic records here — the same dict is applied to every domain on listing.
 */
export function buildDnsRecordsDict(records: Partial<Record<keyof typeof DnsRecordType, Cell>>): Dictionary<bigint, Cell> {
    const dict = Dictionary.empty(Dictionary.Keys.BigUint(256), Dictionary.Values.Cell());
    for (const [type, value] of Object.entries(records)) {
        if (value) dict.set(DnsRecordType[type as keyof typeof DnsRecordType], value);
    }
    return dict;
}

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

    static changeDnsRecordMessage(key: bigint, value: Maybe<Cell> = null, queryId: number = 0) {
        const body = beginCell()
            .storeUint(OpCodes.CHANGE_DNS_RECORD, 32)
            .storeUint(queryId, 64)
            .storeUint(key, 256);
        // A present value ref => set the record; no ref => delete the record.
        if (value) {
            body.storeRef(value);
        }
        return body.endCell();
    }

    async sendChangeDnsRecord(provider: ContractProvider, via: Sender, key: bigint,
                              value: Maybe<Cell> = null, queryId: number = 0, value_ton: bigint = toNano("0.02")) {
        await provider.internal(via, {
            value: value_ton,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: Domain.changeDnsRecordMessage(key, value, queryId)
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
            value: toNano("0.001"),
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
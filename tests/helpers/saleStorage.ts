import { Address, beginCell, Builder, Cell, Slice } from '@ton/core';
import { Blockchain } from '@ton/sandbox';

/**
 * Where `price` and `commission` sit in a fix-price sale's storage:
 *   tonSimple    — domainAddress, sellerAddress, price, state:uint2, commission, ...
 *   jettonSimple — jettonWalletAddress?, sellerAddress, price, state:uint2, commission, ...
 *   multiple     — sellerAddress, domainsDict, domainsTotal:uint8, domainsReceived:uint8, price, commission, ...
 *                  (TonMultipleSale and JettonMultipleSale)
 *
 * The `get_storage_data` getters only expose commission as a rate, so tests that need the exact
 * stored amount (or a state only an older contract version could reach) go through the raw cell.
 */
export type SaleLayout = 'tonSimple' | 'jettonSimple' | 'multiple';

type ParsedPricing = { head: Builder; price: bigint; state: number | null; commission: bigint; tail: Slice };

function parsePricing(data: Cell, layout: SaleLayout): ParsedPricing {
    const s = data.beginParse();
    const head = beginCell();
    if (layout === 'multiple') {
        head.storeAddress(s.loadAddress())
            .storeMaybeRef(s.loadMaybeRef())
            .storeUint(s.loadUint(8), 8)
            .storeUint(s.loadUint(8), 8);
    } else {
        head.storeAddress(layout === 'tonSimple' ? s.loadAddress() : s.loadMaybeAddress())
            .storeAddress(s.loadAddress());
    }
    const price = s.loadCoins();
    const state = layout === 'multiple' ? null : s.loadUint(2);
    const commission = s.loadCoins();
    return { head, price, state, commission, tail: s };
}

async function loadActive(blockchain: Blockchain, address: Address) {
    const contract = await blockchain.getContract(address);
    const account = contract.account;
    const state = account.account?.storage.state;
    if (state?.type !== 'active' || !state.state.data) {
        throw new Error(`${address} is not an active contract`);
    }
    return { contract, account, stateInit: state.state };
}

export async function readSalePricing(blockchain: Blockchain, address: Address, layout: SaleLayout) {
    const { stateInit } = await loadActive(blockchain, address);
    const { price, commission } = parsePricing(stateInit.data!, layout);
    return { price, commission };
}

export async function writeSalePricing(
    blockchain: Blockchain,
    address: Address,
    layout: SaleLayout,
    price: bigint,
    commission: bigint,
) {
    const { contract, account, stateInit } = await loadActive(blockchain, address);
    const parsed = parsePricing(stateInit.data!, layout);
    const b = parsed.head.storeCoins(price);
    if (parsed.state !== null) {
        b.storeUint(parsed.state, 2);
    }
    stateInit.data = b.storeCoins(commission).storeSlice(parsed.tail).endCell();
    contract.account = account;
}

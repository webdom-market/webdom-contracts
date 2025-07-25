import { Address, beginCell, Cell } from "@ton/core";
import { ONE_TON } from "./constants";

export function packStateInit(code: Cell, data: Cell): Cell {
    return beginCell()
        .storeUint(0, 2)
        .storeMaybeRef(code)
        .storeMaybeRef(data)
        .storeUint(0, 1)
    .endCell();
}

export function getAddressByStateInit(stateInit: Cell): Address {
    return beginCell()
                .storeUint(1024, 11)
                .storeUint(BigInt('0x' + stateInit.hash().toString('hex')), 256)
            .endCell().beginParse().loadAddress();
}


export function getIndexByDomainName(domainName: string): bigint {
    return BigInt(beginCell().storeStringTail(domainName).endCell().hash().toString('hex'));
}

export function getAddressByDomainName(domainName: string, domainCode: Cell,dnsCollectionAddress: Address): Address {
    const domainIndex = getIndexByDomainName(domainName);
    const domainData = beginCell().storeUint(domainIndex, 256).storeAddress(dnsCollectionAddress).endCell();
    return getAddressByStateInit(packStateInit(domainCode, domainData));
}


export function getMinPrice(domainLength: number) {
    if (domainLength < 4 || domainLength > 126) {
        throw new Error('Domain length must be between 4 and 126 characters');
    }
    if (domainLength == 4) {
        return 100n * ONE_TON;
    }
    if (domainLength == 5) {
        return 50n * ONE_TON;
    }   
    if (domainLength == 6) {
        return 40n * ONE_TON;
    }
    if (domainLength == 7) {
        return 30n * ONE_TON;
    }
    if (domainLength == 8) {
        return 20n * ONE_TON;
    }
    if (domainLength == 9) {
        return 10n * ONE_TON;
    }
    if (domainLength == 10) {
        return 5n * ONE_TON;
    }
    return 1n * ONE_TON;
}
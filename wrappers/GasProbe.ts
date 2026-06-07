import {
    Address,
    beginCell,
    Cell,
    Contract,
    contractAddress,
    ContractProvider,
    Sender,
    SendMode,
} from '@ton/core';

// Minimal wrapper around contracts/gas_probe.tolk — exposes the migrated fee helpers as get-methods
// so a test can read the EXACT on-chain TON value under whichever network price config is active.
export class GasProbe implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new GasProbe(address);
    }

    static createFromConfig(_config: Record<string, never>, code: Cell, workchain = 0) {
        const data = beginCell().endCell();
        const init = { code, data };
        return new GasProbe(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    private async getInt(provider: ContractProvider, method: string, args: bigint[] = []): Promise<bigint> {
        const res = await provider.get(
            method,
            args.map((v) => ({ type: 'int' as const, value: v })),
        );
        return res.stack.readBigNumber();
    }

    // primitives
    async getGas(provider: ContractProvider, units: bigint) { return this.getInt(provider, 'gas', [units]); }
    async getFwd(provider: ContractProvider, bits: bigint, cells: bigint) { return this.getInt(provider, 'fwd', [bits, cells]); }
    async getStorageYear(provider: ContractProvider, bits: bigint, cells: bigint) { return this.getInt(provider, 'storage_year', [bits, cells]); }

    // domain helpers
    async getNftTransferFee(provider: ContractProvider) { return this.getInt(provider, 'nft_transfer_fee'); }
    async getDomainRefillFee(provider: ContractProvider) { return this.getInt(provider, 'domain_refill_fee'); }
    async getRenewDomainFee(provider: ContractProvider) { return this.getInt(provider, 'renew_domain_fee'); }

    // fix-price sales
    async getTonSimplePurchase(provider: ContractProvider) { return this.getInt(provider, 'ton_simple_purchase'); }
    async getTonSimplePurchaseFee(provider: ContractProvider) { return this.getInt(provider, 'ton_simple_purchase_fee'); }
    async getAutoRenewLockPerIter(provider: ContractProvider) { return this.getInt(provider, 'auto_renew_lock_per_iter'); }

    // auctions
    async getEndTonAuction(provider: ContractProvider) { return this.getInt(provider, 'end_ton_auction'); }
    async getEndJettonAuction(provider: ContractProvider) { return this.getInt(provider, 'end_jetton_auction'); }

    // offers
    async getTonSimpleOfferReserve(provider: ContractProvider) { return this.getInt(provider, 'ton_simple_offer_reserve'); }
    async getJettonSimpleOfferReserve(provider: ContractProvider) { return this.getInt(provider, 'jetton_simple_offer_reserve'); }
    async getOfferExecutionPad(provider: ContractProvider) { return this.getInt(provider, 'offer_execution_pad'); }
    async getOfferChangePriceGas(provider: ContractProvider) { return this.getInt(provider, 'offer_change_price_gas'); }
    async getOfferCounterproposeGas(provider: ContractProvider) { return this.getInt(provider, 'offer_counterpropose_gas'); }

    // domain swap
    async getAddDomain(provider: ContractProvider) { return this.getInt(provider, 'add_domain'); }
    async getAddPayment(provider: ContractProvider) { return this.getInt(provider, 'add_payment'); }
    async getSwapDeploy(provider: ContractProvider, domainsTotal: bigint) { return this.getInt(provider, 'swap_deploy', [domainsTotal]); }
    async getSwapStorageYear(provider: ContractProvider, domainsTotal: bigint) { return this.getInt(provider, 'swap_storage_year', [domainsTotal]); }
}

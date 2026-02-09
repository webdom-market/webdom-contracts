import "../../imports/constants"

const TONS_STORAGE_PER_YEAR: coins = ton("0.035");

@inline
fun getAutoRenewLockPerIter(domainsTotal: uint8): coins {
    return TONS_STORAGE_PER_YEAR + TONS_AUTORENEW_TX_PER_ITER * domainsTotal;
}

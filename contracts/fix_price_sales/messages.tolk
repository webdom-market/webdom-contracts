struct (0x2e9ead29) RenewDomainMessage {
    queryId: uint64;
    newValidUntil: uint32?;
}

struct (0x96189f94) ChangePriceMessage {
    queryId: uint64;
    newPrice: coins;
    newValidUntil: uint32;
}

struct (0x4ed14b65) DnsBalanceReleaseMessage {
    queryId: uint64;
}

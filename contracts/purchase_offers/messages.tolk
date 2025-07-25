struct (0xfa5a9543) CounterProposePayload {
    sellerPrice: coins
    notifyBuyer: bool
}

struct (0x96189f94) ChangePriceMessage {
    queryId: uint64;
    newPrice: coins;
    newValidUntil: uint32;
    notifySeller: bool;
}

struct (0xfa5a9543) CounterProposeMessage {
    queryId: uint64;
    sellerPrice: coins;
    notifyBuyer: bool;
}

struct (0xfd265ff8) ChangeValidUntilMessage {
    queryId: uint64;
    newValidUntil: uint32;
}

struct OneSideInfo {
    ownerAddress: address;
    domainsTotal: uint8;
    domainsReceived: uint8;
    domainsDict: dict;
    paymentTotal: coins;
    paymentReceived: coins;
}

struct Storage {
    leftInfo: Cell<OneSideInfo>;
    rightInfo: Cell<OneSideInfo>;

    state: uint2;
    createdAt: uint32;
    validUntil: uint32;
    lastActionTime: uint32;
    completionCommission: coins;
    needsAlert: bool;
    cancelledByLeft: bool;
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

fun Storage.save(self): void {
    contract.setData(self.toCell())
}

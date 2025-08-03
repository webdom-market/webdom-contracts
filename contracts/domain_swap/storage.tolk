struct OneSideInfo {
    domainsTotal: uint8;
    domainsReceived: uint8;
    domainsDict: dict;
    paymentTotal: coins;
    paymentReceived: coins;
}

struct Storage {
    leftParticipantAddress: address;
    leftInfo: Cell<OneSideInfo>;

    rightParticipantAddress: address;
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

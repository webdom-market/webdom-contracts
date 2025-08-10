struct OneSideInfo {
    domainsTotal: uint8;       // Total number of domains on one side
    domainsReceived: uint8;    // Number of domains received from the participant
    domainsDict: dict;         // Dictionary of domains (address -> boolean received flag)
    paymentTotal: coins;       // Total amount of payment on one side
    paymentReceived: coins;    // Amount of payment received from the participant
}

struct Storage {
    leftParticipantAddress: address;  // Address of the left participant
    leftInfo: Cell<OneSideInfo>;      // Requirements for the left participant

    rightParticipantAddress: address; // Address of the right participant
    rightInfo: Cell<OneSideInfo>;     // Requirements for the right participant

    state: uint2;                     // State of the contract (UNINIT, WAITING_FOR_LEFT, WAITING_FOR_RIGHT, COMPLETED, CANCELLED)
    createdAt: uint32;                // Timestamp of the contract creation
    validUntil: uint32;               // Timestamp of the contract expiration
    lastActionTime: uint32;           // Timestamp of the last action with the contract
    completionCommission: coins;      // Commission for the completion of the contract
    needsAlert: bool;                 // Flag to check if the contract has to send onchain notifications to the participants
    cancelledByLeft: bool;            // Flag to check if the contract was cancelled by the left participant
}

fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData())
}

fun Storage.save(self): void {
    contract.setData(self.toCell())
}

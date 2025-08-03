import "constants";
import "storage";
import "../imports/constants";
import "../imports/messages";
import "@stdlib/gas-payments";
import "@stdlib/tvm-dicts";

// Executes when the left participant completes his part of the deal
@inline
fun completeLeftPart(storage: Storage, leftInfo: OneSideInfo) {
    setGasLimitToMaximum();

    // Notify the right participant about the new offer
    if (storage.needsAlert) {
        createMessage({
            dest: storage.rightParticipantAddress,
            value: TONS_OFFER_NOTIFICATION,
            bounce: true,
            body: CommentMessage { comment: "You have a new domains swap offer on webdom.market!" },
        }).send(SEND_MODE_PAY_FEES_SEPARATELY); 
    }

    // Send excess to the left participant
    createMessage({
        dest: storage.leftParticipantAddress,
        value: leftInfo.paymentReceived - leftInfo.paymentTotal,
        bounce: false,
        body: CommentMessage { comment: "The offer is ready, wait for the second participant." },
    }).send(SEND_MODE_PAY_FEES_SEPARATELY);

    // Save data
    storage.state = STATE_WAITING_FOR_RIGHT;
    leftInfo.paymentReceived = leftInfo.paymentTotal;
    storage.leftInfo = leftInfo.toCell();
    storage.save();
}


// Executes when the right participant completes his part of the deal
fun completeDeal(storage: Storage, rightInfo: OneSideInfo, queryId: int) {
    setGasLimitToMaximum();

    // Transfer domains to the right participant
    var leftInfo = lazy storage.leftInfo.load();
    var (leftDomainAddress, _, _) = leftInfo.domainsDict.sDictGetFirst(267);
    repeat(leftInfo.domainsTotal) {
        createMessage({
            dest: leftDomainAddress! as address,
            value: TONS_NFT_TRANSFER,
            bounce: false,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.rightParticipantAddress,
                responseAddress: storage.leftParticipantAddress,
                forwardTonAmount: 1,
                forwardPayload: DOMAIN_SWAP_NOTIFICATION(),
            }
        }).send(SEND_MODE_REGULAR);
        (leftDomainAddress, _, _) = leftInfo.domainsDict.sDictGetNext(267, leftDomainAddress!);
    }
    // Send payment for domains swap to the left participant
    if (rightInfo.paymentTotal > TONS_MIN_EXCESS) {
        createMessage({
            dest: storage.leftParticipantAddress,
            value: rightInfo.paymentTotal,
            bounce: false,
            body: CommentMessage { comment: "webdom.market payout for domains swap" },
        }).send(SEND_MODE_REGULAR);
    }

    // Transfer domains to the left participant
    var (rightDomainAddress, _, _) = rightInfo.domainsDict.sDictGetFirst(267);
    repeat(rightInfo.domainsTotal) {
        createMessage({
            dest: rightDomainAddress! as address,
            value: TONS_NFT_TRANSFER,
            bounce: false,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.leftParticipantAddress,
                responseAddress: storage.rightParticipantAddress,
                forwardTonAmount: 1,
                forwardPayload: DOMAIN_SWAP_NOTIFICATION(),
            }
        }).send(SEND_MODE_REGULAR);
        (rightDomainAddress, _, _) = rightInfo.domainsDict.sDictGetNext(267, rightDomainAddress!);
    }
    // Send payment for domains swap + excess to the right participant
    var msgValue = leftInfo.paymentTotal + rightInfo.paymentReceived - rightInfo.paymentTotal;
    if (msgValue > TONS_MIN_EXCESS) {
        createMessage({
            dest: storage.rightParticipantAddress,
            value: msgValue,
            bounce: false,
            body: CommentMessage { comment: "webdom.market payout for domains swap" },
        }).send(SEND_MODE_REGULAR);
    }

    // Matketplace commission
    createMessage({
        dest: MARKETPLACE_ADDRESS,
        value: storage.completionCommission,
        bounce: false,
        body: CommentMessage { comment: "Marketplace commission" },
    }).send(SEND_MODE_REGULAR);
    

    // Excess
    createMessage({
        dest: storage.leftParticipantAddress,
        value: 0,
        bounce: false,
        body: ExcessesMessage { queryId: queryId },
    }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);

    // Save data
    storage.state = STATE_COMPLETED;
    storage.validUntil = blockchain.now();
    storage.save();
    return;
}


// Executes upon cancellation of the deal
fun returnDomains(storage: Storage, rightInfo: OneSideInfo, queryId: int, cancelNotification: cell) {
    setGasLimitToMaximum();

    // Return domains to the left participant
    var leftInfo = lazy storage.leftInfo.load();
    var (leftDomainAddress, leftDomainReceivedSlice, _) = leftInfo.domainsDict.sDictGetFirst(267);
    repeat(leftInfo.domainsTotal) {
        if (leftDomainReceivedSlice!.bitsEqual(BIT_TRUE_SLICE())) {
            createMessage({
                dest: leftDomainAddress! as address,
                value: TONS_NFT_TRANSFER,
                bounce: false,
                body: NftTransferMessage<cell> {
                    queryId: queryId,
                    toAddress: storage.leftParticipantAddress,
                    responseAddress: storage.leftParticipantAddress,
                    forwardTonAmount: 1,
                    forwardPayload: cancelNotification,
                }
            }).send(SEND_MODE_REGULAR);
        }
        (leftDomainAddress, leftDomainReceivedSlice, _) = leftInfo.domainsDict.sDictGetNext(267, leftDomainAddress!);
    }

    // Return domains to the right participant
    var (rightDomainAddress, rightDomainReceivedSlice, _) = rightInfo.domainsDict.sDictGetFirst(267);
    repeat(rightInfo.domainsTotal) {
        if (rightDomainReceivedSlice!.bitsEqual(BIT_TRUE_SLICE())) {
            createMessage({
                dest: rightDomainAddress! as address,
                value: TONS_NFT_TRANSFER,
                bounce: false,
                body: NftTransferMessage<cell> {
                    queryId: queryId,
                    toAddress: storage.rightParticipantAddress,
                    responseAddress: storage.rightParticipantAddress,
                    forwardTonAmount: 1,
                    forwardPayload: cancelNotification,
                }
            }).send(SEND_MODE_REGULAR); 
        }
        (rightDomainAddress, rightDomainReceivedSlice, _) = rightInfo.domainsDict.sDictGetNext(267, rightDomainAddress!);
    }

    // Return payments to the right participant
    if (rightInfo.paymentReceived > TONS_MIN_EXCESS) {
        createMessage({
            dest: storage.rightParticipantAddress,
            value: rightInfo.paymentReceived,
            bounce: false,
            body: ExcessesMessage { queryId: queryId },
        }).send(SEND_MODE_REGULAR);
    }

    // Return payments & send excesses to the left participant
    createMessage({
        dest: storage.leftParticipantAddress,
        value: 0,
        bounce: false,
        body: ExcessesMessage { queryId: queryId },
    }).send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS);

    // Save data
    storage.state = STATE_CANCELLED;
    storage.save();
    return;
}

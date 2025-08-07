import "@stdlib/gas-payments"
import "../../imports/constants"
import "../../imports/messages"
import "../constants"
import "storage"


fun acceptOffer(mutate storage: Storage, sellerAddress: address, sellerMsgValue: coins, queryId: uint64): void {
    setGasLimitToMaximum();
    
    // Send marketplace commission
    createMessage({
        bounce: false,
        value: storage.commission,
        dest: MARKETPLACE_ADDRESS,
        body: CommentMessage { comment: "Marketplace commission" }
    }).send(SEND_MODE_REGULAR);
    
    // Send payment to seller (gas for offer execution is always paid by offer creator)
    createMessage({
        bounce: false,
        value: storage.price + sellerMsgValue,
        dest: sellerAddress,
        body: CommentMessage { comment: "Offer accepted" }
    }).send(SEND_MODE_REGULAR);
    
    // Transfer NFT to buyer
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: storage.buyerAddress,
            responseAddress: storage.buyerAddress,
            customPayload: null,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
    
    // Update storage
    storage.state = STATE_COMPLETED;
    storage.validUntil = blockchain.now();
}


fun cancelOffer(mutate storage: Storage, sellerMsgValue: coins, cancellationComment: slice, queryId: uint64): void {
    if (storage.sellerPrice > 0) {
        // Notify seller that his counterproposal was rejected and return his NFT
        createMessage({
            bounce: false,
            value: TONS_NFT_TRANSFER + sellerMsgValue,
            dest: storage.domainAddress,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.sellerAddress!.load(),
                responseAddress: storage.buyerAddress,
                forwardTonAmount: 1,
                forwardPayload: COUNTERPROPOSAL_REJECTED_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    } else if (sellerMsgValue > 0) {
        // Send excess and decline reward to seller
        createMessage({
            bounce: false,
            value: sellerMsgValue + TONS_DECLINE_REWARD,
            dest: storage.sellerAddress!.load(),
            body: ExcessesMessage { queryId: queryId }
        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
    }
    
    // Update storage
    storage.state = STATE_CANCELLED;
    storage.validUntil = min(storage.validUntil, blockchain.now());
    storage.save();
    
    // Notify buyer that offer was cancelled and transfer remaining contract balance
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.buyerAddress,
        body: CommentMessage { comment: cancellationComment }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
}

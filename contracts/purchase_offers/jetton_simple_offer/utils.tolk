import "@stdlib/gas-payments"
import "../../imports/constants"
import "../../imports/messages"
import "../constants"
import "storage"


fun acceptOffer(mutate storage: Storage, domainAddress: address, buyerAddress: address, sellerMsgValue: coins, queryId: uint64): void {
    setGasLimitToMaximum();
    
    // Send marketplace commission
    if (storage.commission > 0) {
        createMessage({
            bounce: false,
            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
            dest: storage.jettonWalletAddress,
            body: SendJettonsMessage<cell> {
                queryId: queryId,
                jettonAmount: storage.commission,
                toAddress: MARKETPLACE_ADDRESS,
                responseAddress: buyerAddress,
                forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    }
    
    // Send payment to seller
    createMessage({
        bounce: false,
        value: TONS_JETTON_TRANSFER + sellerMsgValue,  // Gas for offer execution is always paid by offer creator
        dest: storage.jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.price,
            toAddress: storage.sellerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: sellerMsgValue,
            forwardPayload: OFFER_ACCEPTED_NOTIFICATION()
        }
    }).send(SEND_MODE_REGULAR);
    
    // Transfer NFT to buyer
    createMessage({
        bounce: false,
        value: 0,
        dest: domainAddress,
        body: NftTransferMessage<cell> {
            queryId: queryId,
            toAddress: buyerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: TONS_PURCHASE_NOTIFICATION,
            forwardPayload: BUYER_NOTIFICATION()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
    
    // Update storage
    storage.state = STATE_COMPLETED;
    storage.validUntil = blockchain.now();
}


fun cancelOffer(mutate storage: Storage, domainAddress: address, buyerAddress: address, sellerMsgValue: coins, cancellationComment: slice, queryId: uint64): void {
    if (storage.sellerPrice > 0) {
        // Notify seller that his counterproposal was rejected and return his NFT
        createMessage({
            bounce: false,
            value: TONS_NFT_TRANSFER + sellerMsgValue,
            dest: domainAddress,
            body: NftTransferMessage<cell> {
                queryId: queryId,
                toAddress: storage.sellerAddress,
                responseAddress: buyerAddress,
                forwardTonAmount: sellerMsgValue,
                forwardPayload: COUNTERPROPOSAL_REJECTED_NOTIFICATION()
            }
        }).send(SEND_MODE_REGULAR);
    } else if (sellerMsgValue > 0) {
        // Send excess and decline reward to seller
        createMessage({
            bounce: false,
            value: sellerMsgValue + TONS_DECLINE_REWARD,
            dest: storage.sellerAddress,
            body: ExcessesMessage { queryId: queryId }
        }).send(SEND_MODE_PAY_FEES_SEPARATELY);
    }
    
    // Update storage
    storage.state = STATE_CANCELLED;
    storage.validUntil = min(storage.validUntil, blockchain.now());
    storage.save();
    
    // Notify buyer that offer was cancelled and transfer remaining contract balance (+ jettons)
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.jettonWalletAddress,
        body: SendJettonsMessage<cell> {
            queryId: queryId,
            jettonAmount: storage.price + storage.commission,
            toAddress: buyerAddress,
            responseAddress: buyerAddress,
            forwardTonAmount: 1,
            forwardPayload: (CommentMessage { comment: cancellationComment }).toCell()
        }
    }).send(SEND_MODE_CARRY_ALL_BALANCE);
}
import "constants"
import "messages"

fun handleMakeHot<T>(mutate storage: T, promotionUntil: uint32, queryId: uint64, senderAddress: address): void {
    assert (senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
    
    if (storage.hotUntil > blockchain.now()) {
        storage.hotUntil += (promotionUntil - blockchain.now());
    } else {
        storage.hotUntil = promotionUntil;
    }
    contract.setData(storage.toCell());  // inlined Storage.save(): generic T can not resolve a concrete Storage.save under Tolk 1.4

    createMessage<ExcessesMessage>({
        bounce: false,
        value: 0,
        dest: storage.sellerAddress,
        body: ExcessesMessage { queryId: queryId }
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

fun handleMakeColored<T>(mutate storage: T, promotionUntil: uint32, queryId: uint64, senderAddress: address): void {
    assert (senderAddress == MARKETPLACE_ADDRESS) throw EXC_INCORRECT_SENDER;
    
    if (storage.coloredUntil > blockchain.now()) {
        storage.coloredUntil += (promotionUntil - blockchain.now());
    } else {
        storage.coloredUntil = promotionUntil;
    }
    contract.setData(storage.toCell());  // inlined Storage.save(): generic T can not resolve a concrete Storage.save under Tolk 1.4
    
    createMessage<ExcessesMessage>({
        bounce: false,
        value: 0,
        dest: storage.sellerAddress,
        body: ExcessesMessage { queryId: queryId }
    }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}
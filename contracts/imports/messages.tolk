import "constants";
import "types";


struct (0x00000000) CommentMessage {
    comment: SerializableSlice;
}

struct (0x5fcc3d14) NftTransferMessage<T> {
    queryId: uint64;
    toAddress: address;
    responseAddress: address;
    customPayload: cell? = null;
    forwardTonAmount: coins;
    forwardPayload: T?;
}

struct (0x5fcc3d14) NftTransferMessageBuilder<T> {
    queryId: uint64;
    toAddress: builder;
    responseAddress: address;
    customPayload: cell? = null;
    forwardTonAmount: coins;
    forwardPayload: T?;
}

struct (0x0f8a7ea5) SendJettonsMessage<T> {
    queryId: uint64;
    jettonAmount: coins;
    toAddress: address;
    responseAddress: address;
    customPayload: cell? = null;
    forwardTonAmount: coins;
    forwardPayload: T?;
}

struct (0x0f8a7ea5) SendJettonsMessageBuilder<T> {
    queryId: uint64;
    jettonAmount: coins;
    toAddress: builder;
    responseAddress: address;
    customPayload: cell? = null;
    forwardTonAmount: coins;
    forwardPayload: T?;
}

struct (0x595f07bc) BurnJettonsMessage {
    queryId: uint64;
    jettonAmount: coins;
    responseAddress: address;
}

struct (0x05138d91) NftOwnershipAssignedMessage<T> {
    queryId: uint64;
    fromAddress: address;
    forwardPayload: T | Cell<T>;
}

struct (0x7362d09c) JettonsTransferNotificationMessage<T> {
    queryId: uint64;
    transferredJettons: coins;
    fromAddress: address;
    forwardPayload: T | Cell<T>;
}

struct (0x2c76b973) RequestWalletAddressMessage<T> {
    queryId: uint64;
    contractAddress: address;
    includeOwnerAddress: bool
}

struct (0xd1735400) ResponseWalletAddress {
    queryId: uint64
    jettonWalletAddress: address
    ownerAddress: Cell<address>?
}

struct (0x37726bdb) WithdrawAllTonMessage {
    queryId: uint64;
}

struct (0x37726bdb) WithdrawSomeTonMessage {
    queryId: uint64;
    withdrawAmount: coins;
}

struct (0x11c09682) WithdrawJettonMessage {
    queryId: uint64;
    jettonWalletAddress: address;
    withdrawAmount: coins;
}

struct (0x8ea53895) CancelDealMessage {
    queryId: uint64;
    cancellationComment: SerializableSlice;
}

struct (0xd53276db) ExcessesMessage {
    queryId: uint64;
}

struct (0x0609e47b) FillUpBalanceMessage {
    queryId: uint64;
}

struct (0x8ea53895) ExternalCancelDealMessage {
    queryId: uint64;
    signature: bits512;
    offerAddress: address;
    msgToSend: cell;
}

struct (0x474f86cf) DedustTonPayoutMessage {
    queryId: uint64;
    senderAddress: Cell<address>;
} 

struct (0x504b6dd7) MakeHotMessage {
    queryId: uint64;
    promotionUntil: uint32;
}

struct (0x96dc2804) MakeColoredMessage {
    queryId: uint64;
    promotionUntil: uint32;
}

struct (0x975f5690) RenewalFeeMessage {
    queryId: uint64;
}

type DedustJettonPayoutMessage = JettonsTransferNotificationMessage<address> | DedustTonPayoutMessage;
import "constants"
import "messages"
import "@stdlib/tvm-lowlevel"

// todo проверить что работает
fun loadData(): void
    asm "1 CALLDICT"


struct (0xe2d2d211) SetCodeAdminMessage {
    code: cell?;
    data: cell?;
}

struct (0xa47d989c) SendAnyAdminMessage {
    dest: address;
    payload: cell;
    stateInit: cell?;
    messageMode: uint8?;
}

struct (0x37726bdb) WithdrawTonAdminMessage {
    tonsToReserve: coins;
}

struct (0x11c09682) WithdrawJettonAdminMessage {
    jettonWalletAddress: address;
    jettonAmount: coins;
}

struct (0x00dc315b) WithdrawNftAdminMessage {
    domainAddress: address;
}

type AdminMessage = SetCodeAdminMessage | SendAnyAdminMessage | WithdrawTonAdminMessage | WithdrawJettonAdminMessage | WithdrawNftAdminMessage;

struct Permissions {
    allowChangeCode: bool = false;
    allowChangeData: bool = false;
    allowSendAnyMessage: bool = false;
    allowWithdrawTon: bool = false;
    allowWithdrawJetton: bool = false;
    allowSendNft: bool = false;
}

@inline
fun handleAdminMessage(senderAddress: address, inMsgBody: slice, permissions: Permissions): void {
    if (senderAddress != ADMIN_ADDRESS) {
        return;
    }
    
    var msgBodyTyped = lazy AdminMessage.fromSlice(inMsgBody);
    match (msgBodyTyped) {
        SetCodeAdminMessage => {
            if (msgBodyTyped.code != null) {
                assert(permissions.allowChangeCode) throw EXC_UNSUPPORTED_OP;
                contract.setCodePostponed(msgBodyTyped.code);
            }
            if (msgBodyTyped.data != null) {
                assert(permissions.allowChangeData) throw EXC_UNSUPPORTED_OP;
                contract.setData(msgBodyTyped.data);
            }
            
            createMessage<CommentMessage>({
                bounce: false,
                value: 0,
                dest: ADMIN_ADDRESS,
                body: CommentMessage { comment: "Code updated" }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }
        
        SendAnyAdminMessage => {
            assert(permissions.allowSendAnyMessage) throw EXC_UNSUPPORTED_OP;
            createMessage<cell>({
                bounce: false,
                value: 0,
                dest: msgBodyTyped.stateInit != null ? AutoDeployAddress { stateInit: msgBodyTyped.stateInit } : msgBodyTyped.dest,
                body: msgBodyTyped.payload
            }).send(msgBodyTyped.messageMode != null ? msgBodyTyped.messageMode : SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }

        WithdrawTonAdminMessage => {
            assert(permissions.allowWithdrawTon) throw EXC_UNSUPPORTED_OP;
            reserveToncoinsOnBalance(msgBodyTyped.tonsToReserve, RESERVE_MODE_EXACT_AMOUNT);
            createMessage<CommentMessage>({
                bounce: false,
                value: 0,
                dest: ADMIN_ADDRESS,
                body: CommentMessage { comment: "TON withrawal" }
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
            throw 0;
        }

        WithdrawJettonAdminMessage => {
            assert(permissions.allowWithdrawJetton) throw EXC_UNSUPPORTED_OP;
            createMessage<SendJettonsMessage<CommentMessage>>({
                bounce: false,
                value: 0,
                dest: msgBodyTyped.jettonWalletAddress,
                body: SendJettonsMessage {
                    queryId: 0,
                    jettonAmount: msgBodyTyped.jettonAmount,
                    toAddress: ADMIN_ADDRESS,
                    responseAddress: ADMIN_ADDRESS,
                    forwardTonAmount: 1,
                    forwardPayload: CommentMessage { comment: "Jetton withrawal" }
                }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }

        WithdrawNftAdminMessage => {
            assert(permissions.allowSendNft) throw EXC_UNSUPPORTED_OP;
            createMessage<NftTransferMessage<CommentMessage>>({
                bounce: false,
                value: 0,
                dest: msgBodyTyped.domainAddress,
                body: NftTransferMessage {
                    queryId: 0,
                    toAddress: ADMIN_ADDRESS,
                    responseAddress: ADMIN_ADDRESS,
                    forwardTonAmount: 1,
                    forwardPayload: CommentMessage { comment: "Domain withrawal" }
                }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }
        else => {
            return;
        }
    }
}

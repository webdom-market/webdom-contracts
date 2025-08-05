import "constants"
import "messages"
import "@stdlib/tvm-lowlevel"

// todo проверить что работает
fun loadData(): void
    asm "1 CALLDICT"


struct (0xe2d2d211) SetCodeAdminMessage {
    queryId: uint64;
    code: cell?;
    data: cell?;
}

struct (0xa47d989c) SendAnyAdminMessage {
    queryId: uint64;
    dest: address;
    payload: cell;
    stateInit: cell?;
    messageMode: uint8?;
}

struct (0x37726bdb) WithdrawTonAdminMessage {
    queryId: uint64;
    tonsToReserve: coins;
}

struct (0x11c09682) WithdrawJettonAdminMessage {
    queryId: uint64;
    jettonWalletAddress: address;
    jettonAmount: coins;
}

struct (0x00dc315b) WithdrawNftAdminMessage {
    queryId: uint64;
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
            commitContractDataAndActions();
            
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
            val messageMode = msgBodyTyped.messageMode != null ? msgBodyTyped.messageMode : SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE as uint8;
            if (msgBodyTyped.stateInit != null) {
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: AutoDeployAddress { stateInit: msgBodyTyped.stateInit },
                    body: msgBodyTyped.payload
                }).send(messageMode);
            } else {
                createMessage<cell>({
                    bounce: false,
                    value: 0,
                    dest: msgBodyTyped.dest,
                    body: msgBodyTyped.payload
                }).send(messageMode);
            }
            
            throw 0;
        }

        WithdrawTonAdminMessage => {
            assert(permissions.allowWithdrawTon || permissions.allowSendAnyMessage) throw EXC_UNSUPPORTED_OP;
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
            assert(permissions.allowWithdrawJetton || permissions.allowSendAnyMessage) throw EXC_UNSUPPORTED_OP;
            createMessage<SendJettonsMessage<cell>>({
                bounce: false,
                value: 0,
                dest: msgBodyTyped.jettonWalletAddress,
                body: SendJettonsMessage {
                    queryId: 0,
                    jettonAmount: msgBodyTyped.jettonAmount,
                    toAddress: ADMIN_ADDRESS,
                    responseAddress: ADMIN_ADDRESS,
                    forwardTonAmount: 1,
                    forwardPayload: (CommentMessage { comment: "Jetton withrawal" }).toCell()
                }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }

        WithdrawNftAdminMessage => {
            assert(permissions.allowSendNft || permissions.allowSendAnyMessage) throw EXC_UNSUPPORTED_OP;
            createMessage<NftTransferMessage<cell>>({
                bounce: false,
                value: 0,
                dest: msgBodyTyped.domainAddress,
                body: NftTransferMessage {
                    queryId: 0,
                    toAddress: ADMIN_ADDRESS,
                    responseAddress: ADMIN_ADDRESS,
                    forwardTonAmount: 1,
                    forwardPayload: (CommentMessage { comment: "Domain withrawal" }).toCell()
                }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            throw 0;
        }
        else => {
            return;
        }
    }
}

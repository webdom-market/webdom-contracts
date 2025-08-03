import "constants";
import "storage";
import "../imports/constants";
import "../imports/messages";
import "@stdlib/gas-payments";
import "@stdlib/tvm-dicts";
import "utils";
import "messages";
import "../imports/types"
import "../imports/utils"
import "../imports/admin_message"


fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);

    var storage = lazy Storage.load();

    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state > STATE_WAITING_FOR_RIGHT,
        allowChangeData: storage.state > STATE_WAITING_FOR_RIGHT,
        allowSendAnyMessage: storage.state > STATE_WAITING_FOR_RIGHT,
        allowWithdrawJetton: true
    });

    val msg = lazy AllowedMessage.fromSlice(in.body);
    match (msg) {
        // deploy
        FillUpBalanceMessage => {
            if (in.senderAddress == MARKETPLACE_ADDRESS && storage.state == STATE_CANCELLED) {
                storage.state = STATE_WAITING_FOR_LEFT;
                storage.save();
                return;
            }
            return;
        },

        // receive domain
        NftOwnershipAssignedMessage<SerializableSlice> => {
            try {
                assert(storage.state < STATE_COMPLETED && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;
                storage.lastActionTime = blockchain.now();

                var msgValue = in.valueCoins - TONS_ADD_DOMAIN;
                assert(msgValue >= 0) throw EXC_OUT_OF_GAS;

                // Receive domain from the left participant
                if (msg.fromAddress == storage.leftParticipantAddress) {
                    assert(storage.state == STATE_WAITING_FOR_LEFT) throw EXC_DEAL_NOT_ACTIVE;

                    var leftInfo: OneSideInfo = lazy storage.leftInfo.load();
                    var (_, found) = leftInfo.domainsDict.sDictGet(267, in.senderAddress as slice);
                    assert(found) throw EXC_INCORRECT_DOMAIN;

                    leftInfo.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                    leftInfo.domainsReceived += 1;
                    leftInfo.paymentReceived += msgValue;

                    if (leftInfo.domainsReceived == leftInfo.domainsTotal && leftInfo.paymentReceived >= leftInfo.paymentTotal) {
                        completeLeftPart(storage, leftInfo);
                        return;
                    }
                    storage.leftInfo = leftInfo.toCell();
                    storage.save();
                    return;
                }

                // Receive domain from the right participant
                else if (msg.fromAddress == storage.rightParticipantAddress) {
                    assert(storage.state == STATE_WAITING_FOR_RIGHT) throw EXC_DEAL_NOT_ACTIVE;

                    var rightInfo: OneSideInfo = lazy storage.rightInfo.load();
                    var (_, found) = rightInfo.domainsDict.sDictGet(267, in.senderAddress as slice);
                    assert(found) throw EXC_INCORRECT_DOMAIN;

                    rightInfo.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                    rightInfo.domainsReceived += 1;
                    rightInfo.paymentReceived += msgValue;

                    if (rightInfo.paymentReceived >= rightInfo.paymentTotal && rightInfo.domainsReceived == rightInfo.domainsTotal) {
                        completeDeal(storage, rightInfo, msg.queryId);
                        return;
                    }
                    storage.rightInfo = rightInfo.toCell();
                    storage.save();
                    return;
                }
                
                throw EXC_INCORRECT_SENDER;
            }
            catch (e, _) {
                returnNftToSender(in.senderAddress, msg, e);
            }
        },

        // change valid until
        ChangeValidUntilMessage => {
            assert (in.senderAddress == storage.leftParticipantAddress) throw EXC_INCORRECT_SENDER;
            assert (msg.newValidUntil > max(blockchain.now() + 300, storage.validUntil) && 
                    msg.newValidUntil < storage.createdAt + ONE_YEAR - ONE_DAY) throw EXC_INCORRECT_VALID_UNTIL;
            
            storage.validUntil = msg.newValidUntil;
            createMessage({
                dest: in.senderAddress,
                value: 0,
                bounce: false,
                body: ExcessesMessage {queryId: msg.queryId},
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            storage.save();
            return;
        },

        // receive payment or cancel deal
        else => {
            var (op, queryId) = loadOpAndQueryId(mutate in.body);

            // receive payment
            if (op == 0) {
                var msgValue = in.valueCoins - ton("0.01");
                if (in.senderAddress == storage.leftParticipantAddress) {
                    var leftInfo = lazy storage.leftInfo.load();

                    assert(storage.state == STATE_WAITING_FOR_LEFT) throw EXC_DEAL_NOT_ACTIVE;
                    assert(leftInfo.paymentReceived < leftInfo.paymentTotal) throw EXC_NO_NEED_TO_PAY;
                    leftInfo.paymentReceived += msgValue;
                    assert(leftInfo.paymentReceived >= leftInfo.paymentTotal) throw EXC_OUT_OF_GAS;

                    if (leftInfo.domainsReceived == leftInfo.domainsTotal) {
                        completeLeftPart(storage, leftInfo);
                        return;
                    }
                    storage.leftInfo = leftInfo.toCell();
                    storage.save();
                    return;
                }
                else if (in.senderAddress == storage.rightParticipantAddress) {
                    var rightInfo = lazy storage.rightInfo.load();

                    assert(storage.state == STATE_WAITING_FOR_RIGHT) throw EXC_DEAL_NOT_ACTIVE;
                    assert(rightInfo.paymentReceived < rightInfo.paymentTotal) throw EXC_NO_NEED_TO_PAY;
                    rightInfo.paymentReceived += msgValue;
                    assert(rightInfo.paymentReceived >= rightInfo.paymentTotal) throw EXC_OUT_OF_GAS;

                    if (rightInfo.domainsReceived == rightInfo.domainsTotal) {
                        completeDeal(storage, rightInfo, queryId);
                        return;
                    }
                    storage.rightInfo = rightInfo.toCell();
                    storage.save();
                    return;
                }
                throw EXC_INCORRECT_SENDER;
            }

            // cancel deal
            else if (op == OP_CANCEL_DEAL) {
                var cancelNotification: cell;
                var rightInfo = lazy storage.rightInfo.load();
                if (in.senderAddress == storage.leftParticipantAddress) {
                    // The deal can be cancelled by the left participant if the right participant has not joined yet or if his last action was more than 1 hour ago
                    assert(
                        storage.state == STATE_WAITING_FOR_LEFT || 
                        storage.lastActionTime + ONE_HOUR < blockchain.now() ||
                        storage.validUntil < blockchain.now()
                    ) throw EXC_CANT_CANCEL_DEAL;

                    cancelNotification = CANCEL_NOTIFICATION_LEFT();
                    storage.cancelledByLeft = true;
                }
                else {
                    // The deal can be cancelled by the right participant at any time
                    assert(in.senderAddress == storage.rightParticipantAddress) throw EXC_INCORRECT_SENDER;
                    cancelNotification = CANCEL_NOTIFICATION_RIGHT();
                    rightInfo.paymentReceived += in.valueCoins - ton("0.01");
                }
                returnDomains(storage, rightInfo, queryId, cancelNotification);
                return;
            }
        },
    }
}


fun onExternalMessage(inMsg: slice) {
    var storage = lazy Storage.load();

    assert(storage.state < STATE_COMPLETED) throw EXC_DEAL_NOT_ACTIVE;
    if (blockchain.now() >= storage.validUntil) {
        assert(inMsg.loadUint(32) == OP_CANCEL_DEAL) throw EXC_UNSUPPORTED_OP;
        var rightInfo = lazy storage.rightInfo.load();
        returnDomains(storage, rightInfo, inMsg.loadUint(64), CANCEL_NOTIFICATION_EXPIRED());
        return;
    }
}

get fun get_storage_data() {
    var storage = Storage.load();
    var leftInfo = storage.leftInfo.load();
    var rightInfo = storage.rightInfo.load();
    return (
        storage.leftParticipantAddress,
        leftInfo.domainsDict,
        leftInfo.domainsTotal,
        leftInfo.domainsReceived,
        leftInfo.paymentTotal,
        leftInfo.paymentReceived,

        storage.rightParticipantAddress,
        rightInfo.domainsDict,
        rightInfo.domainsTotal,
        rightInfo.domainsReceived,
        rightInfo.paymentTotal,
        rightInfo.paymentReceived,

        storage.state,
        storage.createdAt,
        storage.validUntil,
        storage.lastActionTime,
        storage.completionCommission,
        storage.needsAlert,
        storage.cancelledByLeft,

        BURN_ADDRESS, 
        contract.getCode().hash()
    );
}
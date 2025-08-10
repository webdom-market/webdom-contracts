import "constants"
import "storage"
import "../imports/constants"
import "../imports/messages"
import "@stdlib/tvm-dicts"
import "utils"
import "messages"
import "../imports/types"
import "../imports/utils"
import "../imports/admin_message"


fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);

    var storage: Storage = lazy Storage.load();

    // Handle admin messages for contract management
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: storage.state > STATE_WAITING_FOR_RIGHT,
        allowChangeData: storage.state > STATE_WAITING_FOR_RIGHT,
        allowSendAnyMessage: storage.state > STATE_WAITING_FOR_RIGHT,
        allowWithdrawJetton: true
    });

    val msg = lazy AllowedMessage.fromSlice(in.body);
    match (msg) {
        // Activate the contract (it is initially in the CANCELLED state)
        FillUpBalanceMessage => {
            if (in.senderAddress == MARKETPLACE_ADDRESS && storage.state == STATE_CANCELLED) {
                storage.state = STATE_WAITING_FOR_LEFT;
                storage.save();
                return;
            }
            return;
        },

        // Receive domain from a participant (left or right)
        NftOwnershipAssignedMessage<SerializableSlice> => {
            try {
                // Swap must be active and not expired
                assert(storage.state < STATE_COMPLETED && storage.validUntil > blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;
                storage.lastActionTime = blockchain.now();

                // Net TON attached to message minus gas to process domain transfer
                var msgValue: coins = in.valueCoins - TONS_ADD_DOMAIN;
                assert(msgValue >= 0) throw EXC_OUT_OF_GAS;

                // Receive domain from the left participant
                if (msg.fromAddress == storage.leftParticipantAddress) {
                    // Only allowed while waiting for the left side
                    assert(storage.state == STATE_WAITING_FOR_LEFT) throw EXC_DEAL_NOT_ACTIVE;

                    var leftInfo: OneSideInfo = lazy storage.leftInfo.load();
                    // Verify that this domain is expected from the left side
                    var (_, found) = leftInfo.domainsDict.sDictGet(267, in.senderAddress as slice);
                    assert(found) throw EXC_INCORRECT_DOMAIN;

                    // Mark domain as received and accumulate incoming payment for the left side
                    leftInfo.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                    leftInfo.domainsReceived += 1;
                    leftInfo.paymentReceived += msgValue;

                    // If left delivered everything and fully paid, complete the left part (switch state to WAITING_FOR_RIGHT)
                    if (leftInfo.domainsReceived == leftInfo.domainsTotal && leftInfo.paymentReceived >= leftInfo.paymentTotal) {
                        completeLeftPart(storage, leftInfo);
                        return;
                    }

                    // Save leftInfo
                    storage.leftInfo = leftInfo.toCell();
                    storage.save();
                    return;
                }

                // Receive domain from the right participant
                else if (msg.fromAddress == storage.rightParticipantAddress) {
                    // Only allowed while waiting for the right side
                    assert(storage.state == STATE_WAITING_FOR_RIGHT) throw EXC_DEAL_NOT_ACTIVE;

                    var rightInfo: OneSideInfo = lazy storage.rightInfo.load();
                    // Verify that this domain is expected from the right side
                    var (_, found) = rightInfo.domainsDict.sDictGet(267, in.senderAddress as slice);
                    assert(found) throw EXC_INCORRECT_DOMAIN;

                    // Mark domain as received and accumulate incoming payment for the right side
                    rightInfo.domainsDict.sDictSet(267, in.senderAddress as slice, BIT_TRUE_SLICE());
                    rightInfo.domainsReceived += 1;
                    rightInfo.paymentReceived += msgValue;

                    // When right side has fully paid and sent all domains, finish the deal atomically
                    if (rightInfo.paymentReceived >= rightInfo.paymentTotal && rightInfo.domainsReceived == rightInfo.domainsTotal) {
                        completeDeal(storage, rightInfo, msg.queryId);
                        return;
                    }

                    // Save rightInfo
                    storage.rightInfo = rightInfo.toCell();
                    storage.save();
                    return;
                }
                
                // Any other sender is invalid for this message
                throw EXC_INCORRECT_SENDER;
            }
            catch (e, _) {
                // Return NFT to its original owner on error
                returnNftToSender(in.senderAddress, msg, e);
            }
        },

        // Extend validity period (left participant only)
        ChangeValidUntilMessage => {
            assert (in.senderAddress == storage.leftParticipantAddress) throw EXC_INCORRECT_SENDER;  // Check that the message is sent by the left participant
            assert (msg.newValidUntil > max(blockchain.now() + 300, storage.validUntil) && 
                    msg.newValidUntil < storage.createdAt + ONE_YEAR - ONE_DAY) throw EXC_INCORRECT_VALID_UNTIL;  // Check that the new validUntil is at least 5 minutes from now and less than 1 year from creation
            
            // Save new valid until
            storage.validUntil = msg.newValidUntil;
            storage.save();

            // Send excess
            createMessage({
                dest: in.senderAddress,
                value: 0,
                bounce: false,
                body: ExcessesMessage {queryId: msg.queryId},
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            return;
        },

        // Receive payment or cancel the deal
        else => {
            var (op: uint32, queryId: uint64) = loadOpAndQueryId(mutate in.body);

            // receive payment
            if (op == 0) {
                // Net TON attached to payment minus TON to process payment
                var msgValue: coins = in.valueCoins - ton("0.01");
                if (in.senderAddress == storage.leftParticipantAddress) {
                    var leftInfo: OneSideInfo = lazy storage.leftInfo.load();

                    // Only allowed while waiting for the left side; Overpayments are handled in the completeLeftPart function
                    assert(storage.state == STATE_WAITING_FOR_LEFT) throw EXC_DEAL_NOT_ACTIVE;
                    assert(leftInfo.paymentReceived < leftInfo.paymentTotal) throw EXC_NO_NEED_TO_PAY;
                    leftInfo.paymentReceived += msgValue;
                    assert(leftInfo.paymentReceived >= leftInfo.paymentTotal) throw EXC_OUT_OF_GAS;

                    // If left already delivered all domains, we can complete its part now
                    if (leftInfo.domainsReceived == leftInfo.domainsTotal) {
                        completeLeftPart(storage, leftInfo);
                        return;
                    }
                    // Persist partial payment
                    storage.leftInfo = leftInfo.toCell();
                    storage.save();
                    return;
                }
                else if (in.senderAddress == storage.rightParticipantAddress) {
                    var rightInfo: OneSideInfo = lazy storage.rightInfo.load();

                    // Only allowed while waiting for the right side; Overpayments are handled in the completeDeal function
                    assert(storage.state == STATE_WAITING_FOR_RIGHT) throw EXC_DEAL_NOT_ACTIVE;
                    assert(rightInfo.paymentReceived < rightInfo.paymentTotal) throw EXC_NO_NEED_TO_PAY;
                    rightInfo.paymentReceived += msgValue;
                    assert(rightInfo.paymentReceived >= rightInfo.paymentTotal) throw EXC_OUT_OF_GAS;

                    // If right already delivered all domains, we can complete the deal now
                    if (rightInfo.domainsReceived == rightInfo.domainsTotal) {
                        completeDeal(storage, rightInfo, queryId);
                        return;
                    }
                    // Persist partial payment
                    storage.rightInfo = rightInfo.toCell();
                    storage.save();
                    return;
                }
                // Any other sender is invalid for this operation
                throw EXC_INCORRECT_SENDER;
            }

            // cancel deal
            else if (op == OP_CANCEL_DEAL) {
                var cancelNotification: cell;
                var rightInfo: OneSideInfo = lazy storage.rightInfo.load();
                if (in.senderAddress == storage.leftParticipantAddress) {
                    // Left may cancel if right has not joined yet, or was inactive for > 1 hour, or deal expired
                    assert(
                        storage.state == STATE_WAITING_FOR_LEFT || 
                        storage.lastActionTime + ONE_HOUR < blockchain.now() ||
                        storage.validUntil < blockchain.now()
                    ) throw EXC_CANT_CANCEL_DEAL;

                    cancelNotification = CANCEL_NOTIFICATION_LEFT();
                    storage.cancelledByLeft = true;
                }
                else {
                    // Right may cancel at any time (compensated for gas with a small bonus)
                    assert(in.senderAddress == storage.rightParticipantAddress) throw EXC_INCORRECT_SENDER;
                    cancelNotification = CANCEL_NOTIFICATION_RIGHT();
                    rightInfo.paymentReceived += in.valueCoins + ton("0.01");  //  reward for canceling the deal
                }
                // Return all domains back to their owners and notify about cancellation
                returnDomains(storage, rightInfo, queryId, cancelNotification);
                return;
            }
            
            throw EXC_UNSUPPORTED_OP;
        },
    }
}


// External messages: allow cancellation on expiration
fun onExternalMessage(inMsg: slice) {
    var storage: Storage = lazy Storage.load();

    assert(storage.state < STATE_COMPLETED) throw EXC_DEAL_NOT_ACTIVE;
    if (blockchain.now() >= storage.validUntil) {
        assert(inMsg.loadUint(32) == OP_CANCEL_DEAL) throw EXC_UNSUPPORTED_OP;
        var rightInfo: OneSideInfo = lazy storage.rightInfo.load();
        // Expired: return all domains and notify both sides
        returnDomains(storage, rightInfo, inMsg.loadUint(64), CANCEL_NOTIFICATION_EXPIRED());
        return;
    }
}

// Get contract storage data for external queries
get fun get_storage_data() {
    var storage: Storage = Storage.load();
    var leftInfo: OneSideInfo = storage.leftInfo.load();
    var rightInfo: OneSideInfo = storage.rightInfo.load();
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
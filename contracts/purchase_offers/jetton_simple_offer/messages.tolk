import "../../imports/messages"
import "../../imports/types"
import "../messages"


struct (0x96189f94) ChangePricePayload {
    newValidUntil: uint32;
    notifySeller: bool;
}


type AllowedMessage = (
    DeployAndSetWalletMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | JettonsTransferNotificationMessage<SerializableSlice>
    | CounterProposeMessage
    | ChangeValidUntilMessage
    | CancelDealMessage
    | CommentMessage
);
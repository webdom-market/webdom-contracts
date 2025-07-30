import "../../imports/messages"
import "../messages"
import "../../imports/types"


struct (0x0609e47b) DeployAndSetWalletMessage {
    queryId: uint64;
    jettonWalletAddress: address;
}

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
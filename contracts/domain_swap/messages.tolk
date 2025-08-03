import "../imports/messages";
import "../imports/types"


struct (0xfd265ff8) ChangeValidUntilMessage {
    queryId: uint64;
    newValidUntil: uint32;
}

type AllowedMessage = (
    FillUpBalanceMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | ChangeValidUntilMessage
);
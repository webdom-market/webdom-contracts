import "../../imports/messages"
import "../../imports/types"
import "../messages";

type AllowedMessage = (
    NftOwnershipAssignedMessage<SerializableSlice> 
    | CounterProposeMessage
    | ChangePriceMessage
    | ChangeValidUntilMessage
    | CancelDealMessage
    | CommentMessage
    | FillUpBalanceMessage
);

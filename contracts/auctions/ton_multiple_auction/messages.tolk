import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    FillUpBalanceMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);
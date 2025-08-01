import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    FillUpBalanceMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | DnsBalanceReleaseMessage
    | ChangePriceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
); 
import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    FillUpBalanceMessage
    | NftOwnershipAssignedMessage<cell>
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);
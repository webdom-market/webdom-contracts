import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    FillUpBalanceMessage
    | NftOwnershipAssignedMessage<cell>
    | DnsBalanceReleaseMessage
    | ChangePriceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
); 
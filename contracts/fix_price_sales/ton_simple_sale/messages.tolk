import "../../imports/messages";
import "../../imports/types";
import "../messages";


type AllowedMessage = (
    ChangePriceMessage
    | FillUpBalanceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | DnsBalanceReleaseMessage
    | ExcessesMessage
);

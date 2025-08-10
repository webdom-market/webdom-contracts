import "../../imports/messages"
import "../messages"

type AllowedMessage = (
    FillUpBalanceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
); 
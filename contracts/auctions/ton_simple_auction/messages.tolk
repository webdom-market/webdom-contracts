import "../../imports/messages"
import "../../imports/types"
import "../messages"

/* Сообщения, обрабатываемые в onInternalMessage */
type AllowedMessage = (
    FillUpBalanceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
); 
import "../../imports/messages"
import "../../imports/types"
import "../messages"

type AllowedMessage = (
    DeployAndSetWalletMessage
    | JettonsTransferNotificationMessage<SerializableSlice>
    | ChangePriceMessage
    | RenewDomainMessage
    | DnsBalanceReleaseMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);

import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    DeployAndSetWalletMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | DnsBalanceReleaseMessage
    | JettonsTransferNotificationMessage<SerializableSlice>
    | ChangePriceMessage
    | RenewDomainMessage
    | SetAutoRenewParamsMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);

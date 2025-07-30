import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    DeployAndSetWalletMessage
    | NftOwnershipAssignedMessage<cell>
    | DnsBalanceReleaseMessage
    | JettonsTransferNotificationMessage<SerializableSlice>
    | ChangePriceMessage
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);
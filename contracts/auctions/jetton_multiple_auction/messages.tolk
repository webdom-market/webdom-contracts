import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    DeployAndSetWalletMessage
    | NftOwnershipAssignedMessage<cell>
    | JettonsTransferNotificationMessage<SerializableSlice>
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);
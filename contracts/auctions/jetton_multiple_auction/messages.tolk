import "../../imports/messages";
import "../../imports/types";
import "../messages";

type AllowedMessage = (
    DeployAndSetWalletMessage
    | NftOwnershipAssignedMessage<SerializableSlice>
    | JettonsTransferNotificationMessage<SerializableSlice>
    | RenewDomainMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);
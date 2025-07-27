import "../../imports/messages"
import "../../imports/types"
import "../messages"

struct (0x0609e47b) DeployMessage {
    queryId: uint64;
    jettonWalletAddress: address;
}

type AllowedMessage = (
    DeployMessage
    | JettonsTransferNotificationMessage<SerializableSlice>
    | ChangePriceMessage
    | RenewDomainMessage
    | DnsBalanceReleaseMessage
    | MakeHotMessage
    | MakeColoredMessage
    | ExcessesMessage
);

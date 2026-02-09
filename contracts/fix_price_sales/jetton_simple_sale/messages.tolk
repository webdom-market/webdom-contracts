import "../../imports/messages"
import "../../imports/types"
import "../messages"

type AllowedMessage = (
    DeployAndSetWalletMessage                                // Deploy and set jetton wallet
    | JettonsTransferNotificationMessage<SerializableSlice>  // Handle jetton purchases
    | ChangePriceMessage                                     // Change sale price and validity
    | RenewDomainMessage                                     // Renew domain and extend sale
    | SetAutoRenewParamsMessage                              // Update auto-renew settings and paid iterations
    | DnsBalanceReleaseMessage                               // Handle domain expiration
    | MakeHotMessage                                         // Add hot promotion
    | MakeColoredMessage                                     // Add colored promotion
    | ExcessesMessage                                        // Accept excess coins
);

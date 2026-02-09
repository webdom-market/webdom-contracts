import "../../imports/messages"
import "../messages"


type AllowedMessage = (
    ChangePriceMessage          // Change sale price and validity
    | FillUpBalanceMessage      // Activate sale when deployed
    | RenewDomainMessage        // Renew domain and extend sale
    | SetAutoRenewParamsMessage // Update auto-renew settings and paid iterations
    | MakeHotMessage            // Add hot promotion
    | MakeColoredMessage        // Add colored promotion
    | DnsBalanceReleaseMessage  // Handle domain expiration
    | ExcessesMessage           // Accept excess coins
);

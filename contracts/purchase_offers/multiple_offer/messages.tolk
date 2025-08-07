import "../../imports/types"
import "../../imports/constants"
import "../../imports/messages"


// Jetton payment information
struct JettonInfo {
    jettonWalletAddress: address;     // Address of the jetton wallet
    oneJetton: coins;                 // Decimal factor for comment display
    symbol: SerializableSlice;        // Jetton symbol (e.g., "USDT", "WEB3")
}

// Price information for NFT in multiple offer
struct PriceInfo {
    price: coins;                     // NFT price
    validUntil: uint32;               // Offer validity timestamp
    maybeJettonInfo: JettonInfo?;     // Jetton info (null for TON sales)
}

// Payload for TON reservation during jetton deposits
struct ReserveTonsPayload {
    coinsToReserve: coins?;           // Amount of TON to reserve
}

// Information for updating multiple offer data
struct UpdateInfo {
    signTime: uint32;                 // Signature timestamp
    contractAddress: address;         // Contract address for verification
    newMerkleRoot: uint256;           // New Merkle root to set
}

// Message to update multiple offer data with signature
struct (0xb1f57834) SetNewDataMessage {
    queryId: uint64;
    updateInfo: Cell<UpdateInfo>;     // Update information
    signature: bits512;               // Owner's signature
}

// Message to deploy and configure multiple offer
struct (0x0609e47b) MultipleOfferDeployMessage {
    queryId: uint64;
    merkleRoot: uint256;              // Initial Merkle root
    commissionFactor: uint16;         // Standard commission factor
    web3CommissionFactor: uint16;     // WEB3 token commission factor
    web3WalletAddress: address;       // WEB3 jetton wallet address
}

// Merkle proof cell structure for price verification
struct (0x03) MerkleProofCell {
    merkleRoot: uint256;    // Root of the Merkle tree
    priceInfoDict: dict;    // Dictionary containing price information
}

// Message to sell NFT through multiple offer (with Merkle proof)
// Note: We don't use NftOwnershipAssignedMessage<MerkleProofCell> because proof is always in reference
struct (0x05138d91) SellNftMessage {
    queryId: uint64;
    fromAddress: address;                  // Seller address
    forwardPayload: Cell<MerkleProofCell>; // Merkle proof for sale conditions verification
}

// Jetton transfer notification for topping up offer balance
type TopUpJettonBalanceMessage = JettonsTransferNotificationMessage<ReserveTonsPayload>;

// All message types that the multiple offer contract can handle
type AllowedMessage = (
    MultipleOfferDeployMessage      // Deploy and configure offer
    | SellNftMessage                // Sell NFT with Merkle proof
    | TopUpJettonBalanceMessage     // Top up jetton balance
    | SetNewDataMessage             // Update offer data
    | WithdrawSomeTonMessage        // Withdraw TON
    | WithdrawJettonMessage         // Withdraw jettons
    | ExcessesMessage               // Accept excess coins
);
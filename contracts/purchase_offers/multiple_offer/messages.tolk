import "../../imports/types";
import "../../imports/constants";
import "../../imports/messages";

struct (0x03) MerkleProofCell {
    merkleRoot: uint256;
    priceInfoDict: dict;
}

struct JettonInfo {
    jettonWalletAddress: address;
    oneJetton: coins;
    symbol: SerializableSlice;
}

struct PriceInfo {
    price: coins;
    validUntil: uint32;
    maybeJettonInfo: JettonInfo?;
}

struct ReserveTonsPayload {
    coinsToReserve: coins?;
}

struct UpdateInfo {
    signTime: uint32;
    contractAddress: address;
    newMerkleRoot: uint256;
}

struct (0xb1f57834) SetNewDataMessage {
    queryId: uint64;
    updateInfo: Cell<UpdateInfo>;
    signature: bits512;
}

struct (0x0609e47b) MultipleOfferDeployMessage {
    queryId: uint64;
    merkleRoot: uint256;
    commissionFactor: uint16;
    web3CommissionFactor: uint16;
    web3WalletAddress: address;
}

struct (0x05138d91) SellNftMessage {  // не используем NftOwnershipAssignedMessage<MerkleProofCell>, т.к. у нас пруф всегда в ссылке
    queryId: uint64;
    fromAddress: address;
    forwardPayload: Cell<MerkleProofCell>;
}

type TopUpJettonBalanceMessage = JettonsTransferNotificationMessage<ReserveTonsPayload>;

type AllowedMessage = (
    MultipleOfferDeployMessage
    | SellNftMessage
    | TopUpJettonBalanceMessage
    | SetNewDataMessage
    | WithdrawSomeTonMessage
    | WithdrawJettonMessage
    | ExcessesMessage
);
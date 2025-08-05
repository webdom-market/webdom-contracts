import "@stdlib/tvm-dicts";
import "../../imports/constants";
import "../../imports/messages";
import "../../imports/utils";
import "storage";
import "messages";
import "../constants";
import "@stdlib/gas-payments";
import "../../imports/admin_message"
import "../../imports/types"


@inline
fun cancelDeal(queryId: uint64) {
    var storage = lazy Storage.load();
    var (jettonWalletAddress, jettonBalanceSlice, _) = storage.jettonBalancesDict.sDictGetFirst(267);
    while (jettonBalanceSlice != null) {
        val jettonBalance: coins = jettonBalanceSlice.loadCoins();
        if (jettonBalance > 0) {
            createMessage({
                bounce: false,
                value: TONS_JETTON_TRANSFER,
                dest: jettonWalletAddress! as address,
                body: SendJettonsMessage<cell> { 
                    queryId: queryId,
                    jettonAmount: jettonBalance,
                    toAddress: storage.ownerAddress,
                    responseAddress: storage.ownerAddress,
                    forwardTonAmount: 1,
                    forwardPayload: (CommentMessage { comment: "Jetton withdrawal" }).toCell()
                }
            }).send(SEND_MODE_REGULAR);
        }
        (jettonWalletAddress, jettonBalanceSlice, _) = storage.jettonBalancesDict.sDictGetNext(267, jettonWalletAddress!);
    }
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.ownerAddress,
        body: CommentMessage { comment: "Multiple offer was cancelled" },
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    storage.merkleRoot = 0;
    storage.jettonBalancesDict = null;
    storage.soldNftsDict = null;

    storage.save();
}

fun onInternalMessage(in: InMessage) {
    forceSameWorkchain(in.senderAddress);
    
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: true,
        allowChangeData: true,
        allowSendAnyMessage: true,
    });

    val msg = lazy AllowedMessage.fromSlice(in.body);
    val contractBalance: coins = contract.getOriginalBalance();

    match (msg) {
        MultipleOfferDeployMessage => {
            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                var storage = lazy Storage.load();
                assert (storage.merkleRoot == 0) throw EXC_ALREADY_DEPLOYED;

                storage.merkleRoot = msg.merkleRoot;
                storage.commissionFactor = msg.commissionFactor;
                storage.web3CommissionFactor = msg.web3CommissionFactor;
                storage.web3WalletAddress = msg.web3WalletAddress;
                storage.save();
            }
            
        }

        SellNftMessage => {
            var storage = lazy Storage.load();
            try {
                val (_, alreadySold) = storage.soldNftsDict.sDictGet(267, in.senderAddress as slice);
                assert (!alreadySold) throw EXC_NFT_ALREADY_SOLD;
                
                var (proofCellSlice, isExotic) = beginParseExotic(msg.forwardPayload);
                assert (isExotic && proofCellSlice.loadUint(8) == 0x03) throw EXC_INCORRECT_EXOTIC_CELL;
                assert (proofCellSlice.loadUint(256) == storage.merkleRoot) throw EXC_INCORRECT_PROOF;
                
                var (priceInfoSlice, nftFound) = proofCellSlice.loadRef().sDictGet(267, in.senderAddress as slice);
                assert (nftFound) throw EXC_NFT_NOT_FOUND;
                val priceInfo = PriceInfo.fromSlice(priceInfoSlice!);
                assert (priceInfo.validUntil >= blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;

                var commission: coins = mulDivFloor(priceInfo.price, storage.commissionFactor, COMMISSION_DIVIDER);
                var remainingBalance: coins;
                var oneJetton: coins = ton("1");
                var symbol: slice = "TON";

                if (priceInfo.maybeJettonInfo == null) {
                    // за газ платит продавец
                    val requiredGas: coins = TONS_NFT_TRANSFER + ton("0.02");
                    assert (requiredGas <= in.valueCoins) throw EXC_OUT_OF_GAS;
                    
                    remainingBalance = contractBalance - (priceInfo.price + commission + in.valueCoins + storageFees());  // за storage fees платит создатель оффера
                    assert (remainingBalance >= 0) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(remainingBalance, RESERVE_MODE_EXACT_AMOUNT);

                    if (commission > TONS_MIN_EXCESS) {
                        createMessage({
                            bounce: false,
                            value: commission,
                            dest: MARKETPLACE_ADDRESS,
                            body: CommentMessage { comment: "Marketplace commission" }
                        }).send(SEND_MODE_REGULAR);
                    }
                    createMessage({
                        bounce: false,
                        value: priceInfo.price + in.valueCoins - requiredGas,
                        dest: msg.fromAddress,
                        body: CommentMessage { comment: "NFT sold on webdom.market" }
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);                    
                } else {
                    val jettonWalletAddress = priceInfo.maybeJettonInfo.jettonWalletAddress;
                    oneJetton = priceInfo.maybeJettonInfo.oneJetton;
                    symbol = priceInfo.maybeJettonInfo.symbol;

                    if (jettonWalletAddress == storage.web3WalletAddress) {
                        commission = mulDivFloor(priceInfo.price, storage.web3CommissionFactor, COMMISSION_DIVIDER);
                    }
                    remainingBalance = storage.getJettonBalance(jettonWalletAddress) - priceInfo.price - commission;
                    assert (remainingBalance >= 0) throw EXC_NOT_ENOUGH_JETTONS;
                    storage.setJettonBalance(jettonWalletAddress, remainingBalance);
                    
                    var requiredGas: coins = (TONS_NFT_TRANSFER + TONS_JETTON_TRANSFER + ton("0.02"));
                    if (commission > 0) {
                        createMessage({
                            bounce: false,
                            value: TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE,
                            dest: jettonWalletAddress,
                            body: SendJettonsMessage<cell> { 
                                queryId: msg.queryId,
                                jettonAmount: commission,
                                toAddress: MARKETPLACE_ADDRESS,
                                responseAddress: msg.fromAddress,
                                forwardTonAmount: TONS_NOTIFY_MARKETPLACE,
                                forwardPayload: MARKETPLACE_COMMISSION_NOTIFICATION()
                            }
                        }).send(SEND_MODE_REGULAR);
                        requiredGas += (TONS_JETTON_TRANSFER + TONS_NOTIFY_MARKETPLACE);
                    }
                    assert (requiredGas <= in.valueCoins) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(storageFees(), RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);
                    
                    createMessage({
                        bounce: false,
                        value: TONS_JETTON_TRANSFER + in.valueCoins - requiredGas,
                        dest: jettonWalletAddress,
                        body: SendJettonsMessage<cell> { 
                            queryId: msg.queryId,
                            jettonAmount: priceInfo.price,
                            toAddress: msg.fromAddress,
                            responseAddress: msg.fromAddress,
                            forwardTonAmount: 1,
                            forwardPayload: NFT_SOLD_NOTIFICATION()
                        }
                    }).send(SEND_MODE_REGULAR);            
                }

                createMessage({
                    bounce: false,
                    value: 0,
                    dest: in.senderAddress,
                    body: NftTransferMessage<cell> { 
                        queryId: msg.queryId,
                        toAddress: storage.ownerAddress,
                        responseAddress: msg.fromAddress,
                        forwardTonAmount: 1,
                        forwardPayload: beginCell()
                                            .storeUint(0, 32)
                                            .storeSlice("webdom multi-offer executed. Remaining balance: ")
                                            .storeStrJettons(remainingBalance, oneJetton, symbol)
                                        .endCell()
                    }
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
                
                storage.soldNftsDict.sDictSetBuilder(267, in.senderAddress as slice, beginCell().storeUint(blockchain.now(), 32));
                storage.save();
            }
            catch (e, _) {
                returnNftToSender(in.senderAddress, NftOwnershipAssignedMessage<bool> {
                    queryId: msg.queryId,
                    fromAddress: msg.fromAddress,
                    forwardPayload: false
                }, e);
            }

        }

        TopUpJettonBalanceMessage => {
            var storage = lazy Storage.load();
            var forwardPayload: ReserveTonsPayload;
            match(msg.forwardPayload) {
                Cell<ReserveTonsPayload> => {
                    forwardPayload = ReserveTonsPayload.fromCell(msg.forwardPayload);
                }
                ReserveTonsPayload => {
                    forwardPayload = msg.forwardPayload;
                }
            }
            var coinsToReserve: coins = forwardPayload.coinsToReserve == null ? 0 : forwardPayload.coinsToReserve;
            reserveToncoinsOnBalance(coinsToReserve + 1, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);
            if (in.valueCoins - coinsToReserve > TONS_MIN_EXCESS) {
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: msg.fromAddress,
                    body: CommentMessage { comment: "Jetton balance of the multi-offer was filled up" },
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }
            
            val prevJettonBalance = storage.getJettonBalance(in.senderAddress);
            storage.setJettonBalance(in.senderAddress, prevJettonBalance + msg.transferredJettons);
            storage.save();
        }

        SetNewDataMessage => {
            var storage = lazy Storage.load();

            assert (in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER;
            val publicKey = storage.publicKeyCell.load();
            assert (isSignatureValid(msg.updateInfo.hash(), msg.signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;

            val updateInfo = UpdateInfo.fromCell(msg.updateInfo);
            assert (updateInfo.signTime + 600 > blockchain.now() && updateInfo.contractAddress == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
            storage.merkleRoot = updateInfo.newMerkleRoot;

            var (nftAddress, soldTimeSlice, isFound) = storage.soldNftsDict.sDictGetFirst(267);
            while (isFound) {
                val soldTime: uint32 = soldTimeSlice!.loadUint(32);
                if (soldTime < updateInfo.signTime) {
                    storage.soldNftsDict.sDictDelete(267, nftAddress! as slice);
                }
                (nftAddress, soldTimeSlice, isFound) = storage.soldNftsDict.sDictGetNext(267, nftAddress!);
            }
            storage.save();

            createMessage({
                bounce: false,
                value: 0,
                dest: storage.ownerAddress,
                body: CommentMessage { comment: "Multiple offer was successfully updated" },
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        WithdrawSomeTonMessage => {
            var storage = lazy Storage.load();

            assert (in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER;
            val coinsToReserve = ((msg.withdrawAmount > contractBalance - in.valueCoins) | (msg.withdrawAmount == 0)) ? TONS_MIN_RESERVE : contractBalance - msg.withdrawAmount - in.valueCoins;
            reserveToncoinsOnBalance(coinsToReserve, RESERVE_MODE_EXACT_AMOUNT);
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.ownerAddress,
                body: CommentMessage { comment: "TON withdrawal" },
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
        }

        WithdrawJettonMessage => {
            var storage = lazy Storage.load();

            assert (in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER;
            createMessage({
                bounce: false,
                value: 0,
                dest: msg.jettonWalletAddress,
                body: SendJettonsMessage<cell> { 
                    queryId: msg.queryId,
                    jettonAmount: msg.withdrawAmount,
                    toAddress: storage.ownerAddress,
                    responseAddress: contract.getAddress(),
                    forwardTonAmount: 1,
                    forwardPayload: (CommentMessage { comment: "Jetton withdrawal" }).toCell()
                }
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
            
            val jettonBalance = storage.getJettonBalance(msg.jettonWalletAddress);
            storage.setJettonBalance(msg.jettonWalletAddress, max(jettonBalance - msg.withdrawAmount, 0));
            storage.save();
        }

        ExcessesMessage => {
            // accept coins
        }

        else => {
            val op: uint32 = in.body.loadUint(32);
            if (op == 0 && in.body.bitsEqual("cancel")) {
                cancelDeal(blockchain.currentBlockLogicalTime());
            }
            else if (!in.body.bitsEqual("fillup")) {
                throw EXC_UNSUPPORTED_OP;
            }
        }
    }
}


get fun get_storage_data() {
    var storage = Storage.load();
    var publicKey = storage.publicKeyCell.load();
    return (
        storage.ownerAddress,
        storage.merkleRoot,
        publicKey,
        storage.commissionFactor,
        storage.web3CommissionFactor,
        storage.soldNftsDict,
        storage.jettonBalancesDict,
        storage.web3WalletAddress
    );
}

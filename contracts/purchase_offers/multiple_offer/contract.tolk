import "@stdlib/tvm-dicts"
import "../../imports/constants"
import "../../imports/messages"
import "../../imports/utils"
import "../../imports/admin_message"
import "../constants"
import "storage"
import "messages"


// "Cancel" the multiple offer -- reset contract state and return all funds to owner
@inline
fun cancelDeal(queryId: uint64, storage: Storage): void {    
    // Return all jettons to owner
    var (jettonWalletAddress: slice?, jettonBalanceSlice: slice?, _) = storage.jettonBalancesDict.sDictGetFirst(267);
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
    
    // Return remaining TON balance to owner
    createMessage({
        bounce: false,
        value: 0,
        dest: storage.ownerAddress,
        body: CommentMessage { comment: "Multiple offer was cancelled" },
    }).send(SEND_MODE_CARRY_ALL_BALANCE);

    // Reset contract state
    storage.merkleRoot = 0;
    storage.jettonBalancesDict = null;
    storage.soldNftsDict = null;

    storage.save();
}


fun onInternalMessage(in: InMessage): void {
    forceSameWorkchain(in.senderAddress);
    
    // Handle admin messages for contract management (allow all operations for now)
    handleAdminMessage(in.senderAddress, in.body, Permissions {
        allowChangeCode: true,
        allowChangeData: true,
        allowSendAnyMessage: true,
    });

    val msg: AllowedMessage = lazy AllowedMessage.fromSlice(in.body);
    val contractBalance: coins = contract.getOriginalBalance();

    match (msg) {
        MultipleOfferDeployMessage => {
            // If message is from the marketplace, this is a deploy transaction, otherwise it's a simple fill-up transaction
            if (in.senderAddress == MARKETPLACE_ADDRESS) {
                var storage: Storage = lazy Storage.load();
                assert(storage.merkleRoot == 0) throw EXC_ALREADY_DEPLOYED;  // check if offer is already deployed

                // Initialize offer configuration
                storage.merkleRoot = msg.merkleRoot;
                storage.commissionFactor = msg.commissionFactor;
                storage.web3CommissionFactor = msg.web3CommissionFactor;
                storage.web3WalletAddress = msg.web3WalletAddress;
                storage.save();

                return;
            }

            return;
        }

        // Handle NFT sale with Merkle proof verification
        SellNftMessage => {
            var storage: Storage = lazy Storage.load();
            try {
                // Check that the NFT was not already sold
                val (_, alreadySold) = storage.soldNftsDict.sDictGet(267, in.senderAddress as slice);
                assert(!alreadySold) throw EXC_NFT_ALREADY_SOLD;
                
                // Load and verify Merkle proof
                var (proofCellSlice, isExotic) = beginParseExotic(msg.forwardPayload);
                assert(isExotic && proofCellSlice.loadUint(8) == 0x03) throw EXC_INCORRECT_EXOTIC_CELL;
                assert(proofCellSlice.loadUint(256) == storage.merkleRoot) throw EXC_INCORRECT_PROOF;
                
                // Extract sale conditions from proof
                var (priceInfoSlice, nftFound) = proofCellSlice.loadRef().sDictGet(267, in.senderAddress as slice);
                assert(nftFound) throw EXC_NFT_NOT_FOUND;
                val priceInfo: PriceInfo = PriceInfo.fromSlice(priceInfoSlice!);
                assert(priceInfo.validUntil >= blockchain.now()) throw EXC_DEAL_NOT_ACTIVE;

                // Calculate commission and prepare payment variables
                var commission: coins = mulDivFloor(priceInfo.price, storage.commissionFactor, COMMISSION_DIVIDER);
                var remainingBalance: coins;
                var oneJetton: coins = ton("1");
                var symbol: slice = "TON";

                if (priceInfo.maybeJettonInfo == null) {  // sale for TON 
                    val requiredGas: coins = TONS_NFT_TRANSFER + ton("0.02");
                    assert(requiredGas <= in.valueCoins) throw EXC_OUT_OF_GAS;
                    
                    // Calculate remaining balance after payment and fees (offer creator pays storage fees, seller pays for gas)
                    remainingBalance = contractBalance - (priceInfo.price + commission + in.valueCoins + storageFees());
                    assert(remainingBalance >= 0) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(remainingBalance, RESERVE_MODE_EXACT_AMOUNT);

                    // Send marketplace commission
                    if (commission > TONS_MIN_EXCESS) {
                        createMessage({
                            bounce: false,
                            value: commission,
                            dest: MARKETPLACE_ADDRESS,
                            body: CommentMessage { comment: "Marketplace commission" }
                        }).send(SEND_MODE_REGULAR);
                    }
                    
                    // Send payment to seller
                    createMessage({
                        bounce: false,
                        value: priceInfo.price + in.valueCoins - requiredGas,
                        dest: msg.fromAddress,
                        body: CommentMessage { comment: "NFT sold on webdom.market" }
                    }).send(SEND_MODE_PAY_FEES_SEPARATELY);
                } else {  // sale for jettons
                    val jettonWalletAddress: address = priceInfo.maybeJettonInfo.jettonWalletAddress;
                    oneJetton = priceInfo.maybeJettonInfo.oneJetton;
                    symbol = priceInfo.maybeJettonInfo.symbol;

                    // Use special commission rate for WEB3 tokens
                    if (jettonWalletAddress == storage.web3WalletAddress) {
                        commission = mulDivFloor(priceInfo.price, storage.web3CommissionFactor, COMMISSION_DIVIDER);
                    }
                    
                    // Check and update jetton balance
                    remainingBalance = storage.getJettonBalance(jettonWalletAddress) - priceInfo.price - commission;
                    assert(remainingBalance >= 0) throw EXC_NOT_ENOUGH_JETTONS;
                    storage.setJettonBalance(jettonWalletAddress, remainingBalance);
                    
                    // Calculate required gas for jetton operations (seller pays for it)
                    var requiredGas: coins = (TONS_NFT_TRANSFER + TONS_JETTON_TRANSFER + ton("0.02"));
                    
                    // Send marketplace commission in jettons
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
                    
                    assert(requiredGas <= in.valueCoins) throw EXC_OUT_OF_GAS;
                    reserveToncoinsOnBalance(storageFees(), RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);
                    
                    // Send jetton payment to seller
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

                // Transfer NFT to buyer with the info about the remaining balance
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
                
                // Mark NFT as sold with timestamp
                storage.soldNftsDict.sDictSetBuilder(267, in.senderAddress as slice, beginCell().storeUint(blockchain.now(), 32));
                storage.save();
            }
            catch (e, _) {
                // Return NFT to sender on error
                returnNftToSender(in.senderAddress, NftOwnershipAssignedMessage<bool> {
                    queryId: msg.queryId,
                    fromAddress: msg.fromAddress,
                    forwardPayload: false
                }, e);
            }
        }

        // Handle jetton deposits
        TopUpJettonBalanceMessage => {
            var storage: Storage = lazy Storage.load();
            
            // Parse forward payload to get TON reservation amount
            var forwardPayload: ReserveTonsPayload;
            match(msg.forwardPayload) {
                Cell<ReserveTonsPayload> => {
                    forwardPayload = ReserveTonsPayload.fromCell(msg.forwardPayload);
                }
                ReserveTonsPayload => {
                    forwardPayload = msg.forwardPayload;
                }
            }
            
            // Reserve TON for future operations
            var coinsToReserve: coins = forwardPayload.coinsToReserve == null ? 0 : forwardPayload.coinsToReserve;
            reserveToncoinsOnBalance(coinsToReserve + 1, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);
            
            // Send excess
            if (in.valueCoins - coinsToReserve > TONS_MIN_EXCESS) {
                createMessage({
                    bounce: false,
                    value: 0,
                    dest: msg.fromAddress,
                    body: CommentMessage { comment: "Jetton balance of the multi-offer was filled up" },
                }).send(SEND_MODE_CARRY_ALL_BALANCE);
            }
            
            // Update jetton balance
            val prevJettonBalance: coins = storage.getJettonBalance(in.senderAddress);
            storage.setJettonBalance(in.senderAddress, prevJettonBalance + msg.transferredJettons);
            storage.save();
        }

        // Update offer data with new Merkle root
        SetNewDataMessage => {
            var storage: Storage = lazy Storage.load();

            // Verify sender is owner
            assert(in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER;
            
            // Verify signature. Used to ensure that the new merkle tree is stored in the marketplace's backend 
            val publicKey: uint256 = storage.publicKeyCell.load();
            assert(isSignatureValid(msg.updateInfo.hash(), msg.signature as slice, publicKey)) throw EXC_INVALID_SIGNATURE;

            // Verify update info validity
            val updateInfo: UpdateInfo = UpdateInfo.fromCell(msg.updateInfo);
            assert(updateInfo.signTime + 600 > blockchain.now() && updateInfo.contractAddress == contract.getAddress()) throw EXC_INVALID_SIGNATURE;
            
            // Update Merkle root
            storage.merkleRoot = updateInfo.newMerkleRoot;

            // Clean up old sold NFTs (sold before this update)
            var (nftAddress, soldTimeSlice, isFound) = storage.soldNftsDict.sDictGetFirst(267);
            while (isFound) {
                val soldTime: uint32 = soldTimeSlice!.loadUint(32);
                if (soldTime < updateInfo.signTime) {
                    storage.soldNftsDict.sDictDelete(267, nftAddress! as slice);
                }
                (nftAddress, soldTimeSlice, isFound) = storage.soldNftsDict.sDictGetNext(267, nftAddress!);
            }
            storage.save();

            // Confirm successful update
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.ownerAddress,
                body: CommentMessage { comment: "Multiple offer was successfully updated" },
            }).send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        // Withdraw TON from contract
        WithdrawSomeTonMessage => {
            var storage: Storage = lazy Storage.load();

            // Verify sender is owner
            assert(in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER; 
            
            // Set TON amount to reserve. If the amount not specified, reserve the minimum amount.
            val coinsToReserve: coins = ((msg.withdrawAmount > contractBalance - in.valueCoins) | (msg.withdrawAmount == 0)) ? TONS_MIN_RESERVE : contractBalance - msg.withdrawAmount - in.valueCoins;
            reserveToncoinsOnBalance(coinsToReserve, RESERVE_MODE_EXACT_AMOUNT);
            
            // Send remaining balance to owner
            createMessage({
                bounce: false,
                value: 0,
                dest: storage.ownerAddress,
                body: CommentMessage { comment: "TON withdrawal" },
            }).send(SEND_MODE_CARRY_ALL_BALANCE);
        }

        // Withdraw jettons from contract
        WithdrawJettonMessage => {
            var storage: Storage = lazy Storage.load();

            // Verify sender is owner
            assert(in.senderAddress == storage.ownerAddress) throw EXC_INCORRECT_SENDER;
            
            // Send jettons
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
            
            // Update jetton balance
            val jettonBalance: coins = storage.getJettonBalance(msg.jettonWalletAddress);
            storage.setJettonBalance(msg.jettonWalletAddress, max(jettonBalance - msg.withdrawAmount, 0));
            storage.save();
        }

        ExcessesMessage => {
            // Accept coins without action
        }

        else => {
            val op: uint32 = in.body.loadUint(32);
            if (op == 0 && in.body.bitsEqual("cancel")) {
                // Handle text-based cancellation
                var storage: Storage = lazy Storage.load();
                assert(in.senderAddress == storage.ownerAddress || in.senderAddress == ADMIN_ADDRESS) throw EXC_INCORRECT_SENDER;
                cancelDeal(blockchain.currentBlockLogicalTime(), storage);
            }
            else if (!in.body.bitsEqual("fillup")) {
                // Ignore "fillup" messages, throw error for unknown operations
                throw EXC_UNSUPPORTED_OP;
            }
        }
    }
}


// Get contract storage data for external queries
get fun get_storage_data() {
    var storage: Storage = Storage.load();
    var publicKey: uint256 = storage.publicKeyCell.load();
    return (
        storage.ownerAddress,          // Owner of the multiple offer
        storage.merkleRoot,            // Current Merkle root for sale conditions dictionary
        publicKey,                     // Public key for signature verification
        storage.commissionFactor,      // Standard commission factor
        storage.web3CommissionFactor,  // WEB3 token commission factor
        storage.soldNftsDict,          // Dictionary of sold NFTs with timestamps
        storage.jettonBalancesDict,    // Dictionary of jetton balances per wallet
        storage.web3WalletAddress      // WEB3 jetton wallet address
    );
}

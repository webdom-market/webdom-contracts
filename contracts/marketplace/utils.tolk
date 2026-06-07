import "../imports/types"
import "storage"
import "@stdlib/tvm-dicts"
import "../imports/constants"
import "types"
import "constants"
import "@stdlib/gas-payments"
import "../imports/gas"
import "../imports/dns"
import "../imports/messages"


// Functions for executing deploy functions with differend arguments
@inline
fun executeDeploySimple(c: continuation, args: SimpleDeployArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithNftTransfer(c: continuation, args: DeployWithNftTransferArgs): coins 
    asm (args c) "EXECUTE";

@inline
fun executeDeployWithJettonTransfer(c: continuation, args: DeployWithJettonTransferArgs): coins 
    asm (args c) "EXECUTE";


// Marketplace supports discounts for whitelisted users 
@inline
fun getCommissionDiscount(discountInfoCell: cell?, fromAddress: address, publicKey: uint256): uint16 {
    if (discountInfoCell == null) {
        return 0;
    }
    
    var discountInfo: slice = discountInfoCell!.beginParse();
    var signature: slice = discountInfo.loadRef().beginParse();
    
    assert(
        isSignatureValid(discountInfo.hash(), signature, publicKey) &&   // Check that discountInfo was signed by the marketplace backend
        discountInfo.loadUint(32) + 600 >= blockchain.now() &&           // Check that signature is still valid
        discountInfo.loadAddress() == fromAddress                        // Check that discountInfo is for the current user
    ) throw EXC_INVALID_SIGNATURE;
    
    return discountInfo.loadUint(16);  // Return discount percentage (commission = baseCommission * (COMMISSION_DIVIDER - discount) / COMMISSION_DIVIDER)
}


@inline
fun addCollectedFees(collectedFeesDict: dict, jettonWalletAddress: address, transferredJettons: coins): dict {
    var (collectedFeesSlice: slice?, found: bool) = collectedFeesDict.sDictGet(267, jettonWalletAddress as slice);
    val currentFees: coins = found ? (coins.fromSlice(collectedFeesSlice!)) : (0 as coins);
    
    collectedFeesDict.sDictSetBuilder(
        267, jettonWalletAddress as slice, beginCell().storeCoins(currentFees + transferredJettons)
    );

    return collectedFeesDict;
}


// Send one change_dns_record to a domain owned by the marketplace. Carries changeDnsRecordValue()
// (the item's compute + one year of the record's storage, measured in ChangeDnsRecordGas.spec.ts);
// the forward fee is paid separately and added on top via sendAndEstimateFee. Returns the total TON
// the marketplace spends on this message, so the caller can account for it in the gas check.
@inline
fun sendChangeDnsRecord(domainAddress: address, queryId: uint64, dnsKey: uint256, dnsValue: cell): coins {
    val recordValue: coins = changeDnsRecordValue();
    val sentFee: coins = createMessage<ChangeDnsRecordMessage>({
        bounce: false,
        value: recordValue,
        dest: domainAddress,
        body: ChangeDnsRecordMessage {
            queryId: queryId,
            key: dnsKey,
            value: dnsValue
        }
    }).sendAndEstimateFee(SEND_MODE_PAY_FEES_SEPARATELY);
    return recordValue + sentFee;
}

// Apply the marketplace's DNS records to a domain it currently owns: every entry of the global
// dnsRecordsDict (dnsRecord(uint256) -> value ref, e.g. the fixed picture/description) plus a
// per-domain `links` record pointing at the domain's webdom listing page. Returns the total TON
// spent, so the caller can account for it in the gas check.
@inline
fun updateDomainDnsRecords(storage: MarketplaceStorage, domainAddress: address, queryId: uint64, domainName: slice): coins {
    val ds2: MarketplaceStorageDs2 = lazy storage.ds2.load();
    var dnsRecordsDict: dict = ds2.dnsRecordsDict;

    var totalSpent: coins = 0;
    var (dnsKey: int?, dnsValue: slice?, found: bool) = dnsRecordsDict.uDictGetFirst(256);
    while (found) {
        totalSpent += sendChangeDnsRecord(domainAddress, queryId, dnsKey! as uint256, dnsValue!.preloadRef());
        (dnsKey, dnsValue, found) = dnsRecordsDict.uDictGetNext(256, dnsKey!);
    }

    // Dynamic per-domain link record (the admin dict is global, so it cannot hold this)
    totalSpent += sendChangeDnsRecord(domainAddress, queryId, DNS_KEY_LINKS, buildDomainLinkRecord(domainName));

    return totalSpent;
}


@inline
fun checkEnoughGas(msgValue: coins, requiredGas: coins, fromAddress: address, queryId: uint64): void {
    // Calculate total required TONs accounting compute fees
    val totalRequired = requiredGas + calculateGasFee(WORKCHAIN, getGasConsumedAtTheMoment() + 200);
    if (msgValue - totalRequired >= TONS_MIN_EXCESS) {
        // Send excess
        createMessage({
            bounce: false,
            value: 0,
            dest: fromAddress,
            body: CommentMessage { comment: "Deal on webdom.market is active".literalSlice() }
        }).send(SEND_MODE_CARRY_ALL_BALANCE);
        return;
    }
    assert(msgValue >= totalRequired) throw EXC_OUT_OF_GAS;
}


@inline
fun parseDeployInfo(storage: MarketplaceStorage, op: uint32, deployType: uint2): DeployInfo<SerializableSlice> {
    var (deployInfoSlice: slice?, found: bool) = storage.deployInfos.uDictGet(32, op);
    assert(found) throw EXC_UNSUPPORTED_OP;

    var deployInfo = DeployInfo<SerializableSlice>.fromSlice(deployInfoSlice!);
    assert(deployInfo.deployType == deployType) throw EXC_INCORRECT_DEPLOY_TYPE;

    // Reserve deploy fee
    reserveToncoinsOnBalance(deployInfo.deployFee, RESERVE_MODE_INCREASE_BY_ORIGINAL_BALANCE);

    return deployInfo;
}

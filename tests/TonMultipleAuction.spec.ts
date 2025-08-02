import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { TonMultipleAuction, TonMultipleAuctionConfig } from '../wrappers/TonMultipleAuction';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes, Tons } from '../wrappers/helpers/constants';
import { abs, min, max } from './helpers/common';

describe('TonMultipleAuction', () => {
    let tonMultipleAuctionCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        tonMultipleAuctionCode = await compile('TonMultipleAuction');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let tonMultipleAuction: SandboxContract<TonMultipleAuction>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton"];
    let domainConfigs: Array<DomainConfig>;
    let transactionRes: SendMessageResult;

    let tonMultipleAuctionConfig: TonMultipleAuctionConfig;

    async function deployAuction() {
        tonMultipleAuctionConfig.state = TonMultipleAuction.STATE_UNINIT;
        tonMultipleAuction = blockchain.openContract(
            TonMultipleAuction.createFromConfig(tonMultipleAuctionConfig, tonMultipleAuctionCode)
        );

        transactionRes = await tonMultipleAuction.sendDeploy(marketplace.getSender(), toNano('0.06'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: tonMultipleAuction.address,
            deploy: true,
            success: true
        });
    }

    async function sendDomainsToAuction() {
        for (let domain of domains) {
            transactionRes = await domain.sendTransfer(seller.getSender(), tonMultipleAuction.address, seller.address, null, toNano('0.07'));
            domainConfigs.push(await domain.getStorageData());
        }
    }

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        domains = [];
        domainConfigs = [];

        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;
        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');

        // Deploy DNS Collection
        dnsCollection = blockchain.openContract(DnsCollection.createFromConfig({
            content: beginCell().endCell(),
            nftItemCode: domainCode,
        } as DnsCollectionConfig, dnsCollectionCode));

        transactionRes = await dnsCollection.sendDeploy(admin.getSender(), toNano('0.05'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: dnsCollection.address,
            deploy: true,
            success: true,
        });

        // Deploy domains and transfer to seller
        let domainsDict: Dictionary<Address, number> = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(1));
        for (let domainName of DOMAIN_NAMES) {
            transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), domainName);
            const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address;
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            
            blockchain.now! += 60 * 60 + 1;  // end of the auction
            transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
            
            domains.push(domain);
            domainsDict.set(domainAddress, 0);
        }

        // Configure and deploy auction contract
        tonMultipleAuctionConfig = {
            sellerAddress: seller.address,
            domainsDict: domainsDict,
            domainsTotal: domains.length,
            domainsReceived: 0,
            minBidValue: toNano('1'),
            maxBidValue: toNano('10'),
            minBidIncrement: 1050,  // 5% minimum increment
            timeIncrement: 60 * 5,  // 5 minutes extension
            commissionFactor: 500,  // 5% commission
            maxCommission: toNano('1'),
            state: TonMultipleAuction.STATE_UNINIT,
            startTime: blockchain.now! + 60,
            endTime: blockchain.now! + ONE_DAY * 120,
            lastDomainRenewalTime: blockchain.now!,
            lastBidValue: 0n,
            lastBidTime: blockchain.now!,
            lastBidderAddress: null,
            isDeferred: false
        };

        await deployAuction();
    });

    it('should accept bids and extend time', async () => {
        await sendDomainsToAuction();

        // Try bid before start time - should fail
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });

        // Move to start time
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Place minimum bid
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(tonMultipleAuctionConfig.minBidValue);
        expect(tonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(buyer.address.toString());

        // Check auction state
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_ACTIVE);

        // Place higher bid
        const newBid = tonMultipleAuctionConfig.minBidValue * 2n;
        blockchain.now = tonMultipleAuctionConfig.endTime - 60;  // Just before end
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), newBid, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(newBid);
        expect(tonMultipleAuctionConfig.endTime).toEqual(blockchain.now + tonMultipleAuctionConfig.timeIncrement);
    });

    it('should handle bid at start time', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Place bid exactly at start time
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Verify auction state
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(tonMultipleAuctionConfig.minBidValue);
        expect(tonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(buyer.address.toString());
    });

    it('should handle bid at end time', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.endTime;

        // Try to place bid exactly at end time - should fail
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });

        // Verify auction state remains unchanged
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_ACTIVE);
    });

    it('should reject unauthorized auction cancellation', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Try to cancel auction as a non-seller
        transactionRes = await tonMultipleAuction.sendStopAuction(buyer.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.INCORRECT_SENDER
        });

        // Verify auction state remains unchanged
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_ACTIVE);
    });

    it('should handle multiple consecutive bids from the same user', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // First bid
        let currentBid = tonMultipleAuctionConfig.minBidValue;
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), currentBid, domains.length);

        // Second bid
        currentBid = currentBid * 2n;
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), currentBid, domains.length);

        // Verify auction state and last bid
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(currentBid);
        expect(tonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(buyer.address.toString());
    });

    it('should handle bid exactly at minimum increment', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Place initial bid
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), toNano('2'), domains.length);

        // Place bid with exact minimum increment
        const exactIncrementBid = toNano('2.1');
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), exactIncrementBid, domains.length);
        printTransactionFees(transactionRes.transactions)
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Verify auction state and last bid
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(exactIncrementBid);
        expect(tonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(admin.address.toString());
    });

    it('should reject bid with insufficient funds', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Try to place bid with insufficient funds
        const insufficientBid = toNano('0.5');
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), insufficientBid, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // Verify auction state remains unchanged
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(0n);
    });

    it('should end auction when max bid is reached', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Place minimum bid
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(tonMultipleAuctionConfig.minBidValue);
        expect(tonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(buyer.address.toString());
        
        // Place higher bid
        const newBid = tonMultipleAuctionConfig.minBidValue * 2n;
        blockchain.now = tonMultipleAuctionConfig.endTime - 60;  // Just before end
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), newBid, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Place max bid
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.maxBidValue, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_COMPLETED);
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(tonMultipleAuctionConfig.maxBidValue);

        // Verify domains transferred to buyer
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.ownerAddress?.toString()).toEqual(buyer.address.toString());
        }
    });

    it('should allow auction cancellation if no bids placed', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime + 60;
        
        transactionRes = await tonMultipleAuction.sendStopAuction(seller.getSender());
        printTransactionFees(transactionRes.transactions)
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_CANCELLED);

        // Verify domains returned to seller
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.ownerAddress?.toString()).toEqual(seller.address.toString());
        }
    });

    it('should handle domain renewal', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        transactionRes = await tonMultipleAuction.sendRenewDomain(seller.getSender(), domains.length);
        
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastDomainRenewalTime).toEqual(blockchain.now);

        // Verify domains were renewed
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.lastRenewalTime).toEqual(blockchain.now);
        }
    });

    it('should end auction via external message after end time', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        // Place a bid
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        
        // Move past end time
        blockchain.now = tonMultipleAuctionConfig.endTime + 1;
        
        // End auction with external message
        transactionRes = await tonMultipleAuction.sendExternalCancel();
        
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_COMPLETED);

        // Verify domains transferred to highest bidder
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.ownerAddress?.toString()).toEqual(buyer.address.toString());
        }
    });

    it('should reject bid below minimum increment', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        // Place initial bid
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        
        // Try to place bid with increment less than minimum
        const smallIncrementBid = tonMultipleAuctionConfig.minBidValue + toNano('0.01');
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), smallIncrementBid, domains.length);
        
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });
    });

    it('should correctly handle commission calculation', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        const bidAmount = toNano('5');
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), bidAmount, domains.length);
        
        blockchain.now = tonMultipleAuctionConfig.endTime + 1;
        transactionRes = await tonMultipleAuction.sendStopAuction(seller.getSender());
        
        // Check commission payment
        let expectedCommission = bidAmount * BigInt(tonMultipleAuctionConfig.commissionFactor) / 10000n;
        if (expectedCommission > tonMultipleAuctionConfig.maxCommission) {
            expectedCommission = tonMultipleAuctionConfig.maxCommission;
        }
        
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonMultipleAuction.address,
            to: marketplace.address,
            value(v) {
                return expectedCommission - v! < toNano('0.005');
            }
        });
    });

    it('should reject bids after auction end', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.endTime + 1;
        
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });
    });

    it('should return bid amount to previous bidder', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        // First bid
        const firstBid = tonMultipleAuctionConfig.minBidValue;
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), firstBid, domains.length);
        
        // Second higher bid
        const secondBid = firstBid * 2n;
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), secondBid, domains.length);
        
        // Check that first bidder got their bid back
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonMultipleAuction.address,
            to: buyer.address,
            value(v) {
                return v! >= firstBid;
            }
        });
    });

    it('should handle auction with no received domains', async () => {
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });
    });

    it('should handle bid above max value', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;
        
        // Place bid above max value
        const bidAmount = tonMultipleAuctionConfig.maxBidValue + toNano('1');
        const balanceBeforeBid = await buyer.getBalance();
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), bidAmount, domains.length);
        
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.lastBidValue).toEqual(tonMultipleAuctionConfig.maxBidValue);
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_COMPLETED);
        
        // Verify excess funds were returned
        expect(await buyer.getBalance()).toBeGreaterThan(balanceBeforeBid - tonMultipleAuctionConfig.maxBidValue - Tons.NFT_TRANSFER * BigInt(domains.length));
    });

    it('should handle failed transactions and balance changes correctly', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Store initial balances
        const initialBuyerBalance = await buyer.getBalance();
        const initialSellerBalance = await seller.getBalance();
        const initialAuctionBalance = (await blockchain.getContract(tonMultipleAuction.address)).balance;

        // Try to place bid with zero value
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), 0n, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // Verify balances remained unchanged
        expect(abs(initialBuyerBalance - await buyer.getBalance())).toBeLessThan(toNano('0.02'));
        expect(await seller.getBalance()).toEqual(initialSellerBalance);

        // Place valid bid
        const bidAmount = tonMultipleAuctionConfig.minBidValue;
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), bidAmount, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Verify balance changes after successful bid
        expect(await buyer.getBalance()).toBeLessThan(initialBuyerBalance - bidAmount);
        expect(Math.abs(Number(await seller.getBalance() - initialSellerBalance - initialAuctionBalance))).toBeLessThan(Number(toNano('0.01')));

        // Try to place lower bid (should fail)
        const lowerBidAmount = bidAmount - toNano('0.1');
        const secondBuyerBalance = await admin.getBalance();
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), lowerBidAmount, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // Verify second buyer's balance remained unchanged
        expect(abs(await admin.getBalance() - secondBuyerBalance)).toBeLessThan(toNano('0.01'));
    });

    it('should handle multiple failed transactions in sequence', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        const initialBuyerBalance = await buyer.getBalance();

        // Try multiple invalid bids
        const invalidBid = toNano('0.5');
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), invalidBid, domains.length);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonMultipleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // Verify buyer's balance after failed transactions
        const balanceAfterFailedTxs = await buyer.getBalance();
        // Should only lose gas fees
        expect(initialBuyerBalance - balanceAfterFailedTxs).toBeLessThan(toNano('0.02'));
    });

    it('should correctly handle balance changes during bid outbidding', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Store initial balances
        const initialBuyerBalance = await buyer.getBalance();
        const initialAdminBalance = await admin.getBalance();

        // First bid
        const firstBid = tonMultipleAuctionConfig.minBidValue;
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), firstBid, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Verify buyer's balance after first bid
        const buyerBalanceAfterBid = await buyer.getBalance();
        expect(buyerBalanceAfterBid).toBeLessThan(initialBuyerBalance - firstBid);

        // Second bid (outbidding)
        const secondBid = firstBid * 2n;
        transactionRes = await tonMultipleAuction.sendPlaceBid(admin.getSender(), secondBid, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Verify balances after outbidding
        expect(await admin.getBalance()).toBeLessThan(initialAdminBalance - secondBid);
        // Buyer should get their bid back (minus gas fees)
        expect(await buyer.getBalance()).toBeGreaterThan(buyerBalanceAfterBid + firstBid - toNano('0.1'));
    });

    it('should handle failed auction cancellation attempts', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        // Place a valid bid
        const bidAmount = tonMultipleAuctionConfig.minBidValue;
        await tonMultipleAuction.sendPlaceBid(buyer.getSender(), bidAmount, domains.length);

        const initialSellerBalance = await seller.getBalance();

        // Try to cancel auction with active bid (should fail)
        transactionRes = await tonMultipleAuction.sendStopAuction(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: tonMultipleAuction.address,
            success: false
        });

        // Verify seller's balance only lost gas fees
        expect(initialSellerBalance - await seller.getBalance()).toBeLessThan(toNano('0.1'));

        // Verify auction state remained unchanged
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_ACTIVE);
    });

    it('should verify balances after successful auction completion', async () => {
        await sendDomainsToAuction();
        blockchain.now = tonMultipleAuctionConfig.startTime;

        const initialBuyerBalance = await buyer.getBalance();
        const initialSellerBalance = await seller.getBalance();
        const initialMarketplaceBalance = await marketplace.getBalance();

        // Place winning bid
        const bidAmount = tonMultipleAuctionConfig.maxBidValue;
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), bidAmount, domains.length);
        expect(transactionRes.transactions).not.toHaveTransaction({ exitCode(x) {return x != 0} });

        // Calculate expected commission
        const expectedCommission = min(
            bidAmount * BigInt(tonMultipleAuctionConfig.commissionFactor) / 10000n,
            tonMultipleAuctionConfig.maxCommission
        );

        // Verify final balances
        console.log(await buyer.getBalance(), initialBuyerBalance - bidAmount, (await buyer.getBalance() - (initialBuyerBalance - bidAmount)));
        expect(abs(await buyer.getBalance() - (initialBuyerBalance - bidAmount))).toBeLessThan(toNano('0.05'));
        expect(await seller.getBalance()).toBeGreaterThan(
            initialSellerBalance + bidAmount - expectedCommission - toNano('0.1')
        );
        expect(await marketplace.getBalance()).toBeGreaterThan(
            initialMarketplaceBalance + expectedCommission - toNano('0.01')
        );

        // Verify auction state
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.state).toEqual(TonMultipleAuction.STATE_COMPLETED);
    });

    it('should run deferred auction', async () => {
        tonMultipleAuctionConfig.isDeferred = true;
        let auctionDuration = tonMultipleAuctionConfig.endTime - tonMultipleAuctionConfig.startTime;
        tonMultipleAuctionConfig.startTime = blockchain.now! + 360 * 24 * 60 * 60;
        tonMultipleAuctionConfig.endTime = tonMultipleAuctionConfig.startTime + auctionDuration;
        await deployAuction();
        await sendDomainsToAuction();

        blockchain.now! += 350 * 24 * 60 * 60;
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.isDeferred).toEqual(true);
        
        transactionRes = await tonMultipleAuction.sendPlaceBid(buyer.getSender(), tonMultipleAuctionConfig.minBidValue, domains.length);
        tonMultipleAuctionConfig = await tonMultipleAuction.getStorageData();
        expect(tonMultipleAuctionConfig.isDeferred).toEqual(false);
        expect(tonMultipleAuctionConfig.startTime).toEqual(blockchain.now!);
        expect(tonMultipleAuctionConfig.endTime).toEqual(blockchain.now! + auctionDuration);
    });

});

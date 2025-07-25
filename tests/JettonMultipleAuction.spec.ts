import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { JettonMultipleAuction, JettonMultipleAuctionConfig } from '../wrappers/JettonMultipleAuction';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR, OpCodes, Tons } from '../wrappers/helpers/constants';
import { abs, min, max } from './helpers/common';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';

describe('JettonMultipleAuction', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;
    let jettonMultipleAuctionCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');
        jettonMultipleAuctionCode = await compile('JettonMultipleAuction');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let jettonMultipleAuction: SandboxContract<JettonMultipleAuction>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtAdminWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtAuctionWallet: SandboxContract<JettonWallet>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton"];
    let domainConfigs: Array<DomainConfig>;
    let transactionRes: SendMessageResult;

    let jettonMultipleAuctionConfig: JettonMultipleAuctionConfig;

    async function deployAuction() {
        jettonMultipleAuctionConfig.jettonWalletAddress = undefined;
        jettonMultipleAuctionConfig.state = JettonMultipleAuction.STATE_UNINIT;
        jettonMultipleAuction = blockchain.openContract(
            JettonMultipleAuction.createFromConfig(jettonMultipleAuctionConfig, jettonMultipleAuctionCode)
        );

        transactionRes = await jettonMultipleAuction.sendDeploy(marketplace.getSender(), jettonMultipleAuctionConfig.tonsToEndAuction);
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: jettonMultipleAuction.address,
            deploy: true,
            success: true
        });

        usdtAuctionWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(jettonMultipleAuction.address)));
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.state).toEqual(JettonMultipleAuction.STATE_ACTIVE);
        expect(usdtAuctionWallet.address.toString()).toEqual(jettonMultipleAuctionConfig.jettonWalletAddress!!.toString());
    }

    async function sendDomainsToAuction() {
        for (let domain of domains) {
            transactionRes = await domain.sendTransfer(seller.getSender(), jettonMultipleAuction.address, seller.address, null, toNano('0.01'));
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

        // Deploy USDT contracts
        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({
            admin: admin.address, 
            content: beginCell().storeStringTail("usdt").endCell(), 
            wallet_code: jettonWalletCode
        }, jettonMinterCode));
        
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.21"), toNano("0.5"));
        await usdtMinter.sendMint(admin.getSender(), admin.address, toNano(100), toNano("0.21"), toNano("0.5"));
        
        usdtAdminWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtBuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));

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
            const domainAddress = transactionRes.transactions[2].inMessage!!.info.dest!! as Address;
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            
            blockchain.now! += 60 * 60 + 1;  // end of the auction
            transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
            
            domains.push(domain);
            domainsDict.set(domainAddress, 0);
        }

        // Configure and deploy auction contract
        jettonMultipleAuctionConfig = {
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
            state: JettonMultipleAuction.STATE_UNINIT,
            startTime: blockchain.now! + 60,
            endTime: blockchain.now! + ONE_DAY * 120,
            lastDomainRenewalTime: blockchain.now!,
            lastBidValue: 0n,
            lastBidTime: blockchain.now!,
            lastBidderAddress: null,
            jettonMinterAddress: usdtMinter.address,
            tonsToEndAuction: JettonMultipleAuction.getTonsToEndAuction(domains.length),
            isDeferred: false
        };
        
        await deployAuction();
    });

    it('should accept bids and extend time', async () => {
        await sendDomainsToAuction();

        // Try bid before start time - should fail
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(), 
            jettonMultipleAuctionConfig.minBidValue, 
            jettonMultipleAuction.address, 
            buyer.address, 
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(
                jettonMultipleAuctionConfig.minBidValue,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.DEAL_NOT_ACTIVE}`).endCell()
            )
        });

        // Move to start time
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Place minimum bid
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(), 
            jettonMultipleAuctionConfig.minBidValue, 
            jettonMultipleAuction.address, 
            buyer.address, 
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonMultipleAuction.address,
            to: buyer.address,
            body: beginCell().storeUint(0, 32).storeStringTail("Bid placed successfully").endCell()
        });

        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.lastBidValue).toEqual(jettonMultipleAuctionConfig.minBidValue);
        expect(jettonMultipleAuctionConfig.lastBidderAddress?.toString()).toEqual(buyer.address.toString());

        // Place higher bid
        const newBid = jettonMultipleAuctionConfig.minBidValue * 2n;
        blockchain.now = jettonMultipleAuctionConfig.endTime - 60;  // Just before end
        
        transactionRes = await usdtAdminWallet.sendTransfer(
            admin.getSender(), 
            newBid, 
            jettonMultipleAuction.address, 
            admin.address, 
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Check outbid notification
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(
                jettonMultipleAuctionConfig.minBidValue,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail("Your bid was outbid by another user").endCell()
            )
        });

        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.lastBidValue).toEqual(newBid);
        expect(jettonMultipleAuctionConfig.endTime).toEqual(blockchain.now + jettonMultipleAuctionConfig.timeIncrement);
    });

    it('should end auction when max bid is reached', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Place max bid
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.maxBidValue + 1n,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length) + Tons.JETTON_TRANSFER
        );

        // Check commission payment
        const commission = min(
            jettonMultipleAuctionConfig.maxBidValue * BigInt(jettonMultipleAuctionConfig.commissionFactor) / 10000n,
            jettonMultipleAuctionConfig.maxCommission
        );

        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(
                commission,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail("Marketplace commission").endCell()
            )
        });

        // Check seller payment
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(
                jettonMultipleAuctionConfig.maxBidValue - commission,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail("Payout for multiple domains auction on webdom.market").endCell()
            )
        });

        // Check excess return
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(
                1n,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail("Excesses").endCell()
            )
        });

        // Verify domains transferred to buyer
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.ownerAddress?.toString()).toEqual(buyer.address.toString());
        }

        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.state).toEqual(JettonMultipleAuction.STATE_COMPLETED);
    });

    it('should handle domain renewal', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;
        
        transactionRes = await jettonMultipleAuction.sendRenewDomain(seller.getSender(), domains.length);
        
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.lastDomainRenewalTime).toEqual(blockchain.now);

        // Verify domains were renewed
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.lastRenewalTime).toEqual(blockchain.now);
        }
    });

    it('should allow auction cancellation if no bids placed', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime + 60;
        
        transactionRes = await jettonMultipleAuction.sendStopAuction(seller.getSender());
        
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.state).toEqual(JettonMultipleAuction.STATE_CANCELLED);

        // Verify domains returned to seller
        for (let domain of domains) {
            const config = await domain.getStorageData();
            expect(config.ownerAddress?.toString()).toEqual(seller.address.toString());
        }
    });

    it('should verify balances after successful auction completion', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        const initialBuyerJettonBalance = await usdtBuyerWallet.getJettonBalance();
        const initialSellerJettonBalance = await usdtSellerWallet.getJettonBalance();
        const initialMarketplaceJettonBalance = await usdtAdminWallet.getJettonBalance();

        // Place winning bid
        const bidAmount = jettonMultipleAuctionConfig.maxBidValue;
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            bidAmount,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Calculate expected commission
        const expectedCommission = min(
            bidAmount * BigInt(jettonMultipleAuctionConfig.commissionFactor) / 10000n,
            jettonMultipleAuctionConfig.maxCommission
        );

        // Verify final balances
        expect(await usdtBuyerWallet.getJettonBalance()).toEqual(initialBuyerJettonBalance - bidAmount);
        expect(await usdtSellerWallet.getJettonBalance()).toEqual(
            initialSellerJettonBalance + bidAmount - expectedCommission
        );
        expect(await usdtAdminWallet.getJettonBalance()).toEqual(
            initialMarketplaceJettonBalance + expectedCommission
        );

        // Verify auction state
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.state).toEqual(JettonMultipleAuction.STATE_COMPLETED);
    });

    it('should handle failed bid attempts with insufficient gas', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Try bid with insufficient gas
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.minBidValue,
            jettonMultipleAuction.address,
            buyer.address,
            toNano('0.06') // insufficient gas
        );

        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(
                jettonMultipleAuctionConfig.minBidValue,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.OUT_OF_GAS}`).endCell()
            )
        });

        // Verify auction state remains unchanged
        const config = await jettonMultipleAuction.getStorageData();
        expect(config.lastBidValue).toEqual(0n);
        expect(config.lastBidderAddress).toEqual(null);
    });

    it('should handle multiple consecutive bids correctly', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        const initialBuyerBalance = await usdtBuyerWallet.getJettonBalance();
        const initialAdminBalance = await usdtAdminWallet.getJettonBalance();

        // First bid
        const firstBid = jettonMultipleAuctionConfig.minBidValue;
        await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            firstBid,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Second bid
        const secondBid = firstBid * 2n;
        await usdtAdminWallet.sendTransfer(
            admin.getSender(),
            secondBid,
            jettonMultipleAuction.address,
            admin.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Third bid
        const thirdBid = secondBid * 2n;
        transactionRes = await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            thirdBid,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Verify outbid notifications and refunds
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(
                secondBid,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail("Your bid was outbid by another user").endCell()
            )
        });

        // Verify final state
        const config = await jettonMultipleAuction.getStorageData();
        expect(config.lastBidValue).toEqual(thirdBid);
        expect(config.lastBidderAddress?.toString()).toEqual(buyer.address.toString());
    });

    it('should handle bid below minimum increment correctly', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Place initial bid
        await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.minBidValue,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Try to place bid with insufficient increment
        const smallIncrementBid = jettonMultipleAuctionConfig.minBidValue + 1n;
        transactionRes = await usdtAdminWallet.sendTransfer(
            admin.getSender(),
            smallIncrementBid,
            jettonMultipleAuction.address,
            admin.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Verify bid rejection
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(
                smallIncrementBid,
                jettonMultipleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.BID_TOO_LOW}`).endCell()
            )
        });
    });

    it('should handle auction end time extension correctly', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Place initial bid
        await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.minBidValue,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Place bid near end time
        blockchain.now = jettonMultipleAuctionConfig.endTime - 30; // 30 seconds before end
        const newBid = jettonMultipleAuctionConfig.minBidValue * 2n;
        await usdtAdminWallet.sendTransfer(
            admin.getSender(),
            newBid,
            jettonMultipleAuction.address,
            admin.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Verify time extension
        const config = await jettonMultipleAuction.getStorageData();
        expect(config.endTime).toEqual(blockchain.now + config.timeIncrement);
    });

    it('should handle domain renewal with expiration check', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Try to renew too early
        transactionRes = await jettonMultipleAuction.sendRenewDomain(
            seller.getSender(),
            domains.length
        );

        // Move time close to expiration
        blockchain.now = jettonMultipleAuctionConfig.lastDomainRenewalTime + ONE_YEAR - ONE_DAY * 2;

        // Renew domains
        transactionRes = await jettonMultipleAuction.sendRenewDomain(
            seller.getSender(),
            domains.length
        );

        // Verify renewal
        const config = await jettonMultipleAuction.getStorageData();
        expect(config.lastDomainRenewalTime).toEqual(blockchain.now);

        // Verify each domain's renewal time
        for (let domain of domains) {
            const domainConfig = await domain.getStorageData();
            expect(domainConfig.lastRenewalTime).toEqual(blockchain.now);
        }
    });

    it('should handle failed auction cancellation attempts', async () => {
        await sendDomainsToAuction();
        blockchain.now = jettonMultipleAuctionConfig.startTime;

        // Place a valid bid
        await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.minBidValue,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );

        // Try to cancel auction with active bid
        transactionRes = await jettonMultipleAuction.sendStopAuction(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: jettonMultipleAuction.address,
            exitCode: Exceptions.AUCTION_NOT_ENDED
        });
        
        blockchain.now = jettonMultipleAuctionConfig.endTime;
        // Try to cancel auction from non-seller address
        transactionRes = await jettonMultipleAuction.sendStopAuction(admin.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: jettonMultipleAuction.address,
            exitCode: Exceptions.INCORRECT_SENDER
        });

        // Verify auction state remains unchanged
        const config = await jettonMultipleAuction.getStorageData();
        expect(config.state).toEqual(JettonMultipleAuction.STATE_ACTIVE);
    });

    it('should handle deferred auction completion', async () => {
        jettonMultipleAuctionConfig.isDeferred = true;
        let auctionDuration = jettonMultipleAuctionConfig.endTime - jettonMultipleAuctionConfig.startTime;
        jettonMultipleAuctionConfig.startTime = blockchain.now!! + 360 * 24 * 60 * 60;
        jettonMultipleAuctionConfig.endTime = jettonMultipleAuctionConfig.startTime + auctionDuration;
        await deployAuction();
        await sendDomainsToAuction();

        blockchain.now!! += 350 * 24 * 60 * 60;
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.isDeferred).toEqual(true);
        
        // Place initial bid
        await usdtBuyerWallet.sendTransfer(
            buyer.getSender(),
            jettonMultipleAuctionConfig.minBidValue,
            jettonMultipleAuction.address,
            buyer.address,
            JettonMultipleAuction.getTonsToEndAuction(domains.length)
        );
        blockchain.now!! += auctionDuration;
        transactionRes = await jettonMultipleAuction.sendExternalCancel();
        jettonMultipleAuctionConfig = await jettonMultipleAuction.getStorageData();
        expect(jettonMultipleAuctionConfig.isDeferred).toEqual(false);
        expect(jettonMultipleAuctionConfig.state).toEqual(JettonMultipleAuction.STATE_COMPLETED);

    });
        
    // it('should handle auction completion with maximum commission', async () => {
    //     await sendDomainsToAuction();
    //     blockchain.now = jettonMultipleAuctionConfig.startTime;

    //     // Place a large bid that would exceed max commission
    //     const largeBid = toNano('100');
    //     transactionRes = await usdtBuyerWallet.sendTransfer(
    //         buyer.getSender(),
    //         largeBid,
    //         jettonMultipleAuction.address,
    //         buyer.address,
    //         JettonMultipleAuction.getTonsToEndAuction(domains.length)
    //     );

    //     // End auction
    //     blockchain.now = jettonMultipleAuctionConfig.endTime;
    //     transactionRes = await jettonMultipleAuction.sendStopAuction(seller.getSender());

    //     // Verify commission is capped at max commission
    //     expect(transactionRes.transactions).toHaveTransaction({
    //         from: usdtAdminWallet.address,
    //         to: admin.address,
    //         body: JettonWallet.transferNotificationMessage(
    //             jettonMultipleAuctionConfig.maxCommission,
    //             jettonMultipleAuction.address,
    //             beginCell().storeUint(0, 32).storeStringTail("Marketplace commission").endCell()
    //         )
    //     });
    // });
});

import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { JettonSimpleAuction, JettonSimpleAuctionConfig } from '../wrappers/JettonSimpleAuction';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DomainConfig } from '../wrappers/Domain';
import { Domain } from '../wrappers/Domain';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { domainToNotification, TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import { Exceptions, MIN_PRICE_START_TIME, ONE_TON, OpCodes, Tons } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';


describe('JettonSimpleAuction', () => {
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;

    let jettonSimpleAuctionCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');

        jettonSimpleAuctionCode = await compile('JettonSimpleAuction');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let jettonSimpleAuction: SandboxContract<JettonSimpleAuction>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtAdminWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtAuctionWallet: SandboxContract<JettonWallet>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let jettonSimpleAuctionConfig: JettonSimpleAuctionConfig;

    async function deployJettonSimpleAuction() {
        jettonSimpleAuctionConfig.jettonWalletAddress = undefined;
        jettonSimpleAuctionConfig.state = JettonSimpleAuction.STATE_UNINIT;

        jettonSimpleAuction = blockchain.openContract(JettonSimpleAuction.createFromConfig(jettonSimpleAuctionConfig, jettonSimpleAuctionCode));
        usdtAuctionWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(jettonSimpleAuction.address)));
        
        transactionRes = await jettonSimpleAuction.sendDeploy(marketplace.getSender(), toNano('0.04'), beginCell().storeAddress(usdtAuctionWallet.address).endCell());
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: jettonSimpleAuction.address,
            deploy: true,
            success: true
        });

        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_ACTIVE);
        expect(usdtAuctionWallet.address.toString()).toEqual(jettonSimpleAuctionConfig.jettonWalletAddress!.toString());

        await domain.sendTransfer(seller.getSender(), jettonSimpleAuction.address, seller.address);
    }
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;

        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');
        
        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.21"), toNano("0.5"));
        await usdtMinter.sendMint(admin.getSender(), admin.address, toNano(100), toNano("0.21"), toNano("0.5"));
        usdtAdminWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtBuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));

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

        transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), DOMAIN_NAME);
        const domainAddress = transactionRes.transactions[2].inMessage!!.info.dest!! as Address; 
        expect(transactionRes.transactions).toHaveTransaction({
            from: dnsCollection.address,
            to: domainAddress,
            deploy: true,
            success: true
        })
        domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
        
        blockchain.now += 60 * 60 + 1;  // end of the auction
        transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
        
        jettonSimpleAuctionConfig = {
            domainAddress,
            sellerAddress: seller.address,
            jettonMinterAddress: usdtMinter.address,
            jettonWalletAddress: null,
            minBidValue: toNano('1'),
            maxBidValue: toNano('10'),
            minBidIncrement: 1050,
            timeIncrement: 60 * 5,  // 5 minutes
            commissionFactor: 500,  // 5%

            state: JettonSimpleAuction.STATE_UNINIT,
            startTime: blockchain.now + 10,
            endTime: blockchain.now + 60 * 15,  // 15 minutes
            lastDomainRenewalTime: blockchain.now,
            lastBidValue: toNano('0'),
            lastBidTime: blockchain.now,
            lastBidderAddress: null,
            domainName: DOMAIN_NAME,
            maxCommission: toNano("999"),
            isDeferred: false,
        }
        await deployJettonSimpleAuction();
    });

    it('should sell the domain after auction end time', async () => {        
        // bid before auction start time rejected

        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleAuctionConfig.minBidValue, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleAuctionConfig.minBidValue, jettonSimpleAuction.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.DEAL_NOT_ACTIVE}`).endCell()),
        })
        
        // minimum bid - 1 rejected
        blockchain.now!! += 10;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleAuctionConfig.minBidValue - 1n, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleAuctionConfig.minBidValue - 1n, jettonSimpleAuction.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.BID_TOO_LOW}`).endCell()),
        });

        // minimum bid accepted
        let bid = toNano('1');
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        let notificationMsg = beginCell().storeUint(0, 32).storeStringTail(`Bid placed successfully`).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonSimpleAuction.address,
            to: buyer.address,
            body: notificationMsg
        });
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(jettonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(jettonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());

        // minimum increased - 1 bid rejected
        blockchain.now!! += 60 * 5;
        bid = (bid * BigInt(jettonSimpleAuctionConfig.minBidIncrement)) / BigInt(1000);
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid - 1n, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(bid - 1n, jettonSimpleAuction.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.BID_TOO_LOW}`).endCell()),
        });

        // minimum increased bid accepted
        blockchain.now!! += 60 * 5;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonSimpleAuction.address,
            to: buyer.address,
            body: notificationMsg
        });
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(jettonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(jettonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(jettonSimpleAuctionConfig.endTime).toEqual(blockchain.now!! + jettonSimpleAuctionConfig.timeIncrement);
        
        // bid accepted (+ outbid notification message)
        let prevBid = bid;
        bid = toNano('5');
        transactionRes = await usdtAdminWallet.sendTransfer(admin.getSender(), bid, jettonSimpleAuction.address, admin.address, toNano("0.21"));
        const outbidMsg = beginCell().storeUint(0, 32).storeStringTail(`Your bid on webdom.market was outbid by another user. Domain: `).storeRef(beginCell().storeStringTail(DOMAIN_NAME).endCell()).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonSimpleAuction.address,
            to: admin.address,
            body: notificationMsg
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(prevBid, jettonSimpleAuction.address, outbidMsg)
        });
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(jettonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(admin.address.toString());

        // minimum increased - 1 bid rejected
        prevBid = bid;
        bid = (bid * BigInt(jettonSimpleAuctionConfig.minBidIncrement)) / BigInt(1000);
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid - 1n, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(bid - 1n, jettonSimpleAuction.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.BID_TOO_LOW}`).endCell()),
        });

        // minimum increased bid accepted
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonSimpleAuction.address,
            to: buyer.address,
            body: notificationMsg
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,  // admin wallet
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(prevBid, jettonSimpleAuction.address, outbidMsg)
        });
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(jettonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(jettonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(jettonSimpleAuctionConfig.endTime).toEqual(blockchain.now!! + jettonSimpleAuctionConfig.timeIncrement);
        
        // reject cancelling auction
        transactionRes = await jettonSimpleAuction.sendStopAuction(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: jettonSimpleAuction.address,
            exitCode: Exceptions.AUCTION_NOT_ENDED
        });

        // bid after auction end time rejected
        blockchain.now!! = jettonSimpleAuctionConfig.endTime;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), jettonSimpleAuctionConfig.maxBidValue + 1n, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleAuctionConfig.maxBidValue + 1n, jettonSimpleAuction.address,
                 beginCell().storeUint(0, 32).storeStringTail(`Error. Code ${Exceptions.DEAL_NOT_ACTIVE}`).endCell()),
        });

        // stop auction message accepted
        transactionRes = await jettonSimpleAuction.sendStopAuction(seller.getSender());
        const commission = jettonSimpleAuctionConfig.lastBidValue * BigInt(jettonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleAuctionConfig.lastBidValue - commission, jettonSimpleAuction.address, 
                domainToNotification(DOMAIN_NAME)
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(commission, jettonSimpleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
            ),
        })
        expect((await blockchain.getContract(jettonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_COMPLETED);
        
    });

    it('should sell the domain after max bid value', async () => {
        blockchain.now!! = jettonSimpleAuctionConfig.startTime;
        let bid = toNano('5');
        transactionRes = await usdtAdminWallet.sendTransfer(admin.getSender(), bid, jettonSimpleAuction.address, admin.address, toNano("0.21"));

        let prevBid = bid;
        bid = jettonSimpleAuctionConfig.maxBidValue + 100n;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.25"));
        const outbidMsg = beginCell().storeUint(0, 32).storeStringTail(`Your bid on webdom.market was outbid by another user. Domain: `).storeRef(beginCell().storeStringTail(DOMAIN_NAME).endCell()).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(prevBid, jettonSimpleAuction.address, outbidMsg)
        });
        const commission = jettonSimpleAuctionConfig.maxBidValue * BigInt(jettonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(jettonSimpleAuctionConfig.maxBidValue - commission, jettonSimpleAuction.address, 
                domainToNotification(DOMAIN_NAME)
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(commission, jettonSimpleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtBuyerWallet.address,
            to: buyer.address,
            body: JettonWallet.transferNotificationMessage(100n, jettonSimpleAuction.address, 
                beginCell().storeUint(0, 32).storeStringTail(`Excesses`).endCell()
            )
        });
        expect((await blockchain.getContract(jettonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastBidValue).toEqual(jettonSimpleAuctionConfig.maxBidValue);
        expect(jettonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(jettonSimpleAuctionConfig.endTime).toEqual(blockchain.now!!);
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_COMPLETED);
    });

    it('should trigger auction finish by external (success)', async () => {
        blockchain.now!! = jettonSimpleAuctionConfig.startTime;
        let bid = toNano('5');
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        blockchain.now!! = jettonSimpleAuctionConfig.endTime;
        
        transactionRes = await jettonSimpleAuction.sendExternalCancel();
        const commission = bid * BigInt(jettonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtSellerWallet.address,
            to: seller.address,
            body: JettonWallet.transferNotificationMessage(bid - commission, jettonSimpleAuction.address, 
                domainToNotification(DOMAIN_NAME)
            ),
        })
        expect(transactionRes.transactions).toHaveTransaction({
            from: usdtAdminWallet.address,
            to: admin.address,
            body: JettonWallet.transferNotificationMessage(commission, jettonSimpleAuction.address,
                beginCell().storeUint(0, 32).storeStringTail(`Marketplace commission`).endCell()
            ),
        })
        expect((await blockchain.getContract(jettonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_COMPLETED);
    });

    it('should trigger auction finish by external (no bids)', async () => {
        blockchain.now!! = jettonSimpleAuctionConfig.endTime;
        transactionRes = await jettonSimpleAuction.sendExternalCancel();
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(seller.address.toString());
    });

    it('should cancel auction', async () => {
        blockchain.now!! = jettonSimpleAuctionConfig.startTime + 40;
        transactionRes = await jettonSimpleAuction.sendStopAuction(seller.getSender());
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(seller.address.toString());
    });

    it('should renew domain', async () => {
        blockchain.now!! = jettonSimpleAuctionConfig.startTime;
        transactionRes = await jettonSimpleAuction.sendRenewDomain(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: jettonSimpleAuction.address,
            to: seller.address,
            op: OpCodes.EXCESSES
        });
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.lastDomainRenewalTime).toEqual(blockchain.now!!);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!!);
    });

    it('should run deferred auction', async () => {
        jettonSimpleAuctionConfig.isDeferred = true;
        let auctionDuration = jettonSimpleAuctionConfig.endTime - jettonSimpleAuctionConfig.startTime;
        jettonSimpleAuctionConfig.startTime = blockchain.now!! + 360 * 24 * 60 * 60;
        jettonSimpleAuctionConfig.endTime = jettonSimpleAuctionConfig.startTime + auctionDuration;
        await deployJettonSimpleAuction();

        blockchain.now!! += 350 * 24 * 60 * 60;
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.isDeferred).toEqual(true);
        
        let bid = toNano('5');
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), bid, jettonSimpleAuction.address, buyer.address, toNano("0.21"));
        blockchain.now!! += auctionDuration;
        transactionRes = await jettonSimpleAuction.sendExternalCancel();
        
        jettonSimpleAuctionConfig = await jettonSimpleAuction.getStorageData();
        expect(jettonSimpleAuctionConfig.isDeferred).toEqual(false);
        expect(jettonSimpleAuctionConfig.state).toEqual(JettonSimpleAuction.STATE_COMPLETED);
    });
});

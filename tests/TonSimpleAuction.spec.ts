import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { TonSimpleAuction, TonSimpleAuctionConfig } from '../wrappers/TonSimpleAuction';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DomainConfig } from '../wrappers/Domain';
import { Domain } from '../wrappers/Domain';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import { Exceptions, MIN_PRICE_START_TIME, ONE_TON, OpCodes, Tons } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';

describe('TonSimpleAuction', () => {
    let tonSimpleAuctionCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        tonSimpleAuctionCode = await compile('TonSimpleAuction');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let tonSimpleAuction: SandboxContract<TonSimpleAuction>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let tonSimpleAuctionConfig: TonSimpleAuctionConfig;

    async function deployTonSimpleAuction() {
        tonSimpleAuction = blockchain.openContract(TonSimpleAuction.createFromConfig(tonSimpleAuctionConfig, tonSimpleAuctionCode));
        transactionRes = await tonSimpleAuction.sendDeploy(marketplace.getSender(), toNano('0.03'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: marketplace.address,
            to: tonSimpleAuction.address,
            deploy: true,
            success: true
        });

        await domain.sendTransfer(seller.getSender(), tonSimpleAuction.address, seller.address);
    }

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;

        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');
        
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
        
        tonSimpleAuctionConfig = {
            domainAddress,
            sellerAddress: seller.address,
            minBidValue: toNano('1'),
            maxBidValue: toNano('10'),
            minBidIncrement: 1050,
            timeIncrement: 60 * 5,  // 5 minutes
            commissionFactor: 500,  // 5%

            state: TonSimpleAuction.STATE_UNINIT,
            startTime: blockchain.now + 10,
            endTime: blockchain.now + 10 + 60 * 15,  // 15 minutes
            lastDomainRenewalTime: blockchain.now,
            lastBidValue: toNano('0'),
            lastBidTime: blockchain.now,
            lastBidderAddress: null,
            domainName: DOMAIN_NAME,
            isDeferred: false,
            maxCommission: toNano("999"),
        }
        await deployTonSimpleAuction();
    });

    it('should sell the domain after auction end time', async () => {
        // console.log(`Admin address: ${admin.address}\nSeller address: ${seller.address}\nBuyer address: ${buyer.address}\nAuction address: ${tonSimpleAuction.address}\n`);
        
        // bid before auction start time rejected
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), tonSimpleAuctionConfig.minBidValue);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });
        
        // minimum bid - 1rejected
        blockchain.now!! += 10;
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), tonSimpleAuctionConfig.minBidValue - 1n);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // minimum bid accepted
        let bid = toNano('1');
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid);
        let notificationMsg = beginCell().storeUint(0, 32).storeStringTail(`${jettonsToString(Number(bid), 9)} TON bid placed successfully`).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: buyer.address,
            body: notificationMsg
        });
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(tonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(tonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());

        // minimum increased - 1 bid rejected
        blockchain.now!! += 60 * 5;
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), (bid * BigInt(tonSimpleAuctionConfig.minBidIncrement)) / BigInt(1000));
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // minimum increased bid accepted
        blockchain.now!! += 60 * 5;
        bid += Tons.MIN_BID_INCREMENT;
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            success: true
        });
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(tonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(tonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(tonSimpleAuctionConfig.endTime).toEqual(blockchain.now!! + tonSimpleAuctionConfig.timeIncrement);
        
        // bid accepted (+ outbid notification message)
        bid = toNano('5');
        transactionRes = await tonSimpleAuction.sendPlaceBid(admin.getSender(), bid);
        notificationMsg = beginCell().storeUint(0, 32).storeStringTail(`${jettonsToString(Number(bid), 9)} TON bid placed successfully`).endCell();
        const outbidMsg = beginCell().storeUint(0, 32).storeStringTail(`Your bid on ${tonSimpleAuctionConfig.domainName} was outbid by another user on webdom.market`).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: admin.address,
            body: notificationMsg
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: buyer.address,
            body: outbidMsg
        });
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(tonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(admin.address.toString());

        // minimum increased - 1 bid rejected
        bid = (bid * BigInt(tonSimpleAuctionConfig.minBidIncrement)) / BigInt(1000);
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid - 1n);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.BID_TOO_LOW
        });

        // minimum increased bid accepted
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            success: true
        });
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(tonSimpleAuctionConfig.lastBidTime).toEqual(blockchain.now);
        expect(tonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(tonSimpleAuctionConfig.endTime).toEqual(blockchain.now!! + tonSimpleAuctionConfig.timeIncrement);
        
        // reject cancelling auction
        transactionRes = await tonSimpleAuction.sendStopAuction(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: seller.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.AUCTION_NOT_ENDED
        });

        // bid after auction end time rejected
        blockchain.now!! = tonSimpleAuctionConfig.endTime;
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), tonSimpleAuctionConfig.maxBidValue + 1n);
        expect(transactionRes.transactions).toHaveTransaction({
            from: buyer.address,
            to: tonSimpleAuction.address,
            exitCode: Exceptions.DEAL_NOT_ACTIVE
        });

        // stop auction message accepted
        transactionRes = await tonSimpleAuction.sendStopAuction(seller.getSender());
        const commission = tonSimpleAuctionConfig.lastBidValue * BigInt(tonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: marketplace.address,
            value(x) {
                return x!! > commission - toNano('0.005');
            },
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: seller.address,
            value(x) {
                return x!! > tonSimpleAuctionConfig.lastBidValue -commission - toNano('0.005');
            },
        });
        expect((await blockchain.getContract(tonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.state).toEqual(TonSimpleAuction.STATE_COMPLETED);
        
    });

    it('should sell the domain after max bid value', async () => {
        blockchain.now!! = tonSimpleAuctionConfig.startTime;
        let bid = toNano('5');
        transactionRes = await tonSimpleAuction.sendPlaceBid(admin.getSender(), bid);

        bid = tonSimpleAuctionConfig.maxBidValue;
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid);
        const outbidMsg = beginCell().storeUint(0, 32).storeStringTail(`Your bid on ${tonSimpleAuctionConfig.domainName} was outbid by another user on webdom.market`).endCell();
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: admin.address,
            body: outbidMsg
        });
        const commission = tonSimpleAuctionConfig.lastBidValue * BigInt(tonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: marketplace.address,
            value(x) {
                return x!! > commission - toNano('0.005');
            },
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: seller.address,
            value(x) {
                return x!! > tonSimpleAuctionConfig.lastBidValue -commission - toNano('0.005');
            },
        });
        expect((await blockchain.getContract(tonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastBidValue).toEqual(bid);
        expect(tonSimpleAuctionConfig.lastBidderAddress!!.toString()).toEqual(buyer.address.toString());
        expect(tonSimpleAuctionConfig.endTime).toEqual(blockchain.now!!);
        expect(tonSimpleAuctionConfig.state).toEqual(TonSimpleAuction.STATE_COMPLETED);
    });

    it('should trigger auction finish by external (success)', async () => {
        blockchain.now!! = tonSimpleAuctionConfig.startTime;
        let bid = toNano('5');
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), bid);
        blockchain.now!! = tonSimpleAuctionConfig.endTime;

        transactionRes = await tonSimpleAuction.sendExternalCancel();
        const commission = tonSimpleAuctionConfig.lastBidValue * BigInt(tonSimpleAuctionConfig.commissionFactor) / 10000n;
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: marketplace.address,
            value(x) {
                return x!! > commission - toNano('0.005');
            },
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: seller.address,
            value(x) {
                return x!! > tonSimpleAuctionConfig.lastBidValue -commission - toNano('0.005');
            },
        });
        expect((await blockchain.getContract(tonSimpleAuction.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(buyer.address.toString());
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.state).toEqual(TonSimpleAuction.STATE_COMPLETED);
    });

    it('should trigger auction finish by external (no bids)', async () => {
        blockchain.now!! = tonSimpleAuctionConfig.endTime;
        transactionRes = await tonSimpleAuction.sendExternalCancel();
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.state).toEqual(TonSimpleAuction.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(seller.address.toString());
    });

    it('should cancel auction', async () => {
        blockchain.now!! = tonSimpleAuctionConfig.startTime + 40;
        transactionRes = await tonSimpleAuction.sendStopAuction(seller.getSender());
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.state).toEqual(TonSimpleAuction.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!!.toString()).toEqual(seller.address.toString());
    });

    it('should renew domain', async () => {
        blockchain.now!! = tonSimpleAuctionConfig.startTime;
        transactionRes = await tonSimpleAuction.sendRenewDomain(seller.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: tonSimpleAuction.address,
            to: seller.address,
            op: OpCodes.EXCESSES
        });
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.lastDomainRenewalTime).toEqual(blockchain.now!!);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.lastRenewalTime).toEqual(blockchain.now!!);
    });

    it('should run deferred auction', async () => {
        tonSimpleAuctionConfig.isDeferred = true;
        let auctionDuration = tonSimpleAuctionConfig.endTime - tonSimpleAuctionConfig.startTime;
        tonSimpleAuctionConfig.startTime = blockchain.now!! + 360 * 24 * 60 * 60;
        tonSimpleAuctionConfig.endTime = tonSimpleAuctionConfig.startTime + auctionDuration;
        await deployTonSimpleAuction();

        blockchain.now!! += 350 * 24 * 60 * 60;
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.isDeferred).toEqual(true);
        
        transactionRes = await tonSimpleAuction.sendPlaceBid(buyer.getSender(), tonSimpleAuctionConfig.minBidValue);
        tonSimpleAuctionConfig = await tonSimpleAuction.getStorageData();
        expect(tonSimpleAuctionConfig.isDeferred).toEqual(false);
        expect(tonSimpleAuctionConfig.startTime).toEqual(blockchain.now!!);
        expect(tonSimpleAuctionConfig.endTime).toEqual(blockchain.now!! + auctionDuration);
    });
});

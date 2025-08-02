import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { TonSimpleOffer, TonSimpleOfferConfig } from '../wrappers/TonSimpleOffer';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, OpCodes, Tons } from '../wrappers/helpers/constants';

describe('TonSimpleOffer', () => {
    let offerCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        offerCode = await compile('TonSimpleOffer');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;

    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let offer: SandboxContract<TonSimpleOffer>;

    let offerConfig: TonSimpleOfferConfig;

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
        transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), DOMAIN_NAME);
        const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
        domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
        blockchain.now += 60 * 60 + 1;  // end of the auction
        transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);

        offerConfig = {
            domainAddress,
            price: toNano('2'),
            state: TonSimpleOffer.STATE_NOT_INITIALIZED,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: buyer.address,
            sellerAddress: seller.address,
            domainName: DOMAIN_NAME,
            sellerPrice: 0n
        }
        offer = blockchain.openContract(TonSimpleOffer.createFromConfig(offerConfig, offerCode));
        transactionRes = await offer.sendDeploy(admin.getSender(), offerConfig.price + offerConfig.commission + toNano('0.085'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: offer.address,
            success: true,
            deploy: true,
        });

    });

    it('should accept domain', async () => {
        // console.log(`Seller address: ${seller.address}\nBuyer address: ${buyer.address}\nOffer address: ${offer.address}\n`);

        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, null, toNano('0.02'));
        expect(transactionRes.transactions[4].inMessage!.body.beginParse().skip(32).loadStringTail()).toEqual("Marketplace commission");
        expect(transactionRes.transactions).toHaveTransaction({
            from: offer.address,
            to: seller.address,
            success: true,
            value(x) {
                return x! > offerConfig.price;
            },
        });
        expect(transactionRes.transactions[5].inMessage!.body.beginParse().skip(32).loadStringTail()).toEqual("Offer accepted");
        expect(transactionRes.transactions).toHaveTransaction({
            from: offer.address,
            to: marketplace.address,
            success: true,
            value(x) {
                return x! > offerConfig.commission - toNano('0.001');
            },
        });
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_COMPLETED);
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        
        // should return domain if the offer is already accepted
        transactionRes = await domain.sendTransfer(buyer.getSender(), offer.address, seller.address, null, toNano('0.04'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
    });

    it('should change price', async () => {
        // with notification
        transactionRes = await offer.sendChangePrice(buyer.getSender(), offerConfig.price, offerConfig.commission, toNano('3'), blockchain.now! + ONE_DAY * 4, true);
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("New offer on webdom.market!");
        expect(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Price changed to");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('3'));
        expect(offerConfig.validUntil).toEqual(blockchain.now! + ONE_DAY * 4);
        expect(offerConfig.commission).toEqual(toNano('0.3'));

        // without notification
        blockchain.now! += ONE_DAY;
        transactionRes = await offer.sendChangePrice(buyer.getSender(), offerConfig.price, offerConfig.commission, toNano('5'), blockchain.now! + ONE_DAY * 3, false);
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Price changed to");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('5'));
        expect(offerConfig.validUntil).toEqual(blockchain.now! + ONE_DAY * 3);
        expect(offerConfig.commission).toEqual(toNano('0.5'));

        // counterpropose
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), true), toNano('0.2'));
        // expect(transactionRes.transactions).toHaveTransaction({
        //     from: offer.address,
        //     to: marketplace.address,
        //     value(x) {
        //         return x! > toNano('0.049') && x! < toNano('0.05');
        //     },
        // });
        expect(transactionRes.transactions[4].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("You have received a counterproposal for your offer on webdom.market");
        expect(transactionRes.transactions[5].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Counterproposal sent");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6'));

        // change price
        transactionRes = await offer.sendChangePrice(buyer.getSender(), offerConfig.price, offerConfig.commission, toNano('5.5'), offerConfig.validUntil, false, 0, true);
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Marketplace commission");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('5.5'));
        expect(offerConfig.commission).toEqual(toNano('0.55'));

        // counterpropose after nft transfer
        transactionRes = await offer.sendCounterpropose(seller.getSender(), toNano('6.5'), true);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6.5'));

        // accept counterproposal
        transactionRes = await offer.sendChangePrice(buyer.getSender(), offerConfig.price, offerConfig.commission, offerConfig.sellerPrice, offerConfig.validUntil, true);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(offerConfig.sellerPrice);
        expect(offerConfig.commission).toEqual(toNano('0.65'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
        
        // // reject invalid valid until
        // blockchain.now! += ONE_DAY * 3;
        // transactionRes = await offer.sendChangePrice(buyer.getSender(), offerConfig.price, offerConfig.commission, toNano('6'), blockchain.now! + 299, false);
        // expect(transactionRes.transactions).toHaveTransaction({
        //     success: false,
        //     exitCode: Exceptions.INCORRECT_VALID_UNTIL,
        // });

    });

    it("should be cancelable by the buyer after counterproposal", async () => {
        // counterpropose
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6'));

        // cancel
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        expect(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Your offer on webdom.market was cancelled");
        expect(transactionRes.transactions[4].inMessage!.body.beginParse().loadRef().beginParse().skip(32).loadStringTail()).toContain("Your counterproposal was rejected");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });

    it("should be cancelable by the seller after counterproposal", async () => {
        // counterpropose
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6'));
        
        transactionRes = await offer.sendCancelOffer(seller.getSender(), "Test comment");
        expect(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Test comment");
        expect(transactionRes.transactions[4].inMessage!.body.beginParse().loadRef().beginParse().skip(32).loadStringTail()).toContain("Your counterproposal was rejected");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });

    it('should be cancelable by the buyer', async () => {
        // reject if not enough time passed
        blockchain.now! += 300;
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            success: false,
            exitCode: Exceptions.CANT_CANCEL_DEAL,
        });

        // cancel
        blockchain.now! += 601;
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Your offer on webdom.market was cancelled");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_CANCELLED);

        // should return domain if the offer is cancelled
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, null, toNano('0.02'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });

    it('should be cancelable by the offer receiver', async () => {        
        // cancel
        transactionRes = await offer.sendCancelOffer(seller.getSender(), "Test comment");
        expect(transactionRes.transactions).toHaveTransaction({
            from: offer.address,
            to: seller.address,
            op: OpCodes.EXCESSES,
            value: toNano('0.01') + TonSimpleOffer.DECLINE_REWARD,
        });
        expect(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Test comment");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_CANCELLED);
    });

    it('should be cancelable by external message', async () => {
        // // should reject message if valid until is not over
        // transactionRes = await offer.sendExternalCancel();
        // printTransactionFees(transactionRes.transactions);
        // expect(transactionRes.transactions).toHaveTransaction({
        //     success: false,
        //     exitCode: Exceptions.DEAL_NOT_ACTIVE,
        // });

        blockchain.now! = offerConfig.validUntil! + 1;
        // should return domain if valid until is over
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, null, toNano('0.02'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());

        // cancel
        transactionRes = await offer.sendExternalCancel();
        // printTransactionFees(transactionRes.transactions);
        expect(transactionRes.transactions[1].inMessage!.body.beginParse().skip(32).loadStringTail()).toEqual("Offer expired");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(TonSimpleOffer.STATE_CANCELLED);
    });

    it('should change valid until', async () => {
        let newValidUntil = offerConfig.validUntil! + ONE_DAY * 3;
        transactionRes = await offer.sendChangeValidUntil(buyer.getSender(), newValidUntil);
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toEqual("Valid until time updated");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.validUntil).toEqual(newValidUntil)
    });
});

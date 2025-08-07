import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { JettonSimpleOffer, JettonSimpleOfferConfig } from '../wrappers/JettonSimpleOffer';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, OpCodes, Tons } from '../wrappers/helpers/constants';
import { JettonMinter } from '../wrappers/JettonMinter';
import { JettonWallet } from '../wrappers/JettonWallet';
import { TonSimpleOffer } from '../wrappers/TonSimpleOffer';

describe('JettonSimpleOffer', () => {
    let offerCode: Cell;
    let jettonWalletCode: Cell;
    let jettonMinterCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        offerCode = await compile('JettonSimpleOffer');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        jettonWalletCode = await compile('JettonWallet');
        jettonMinterCode = await compile('JettonMinter');
    });

    let blockchain: Blockchain;

    let admin: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    let buyer: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domain: SandboxContract<Domain>;
    
    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtMarketplaceWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtBuyerWallet: SandboxContract<JettonWallet>;
    let usdtOfferWallet: SandboxContract<JettonWallet>;

    const DOMAIN_NAME = "test12345678.ton";
    let domainConfig: DomainConfig;
    let transactionRes: SendMessageResult;

    let offer: SandboxContract<JettonSimpleOffer>;

    let offerConfig: JettonSimpleOfferConfig;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        marketplace = admin;

        seller = await blockchain.treasury('seller');
        buyer = await blockchain.treasury('buyer');
        
        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendDeploy(admin.getSender(), toNano("0.05"));
        await usdtMinter.sendMint(admin.getSender(), buyer.address, toNano(100), toNano("0.2"), toNano("0.5"));
        usdtMarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtBuyerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(buyer.address)));
        
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
            state: JettonSimpleOffer.STATE_NOT_INITIALIZED,
            commission: toNano("0.2"),
            createdAt: blockchain.now,
            validUntil: blockchain.now + ONE_DAY * 3,
            buyerAddress: buyer.address,
            sellerAddress: seller.address,
            sellerPrice: 0n,
            domainName: DOMAIN_NAME,
            jettonWalletAddress: null,
            jettonMinterAddress: usdtMinter.address
        }
        offer = blockchain.openContract(JettonSimpleOffer.createFromConfig(offerConfig, offerCode));
        const usdtOfferWalletAddress = await usdtMinter.getWalletAddress(offer.address);
        transactionRes = await offer.sendDeploy(admin.getSender(), toNano('0.17'), beginCell().storeAddress(usdtOfferWalletAddress).endCell());
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: offer.address,
            success: true,
            deploy: true,
        });

        offerConfig = await offer.getStorageData();
        usdtOfferWallet = blockchain.openContract(JettonWallet.createFromAddress(offerConfig.jettonWalletAddress!));
        expect(usdtOfferWallet.address.toString()).toEqual(usdtOfferWalletAddress.toString());

        await usdtBuyerWallet.sendTransfer(buyer.getSender(), offerConfig.price + offerConfig.commission, offer.address, buyer.address, 0n);
    });

    it('should deploy', async () => {
    });

    it('should accept domain', async () => {
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, null, toNano('0.02'));

        // check jetton balances
        expect(await usdtOfferWallet.getJettonBalance()).toEqual(0n);
        expect(await usdtSellerWallet.getJettonBalance()).toEqual(offerConfig.price);
        expect(await usdtMarketplaceWallet.getJettonBalance()).toEqual(offerConfig.commission);

        // check domain owner
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());

        // check offer state
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_COMPLETED);
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        
        // should return domain if the offer is already accepted
        transactionRes = await domain.sendTransfer(buyer.getSender(), offer.address, seller.address, null, toNano('0.02'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());
    });

    it('should change price', async () => {
        // with notification
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), offerConfig.price + offerConfig.commission, offer.address, buyer.address, 
                                                            toNano("0.125"), JettonSimpleOffer.changePricePayload(blockchain.now! + ONE_DAY * 4, true));

        expect(transactionRes.transactions[5].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("New offer on webdom.market! 4000 USDT for");
        expect(transactionRes.transactions[6].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Price changed to 4000");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('4'));
        expect(offerConfig.validUntil).toEqual(blockchain.now! + ONE_DAY * 4);
        expect(offerConfig.commission).toEqual(toNano('0.4'));

        // without notification
        blockchain.now! += ONE_DAY;
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), toNano('0.11'), offer.address, buyer.address, 
                                                            toNano("0.025"), JettonSimpleOffer.changePricePayload(blockchain.now! + ONE_DAY * 5, false));
        expect(transactionRes.transactions[5].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Price changed to");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('4.1'));
        expect(offerConfig.validUntil).toEqual(blockchain.now! + ONE_DAY * 5);
        expect(offerConfig.commission).toEqual(toNano('0.41'));
        
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
        
        // Change price after counterproposal
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), toNano("0.99"), offer.address, buyer.address, 
                                toNano("0.075"), JettonSimpleOffer.changePricePayload(offerConfig.validUntil!, false));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.price).toEqual(toNano('5'));
        expect(offerConfig.commission).toEqual(toNano('0.5'));

        // counterpropose after nft transfer
        transactionRes = await offer.sendCounterpropose(seller.getSender(), toNano('5.5'), true);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('5.5'));

        // Accept counterproposal
        transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), toNano("0.55"), offer.address, buyer.address, 
                                                            toNano("0.025"), JettonSimpleOffer.changePricePayload(blockchain.now! + ONE_DAY * 4, false));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_COMPLETED);
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(buyer.address.toString());

        
        // // reject invalid valid until
        // blockchain.now! += ONE_DAY * 5;
        // transactionRes = await usdtBuyerWallet.sendTransfer(buyer.getSender(), toNano('0.1'), offer.address, buyer.address, 
        //                                                     toNano("0.15"), JettonSimpleOffer.changePricePayload(blockchain.now! + 299, false));
        // expect(transactionRes.transactions).toHaveTransaction({
        //     success: true,
        //     exitCode: Exceptions.INCORRECT_VALID_UNTIL,
        // });
        // expect(await usdtOfferWallet.getJettonBalance()).toEqual(offerConfig.price + offerConfig.commission);
    });

    it("should be cancelable by the buyer after counterproposal", async () => {
        // counterpropose
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6'));

        // cancel
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });

    it("should be cancelable by the seller after counterproposal", async () => {
        // counterpropose
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, TonSimpleOffer.counterProposePayload(toNano('6'), false), toNano('0.2'));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.sellerPrice).toEqual(toNano('6'));
        
        transactionRes = await offer.sendCancelOffer(seller.getSender(), "Test comment");
        // console.log(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail())
        // expect(transactionRes.transactions[3].inMessage!.body.beginParse().skip(32).loadStringTail()).toContain("Test comment");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_CANCELLED);
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });


    it('should be cancelable by the buyer', async () => {
        // reject if not enough time passed
        blockchain.now! += 30;
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            success: false,
            exitCode: Exceptions.CANT_CANCEL_DEAL,
        });

        // cancel
        blockchain.now! += 601;
        transactionRes = await offer.sendCancelOffer(buyer.getSender());
        printTransactionFees(transactionRes.transactions);
        console.log(transactionRes.transactions[1].vmLogs);
        
        expect(transactionRes.transactions[4].inMessage!.body.beginParse().loadRef().beginParse().skip(32).loadStringTail()).toContain("Your offer on webdom.market was cancelled");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        expect(await usdtOfferWallet.getJettonBalance()).toEqual(0n);
        expect(await usdtBuyerWallet.getJettonBalance()).toEqual(toNano('100'));

        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_CANCELLED);

        // should return domain if the offer is cancelled
        transactionRes = await domain.sendTransfer(seller.getSender(), offer.address, seller.address, null, toNano('0.02'));
        domainConfig = await domain.getStorageData();
        expect(domainConfig.ownerAddress!.toString()).toEqual(seller.address.toString());
    });

    it('should be cancelable by the offer receiver', async () => {        
        // cancel
        transactionRes = await offer.sendCancelOffer(seller.getSender(), "Test comment");
        printTransactionFees(transactionRes.transactions);
        console.log(transactionRes.transactions[1].vmLogs);
        expect(transactionRes.transactions).toHaveTransaction({
            from: offer.address,
            to: seller.address,
            op: OpCodes.EXCESSES,
            value: toNano('0.01') + JettonSimpleOffer.DECLINE_REWARD,
        });

        expect(transactionRes.transactions[4].inMessage!.body.beginParse().loadRef().beginParse().skip(32).loadStringTail()).toContain("Test comment");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        expect(await usdtBuyerWallet.getJettonBalance()).toEqual(toNano('100'));
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_CANCELLED);
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
        expect(transactionRes.transactions[3].inMessage!.body.beginParse().loadRef().beginParse().skip(32).loadStringTail()).toEqual("Offer expired");
        expect((await blockchain.getContract(offer.address)).balance).toEqual(0n);
        offerConfig = await offer.getStorageData();
        expect(offerConfig.state).toEqual(JettonSimpleOffer.STATE_CANCELLED);
        expect(await usdtBuyerWallet.getJettonBalance()).toEqual(toNano('100'));
    });

    it('should change valid until', async () => {
        let newValidUntil = offerConfig.validUntil! + ONE_DAY * 3;
        transactionRes = await offer.sendChangeValidUntil(buyer.getSender(), newValidUntil);
        expect(transactionRes.transactions[2].inMessage!.body.beginParse().skip(32).loadStringTail()).toEqual("Valid until time updated");
        offerConfig = await offer.getStorageData();
        expect(offerConfig.validUntil).toEqual(newValidUntil)
    });
});

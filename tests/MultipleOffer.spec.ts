import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { DomainInOfferInfo, domainInOfferValue, MultipleOffer, MultipleOfferConfig } from '../wrappers/MultipleOffer';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { COMMISSION_DIVIDER, Exceptions, ONE_DAY, OpCodes } from '../wrappers/helpers/constants';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { JettonWallet } from '../wrappers/JettonWallet';
import { jettonsToString } from '../wrappers/helpers/functions';
import { JettonMinter } from '../wrappers/JettonMinter';


describe('MultipleOffer', () => {
    let multipleOfferCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;
    let jettonMinterCode: Cell;
    let jettonWalletCode: Cell;

    beforeAll(async () => {
        multipleOfferCode = await compile('MultipleOffer');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
        jettonMinterCode = await compile('JettonMinter');
        jettonWalletCode = await compile('JettonWallet');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;
    let owner: SandboxContract<TreasuryContract>;
    let seller: SandboxContract<TreasuryContract>;
    
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;

    let usdtMinter: SandboxContract<JettonMinter>;
    let usdtMarketplaceWallet: SandboxContract<JettonWallet>;
    let usdtSellerWallet: SandboxContract<JettonWallet>;
    let usdtOwnerWallet: SandboxContract<JettonWallet>;
    let usdtOfferWallet: SandboxContract<JettonWallet>;

    let web3Minter: SandboxContract<JettonMinter>;
    let web3MarketplaceWallet: SandboxContract<JettonWallet>;
    let web3SellerWallet: SandboxContract<JettonWallet>;
    let web3OwnerWallet: SandboxContract<JettonWallet>;
    let web3OfferWallet: SandboxContract<JettonWallet>;

    let multipleOffer: SandboxContract<MultipleOffer>;
    let multipleOfferConfig: MultipleOfferConfig;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton", "test400000000.ton", "test500000000.ton"];
    let domainConfigs: Array<DomainConfig>;
    let domainsDict: Dictionary<Address, DomainInOfferInfo>;
    let merkleRoot: bigint;

    let transactionRes: SendMessageResult;

    let DOMAINS_INFO: Array<DomainInOfferInfo> = []
    const secretKey = Buffer.from("a697139dab71a6ec0e2abf3232c4ebe2ba5c383c18a0229e9e3705aacfa3d9c96580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8", 'hex');

    async function checkSuccessfullSale(transactionRes: SendMessageResult, domainIndex: number) {
        const domainInOfferInfo = DOMAINS_INFO[domainIndex];
        let expectedNotification: string;
        let commission = domainInOfferInfo.price * BigInt(multipleOfferConfig.commissionFactor) / BigInt(COMMISSION_DIVIDER);
       
        if (!domainInOfferInfo.jettonInfo) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleOffer.address,
                to: marketplace.address,
                value: (v) => { return v! > commission - toNano('0.01') && v! < commission},
                body: beginCell().storeUint(0, 32).storeStringTail("Marketplace commission").endCell(),
                success: true,
            });

            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleOffer.address,
                to: seller.address,
                value: domainInOfferInfo.price,
                body: beginCell().storeUint(0, 32).storeStringTail("NFT sold on webdom.market").endCell(),
                success: true,
            });
            
            let multipleOfferBalance = (await blockchain.getContract(multipleOffer.address)).balance;
            expectedNotification = `webdom multi-offer executed. Remaining balance: ${jettonsToString(multipleOfferBalance, 9)} TON`;
        }
        else {
            const {jettonWalletAddress, oneJetton, jettonSymbol} = domainInOfferInfo.jettonInfo;
            const jettonWallet = blockchain.openContract(JettonWallet.createFromAddress(jettonWalletAddress));
            const jettonWalletBalance = await jettonWallet.getJettonBalance();
            expectedNotification = `webdom multi-offer executed. Remaining balance: ${jettonsToString(jettonWalletBalance, Math.log10(Number(oneJetton)))} ${jettonSymbol}`;
            
            if (jettonWalletAddress.equals(web3OfferWallet.address)) {
                commission = domainInOfferInfo.price * BigInt(multipleOfferConfig.web3CommissionFactor) / BigInt(COMMISSION_DIVIDER);
            }

            expect(transactionRes.transactions).toHaveTransaction({
                to: marketplace.address,
                value: toNano('0.01'),
                body: (c: Cell | undefined) => {
                    if (!c) {
                        return false;
                    }
                    try {
                        const {jettonAmount, fromAddress, forwardPayload} = JettonWallet.parseTransferNotificationMessage(c);
                        expect(jettonAmount).toBe(commission);
                        expect(fromAddress.equals(multipleOffer.address)).toBeTruthy();
                        expect(forwardPayload?.beginParse().skip(32).loadStringTail()).toBe("Marketplace commission");
                        return true;
                    } catch (e) {
                        return false;
                    }
                }
            });
            expect(transactionRes.transactions).toHaveTransaction({
                to: seller.address,
                value: 1n,
                body: (c: Cell | undefined) => {
                    if (!c) {
                        return false;
                    }
                    try {
                        const {jettonAmount, fromAddress, forwardPayload} = JettonWallet.parseTransferNotificationMessage(c);
                        expect(jettonAmount).toBe(domainInOfferInfo.price);
                        expect(fromAddress.equals(multipleOffer.address)).toBeTruthy();
                        expect(forwardPayload?.beginParse().skip(32).loadStringTail()).toBe("NFT sold on webdom.market");
                        return true;
                    } catch (e) {
                        return false;
                    }
                }
            });
        }

        expect(transactionRes.transactions).toHaveTransaction({
            from: domains[domainIndex].address,
            to: owner.address,
            body: (c: Cell | undefined) => {
                if (!c) {
                    return false;
                }
                try {
                    const {fromAddress, forwardPayload} = Domain.parseOwnershipAssignedMessage(c);
                    expect(fromAddress.equals(multipleOffer.address)).toBeTruthy();
                    const receivedNotification = forwardPayload!.beginParse().skip(32).loadStringTail();
                    if (domainInOfferInfo.jettonInfo) {
                        expect(receivedNotification).toBe(expectedNotification);
                    }
                    else {
                        const receivedRemainingBalance = Number(receivedNotification.split(" ")[5]);
                        const expectedRemainingBalance = Number(expectedNotification.split(" ")[5]);
                        expect(Math.abs(receivedRemainingBalance - expectedRemainingBalance)).toBeLessThan(0.015);
                    }
                    return true;
                } catch (e) {
                    return false;
                }
            }
        });
        
        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.soldNftsDict.get(domains[domainIndex].address)).toBe(blockchain.now!);
        
        const domainConfig = await domains[domainIndex].getStorageData();
        expect(domainConfig.ownerAddress?.equals(owner.address)).toBeTruthy();
    }

    async function checkFailedSale(transactionRes: SendMessageResult, domainIndex: number, exitCode: number, nftOwnerAddress?: Address) {
        expect(transactionRes.transactions).toHaveTransaction({
            from: domains[domainIndex].address,
            to: multipleOffer.address,
            exitCode: exitCode,
        });

        const domainConfig = await domains[domainIndex].getStorageData();
        expect(domainConfig.ownerAddress?.equals(nftOwnerAddress ?? seller.address)).toBeTruthy();
    }

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = Math.floor(Date.now() / 1000);

        admin = await blockchain.treasury('admin');
        marketplace = admin;
        owner = await blockchain.treasury('owner');
        seller = await blockchain.treasury('seller');

        multipleOfferConfig = {
            ownerAddress: owner.address,
            merkleRoot: 0n,
            publicKey: 0x6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8n,
            commissionFactor: 0,
            soldNftsDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Uint(32)),
            jettonBalancesDict: Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.BigVarUint(4)),
            web3CommissionFactor: 0,
        };

        multipleOffer = blockchain.openContract(
            MultipleOffer.createFromConfig(multipleOfferConfig, multipleOfferCode)
        );

        usdtMinter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("usdt").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await usdtMinter.sendMint(admin.getSender(), owner.address, toNano(100), toNano("0.2"), toNano("0.5"));
        usdtMarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(admin.address)));
        usdtSellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(seller.address)));
        usdtOwnerWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(owner.address)));
        usdtOfferWallet = blockchain.openContract(JettonWallet.createFromAddress(await usdtMinter.getWalletAddress(multipleOffer.address)));

        web3Minter = blockchain.openContract(JettonMinter.createFromConfig({admin: admin.address, content: beginCell().storeStringTail("web3").endCell(), wallet_code: jettonWalletCode}, jettonMinterCode));
        await web3Minter.sendMint(admin.getSender(), owner.address, toNano(100), toNano("0.2"), toNano("0.5"));
        web3MarketplaceWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(admin.address)));
        web3SellerWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(seller.address)));
        web3OwnerWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(owner.address)));
        web3OfferWallet = blockchain.openContract(JettonWallet.createFromAddress(await web3Minter.getWalletAddress(multipleOffer.address)));

        DOMAINS_INFO = [
            {
                price: toNano('1'),
                validUntil: blockchain.now + ONE_DAY,
            },
            {
                price: toNano('2'),
                validUntil: blockchain.now + ONE_DAY,
            },
            {
                price: toNano('0.5'),
                validUntil: blockchain.now + ONE_DAY / 2,
            },
            {
                price: toNano('3.05'),
                validUntil: blockchain.now + ONE_DAY * 2
            },
            {
                price: 30_000n,
                validUntil: blockchain.now + ONE_DAY * 2,
                jettonInfo: {
                    jettonWalletAddress: web3OfferWallet.address,
                    oneJetton: 1000n,
                    jettonSymbol: "WEB3",
                },
            },
            {
                price: 7_500_000n,
                validUntil: blockchain.now + ONE_DAY * 2,
                jettonInfo: {
                    jettonWalletAddress: usdtOfferWallet.address,
                    oneJetton: 1000000n,
                    jettonSymbol: "USDT",
                },
            },
        ]
    
        domains = [];
        domainConfigs = [];
        domainsDict = Dictionary.empty(Dictionary.Keys.Address(), domainInOfferValue);

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


        for (let i = 0; i < DOMAIN_NAMES.length; i++) {  // deploy domains
            transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), DOMAIN_NAMES[i]);
            const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
            expect(transactionRes.transactions).toHaveTransaction({
                from: dnsCollection.address,
                to: domainAddress,
                deploy: true,
                success: true
            })
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            blockchain.now += 60 * 60 + 1;  // end of the auction
            transactionRes = await domain.sendTransfer(admin.getSender(), seller.address, seller.address);
            
            domains.push(domain);
            if (i !== 5) {
                domainsDict.set(domainAddress, DOMAINS_INFO[i]);
            }
        }

        // Calculate merkle root
        const dictCell = beginCell().storeDictDirect(domainsDict).endCell();
        merkleRoot = BigInt('0x' + dictCell.hash().toString('hex'));

        transactionRes = await multipleOffer.sendDeploy(
            admin.getSender(),
            toNano('0.05'),
            MultipleOffer.deployMessage(merkleRoot, web3OfferWallet.address, COMMISSION_DIVIDER / 10, COMMISSION_DIVIDER / 20)
        );
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: multipleOffer.address,
            deploy: true,
            success: true,
        });

        await multipleOffer.sendFillUpBalance(owner.getSender(), toNano('0.5'));
        let multipleOfferBalance = (await blockchain.getContract(multipleOffer.address)).balance;
        expect(multipleOfferBalance).toBeGreaterThan(toNano('0.5'));

        transactionRes = await usdtOwnerWallet.sendTransfer(
            owner.getSender(), 8250000n, multipleOffer.address, owner.address, 
            toNano('0.55'), MultipleOffer.fillUpJettonBalancePayload(toNano('0.5'))
        );

        transactionRes = await multipleOffer.sendFillUpBalance(owner.getSender(), toNano('0.2'));
        
        multipleOfferBalance = (await blockchain.getContract(multipleOffer.address)).balance
        expect(multipleOfferBalance).toBeGreaterThan(toNano('1'));

        transactionRes = await web3OwnerWallet.sendTransfer(
            owner.getSender(), 29_000n, multipleOffer.address, owner.address, 
            toNano('0.05'), MultipleOffer.fillUpJettonBalancePayload(0n)
        );

        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.ownerAddress.equals(owner.address)).toBeTruthy();
        expect(multipleOfferConfig.merkleRoot).toBe(merkleRoot);
        expect(multipleOfferConfig.jettonBalancesDict.get(web3OfferWallet.address)).toBe(29_000n);
        expect(multipleOfferConfig.jettonBalancesDict.get(usdtOfferWallet.address)).toBe(8250000n);
    });

    it('should deploy', async () => {
        blockchain.now! += ONE_DAY * 365;
        transactionRes = await multipleOffer.sendFillUpBalance(owner.getSender(), toNano('0.5'));

    });

    it('should not accept multiple deploy requests', async () => {
        // Second deploy should fail
        transactionRes = await multipleOffer.sendDeploy(
            admin.getSender(),
            toNano('0.05'),
            MultipleOffer.deployMessage(merkleRoot, web3OfferWallet.address, COMMISSION_DIVIDER / 10, COMMISSION_DIVIDER / 20)
        );

        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: multipleOffer.address,
            exitCode: Exceptions.ALREADY_DEPLOYED,
        });
        
    });

    it('should sell NFTs', async () => {
        // successfull sale
        transactionRes = await domains[0].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[0].address]),
            toNano('0.03')
        );
        await checkSuccessfullSale(transactionRes, 0);

        transactionRes = await multipleOffer.sendMessageWithComment(owner.getSender(), toNano(3), "fillup");
        expect((await blockchain.getContract(multipleOffer.address)).balance).toBeGreaterThan(toNano(3));
        
        // not enough balance
        transactionRes = await domains[3].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[3].address]),
            toNano('0.03')
        );
        await checkFailedSale(transactionRes, 3, Exceptions.OUT_OF_GAS);

        // NFT already sold
        transactionRes = await domains[0].sendTransfer(
            owner.getSender(), multipleOffer.address, owner.address, 
            domainsDict.generateMerkleProof([domains[0].address]),
            toNano('0.03')
        );
        await checkFailedSale(transactionRes, 0, Exceptions.NFT_ALREADY_SOLD, owner.address);

        // incorrect proof
        transactionRes = await domains[1].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[0].address]),
            toNano('0.03')
        );
        await checkFailedSale(transactionRes, 1, 9);
        
        // successfull sale 2
        transactionRes = await domains[1].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[1].address]),
            toNano('0.03')
        );
        printTransactionFees(transactionRes.transactions);
        await checkSuccessfullSale(transactionRes, 1);

        // offer expired
        blockchain.now = DOMAINS_INFO[2].validUntil + 1;
        transactionRes = await domains[2].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[2].address]),
            toNano('0.03')
        );
        await checkFailedSale(transactionRes, 2, Exceptions.DEAL_NOT_ACTIVE);

        // jetton balance is not enough
        transactionRes = await domains[4].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[4].address]),
            toNano('0.03')
        );
        await checkFailedSale(transactionRes, 4, Exceptions.NOT_ENOUGH_JETTONS);
        
        // successfull sale
        blockchain.now += 100;
        transactionRes = await web3OwnerWallet.sendTransfer(
            owner.getSender(), 29_000n, multipleOffer.address, owner.address, 
            toNano('0.05'), MultipleOffer.fillUpJettonBalancePayload(0n)
        );
        transactionRes = await domains[4].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[4].address]),
            toNano('0.03')
        );
        await checkSuccessfullSale(transactionRes, 4);

        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.jettonBalancesDict.get(web3OfferWallet.address)).toBe(26_500n);
        
        // update data
        for (let i = 0; i < 5; i++) {
            domainsDict.delete(domains[i].address);
        }
        domainsDict.set(domains[5].address, DOMAINS_INFO[5]);
        merkleRoot = BigInt('0x' + beginCell().storeDictDirect(domainsDict).endCell().hash().toString('hex'));
        transactionRes = await multipleOffer.sendChangeData(owner.getSender(), merkleRoot, blockchain.now - 1, multipleOffer.address, secretKey);
        expect(transactionRes.transactions).toHaveTransaction({
            from: owner.address,
            to: multipleOffer.address,
            success: true,
            exitCode: 0,
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleOffer.address,
            to: owner.address,
            body: beginCell().storeUint(0, 32).storeStringTail("Multiple offer was successfully updated").endCell(),
        });

        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.merkleRoot).toBe(merkleRoot);
        expect(multipleOfferConfig.soldNftsDict.keys().length).toBe(1);
        expect(multipleOfferConfig.soldNftsDict.keys()[0].equals(domains[4].address)).toBeTruthy();

        // sale of the added NFT
        transactionRes = await domains[5].sendTransfer(
            seller.getSender(), multipleOffer.address, seller.address, 
            domainsDict.generateMerkleProof([domains[5].address]),
            toNano('0.02')
        );
        await checkSuccessfullSale(transactionRes, 5);

    });

    it ('should withdraw ton and jettons', async () => {
        transactionRes = await multipleOffer.sendWithdrawTonAmount(owner.getSender(), toNano('0.5'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleOffer.address,
            to: owner.address,
            value: (v: bigint | undefined) => {
                return v! > toNano('0.5') && v! < toNano('0.52');
            },
            body: beginCell().storeUint(0, 32).storeStringTail("TON withdrawal").endCell(),
            success: true,
        });
        expect((await blockchain.getContract(multipleOffer.address)).balance).toBeLessThan(toNano('0.75'));

        transactionRes = await multipleOffer.sendWithdrawJetton(owner.getSender(), usdtOfferWallet.address, 500_000n);
        expect(await usdtOfferWallet.getJettonBalance()).toBe(8250000n - 500_000n);
        transactionRes = await multipleOffer.sendWithdrawJetton(owner.getSender(), web3OfferWallet.address, 30_000n);
        expect(await web3OfferWallet.getJettonBalance()).toBe(29_000n);

        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.jettonBalancesDict.get(usdtOfferWallet.address)).toBe(8250000n - 500_000n);
        expect(multipleOfferConfig.jettonBalancesDict.get(web3OfferWallet.address)).toBe(0n);
    });

    it('should cancel deal', async () => {
        transactionRes = await multipleOffer.sendMessageWithComment(owner.getSender(), toNano(1), "cancel");

        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleOffer.address,
            to: owner.address,
            success: true,
            body: beginCell().storeUint(0, 32).storeStringTail("Multiple offer was cancelled").endCell(),
        });
        
        const usdtOfferBalance = await usdtOfferWallet.getJettonBalance();
        const web3OfferBalance = await web3OfferWallet.getJettonBalance();
        expect(usdtOfferBalance).toBe(0n);
        expect(web3OfferBalance).toBe(0n);

        const usdtOwnerBalance = await usdtOwnerWallet.getJettonBalance();
        const web3OwnerBalance = await web3OwnerWallet.getJettonBalance();
        expect(usdtOwnerBalance).toBe(toNano(100));
        expect(web3OwnerBalance).toBe(toNano(100));

        const multipleOfferBalance = (await blockchain.getContract(multipleOffer.address)).balance;
        expect(multipleOfferBalance).toBe(0n);

        multipleOfferConfig = await multipleOffer.getStorageData();
        expect(multipleOfferConfig.merkleRoot).toBe(0n);
        expect(multipleOfferConfig.jettonBalancesDict.keys().length).toBe(0);
        expect(multipleOfferConfig.soldNftsDict.keys().length).toBe(0);
    });
});

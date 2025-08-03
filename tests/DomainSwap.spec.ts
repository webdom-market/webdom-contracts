import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { DomainSwap, DomainsSwapConfig } from '../wrappers/DomainSwap';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { DomainConfig } from '../wrappers/Domain';
import { Domain } from '../wrappers/Domain';
import { TonMultipleSaleConfig } from '../wrappers/TonMultipleSale';
import { Exceptions, MIN_PRICE_START_TIME, OpCodes, Tons } from '../wrappers/helpers/constants';

describe('DomainSwap', () => {
    let multipleDomainsSwapCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        multipleDomainsSwapCode = await compile('DomainSwap');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let leftParticipant: SandboxContract<TreasuryContract>;
    let rightParticipant: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let multipleDomainsSwap: SandboxContract<DomainSwap>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;
    let leftDomains: Array<SandboxContract<Domain>>;
    let rightDomains: Array<SandboxContract<Domain>>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton", "mxmxmx.ton"];
    let transactionRes: SendMessageResult;

    let multipleDomainsSwapConfig: DomainsSwapConfig;
    
    let tmp = 0;

    const readyNotification = beginCell().storeUint(0, 32).storeStringTail("The offer is ready, wait for the second participant.").endCell();
    const offerCancelledNotification = beginCell().storeUint(0, 32).storeStringTail("You have a new domains swap offer on webdom.market!").endCell();
    const payoutNotification = beginCell().storeUint(0, 32).storeStringTail("webdom.market payout for domains swap").endCell();
    
    async function checkSwapSuccess() {
        if (multipleDomainsSwapConfig.rightPaymentReceived - multipleDomainsSwapConfig.rightPaymentTotal + multipleDomainsSwapConfig.leftPaymentTotal > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainsSwap.address,
                to: rightParticipant.address,
                body: payoutNotification,
                value(x) {
                    return x! > multipleDomainsSwapConfig.rightPaymentReceived - multipleDomainsSwapConfig.rightPaymentTotal + multipleDomainsSwapConfig.leftPaymentTotal - toNano('0.001');
                }
            });
        }
        if (multipleDomainsSwapConfig.rightPaymentTotal > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainsSwap.address,
                to: leftParticipant.address,
                body: payoutNotification,
                value(x) {
                    return x! > multipleDomainsSwapConfig.rightPaymentTotal - toNano('0.001');
                }
            });
        }
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: marketplace.address,
            value(x) {
                return x! > multipleDomainsSwapConfig.commission - toNano('0.001');
            }
        });
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_COMPLETED);
        for (let domain of leftDomains) {
            const domainOwnerAddress = (await domain.getStorageData()).ownerAddress?.toString();
            expect(domainOwnerAddress).toBe(rightParticipant.address.toString());
        }
        for (let domain of rightDomains) {
            const domainOwnerAddress = (await domain.getStorageData()).ownerAddress?.toString();
            expect(domainOwnerAddress).toBe(leftParticipant.address.toString());
        }
        expect((await blockchain.getContract(multipleDomainsSwap.address)).balance).toBe(0n);
    }

    async function checkSwapCancelled(cancelNotification: string) {
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_CANCELLED);

        if (multipleDomainsSwapConfig.leftDomainsReceived > 0) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: leftDomains[0].address,
                to: leftParticipant.address,
                body(x) {
                    return x!.refs.length > 0 && x!.beginParse().loadRef().beginParse().skip(32).loadStringTail() == cancelNotification;
                }
            });
        }
        if (multipleDomainsSwapConfig.rightDomainsReceived > 0) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: rightDomains[0].address,
                to: rightParticipant.address,
                body(x) {
                    return x!.refs.length > 0 && x!.beginParse().loadRef().beginParse().skip(32).loadStringTail() == cancelNotification;
                }
            });
        }
        if (multipleDomainsSwapConfig.rightPaymentReceived > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainsSwap.address,
                to: rightParticipant.address,
                op: OpCodes.EXCESSES,
                value(x) {
                    return x! > multipleDomainsSwapConfig.rightPaymentReceived - toNano('0.001');
                },
            });
        }
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: leftParticipant.address,
            op: OpCodes.EXCESSES,
        });
        for (let domain of leftDomains) {
            expect((await domain.getStorageData()).ownerAddress?.toString()).toBe(leftParticipant.address.toString());
        }
        for (let domain of rightDomains) {
            expect((await domain.getStorageData()).ownerAddress?.toString()).toBe(rightParticipant.address.toString());
        }
        expect((await blockchain.getContract(multipleDomainsSwap.address)).balance).toBe(0n);
    }
    
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        domains = [];
        leftDomains = [];
        rightDomains = [];

        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        
        marketplace = admin;

        leftParticipant = await blockchain.treasury('left');
        rightParticipant = await blockchain.treasury('right');
        
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

        let leftDomainsDict: Dictionary<Address, boolean> = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        let rightDomainsDict: Dictionary<Address, boolean> = Dictionary.empty(Dictionary.Keys.Address(), Dictionary.Values.Bool());
        for (let i = 0; i < DOMAIN_NAMES.length; ++i) {  // deploy domains
            const domainName = DOMAIN_NAMES[i];
            transactionRes = await dnsCollection.sendStartAuction(admin.getSender(), domainName);
            const domainAddress = transactionRes.transactions[2].inMessage!.info.dest! as Address; 
            expect(transactionRes.transactions).toHaveTransaction({
                from: dnsCollection.address,
                to: domainAddress,
                deploy: true,
                success: true
            })
            let domain = blockchain.openContract(Domain.createFromAddress(domainAddress));
            blockchain.now += 60 * 60 + 1;  // end of the auction

            domains.push(domain);
            if (i < 2) {
                transactionRes = await domain.sendTransfer(admin.getSender(), leftParticipant.address, admin.address);
                leftDomainsDict.set(domainAddress, false);
                leftDomains.push(domain);
            } else {
                transactionRes = await domain.sendTransfer(admin.getSender(), rightParticipant.address, admin.address);
                rightDomainsDict.set(domainAddress, false);
                rightDomains.push(domain);
            }
        }

        multipleDomainsSwapConfig = {
            leftParticipantAddress: leftParticipant.address,
            leftDomainsTotal: leftDomains.length,
            leftDomainsReceived: 0,
            leftDomainsDict: leftDomainsDict,
            leftPaymentTotal: toNano('5'),
            leftPaymentReceived: 0n,
            
            rightParticipantAddress: rightParticipant.address,
            rightDomainsTotal: rightDomains.length,
            rightDomainsReceived: 0,
            rightDomainsDict: rightDomainsDict,
            rightPaymentTotal: 0n,
            rightPaymentReceived: 0n,

            state: DomainSwap.STATE_CANCELLED,
            createdAt: blockchain.now,
            validUntil: blockchain.now + 60 * 120,
            lastActionTime: 0,
            commission: toNano('0.1'),
            needsAlert: true,
        }
    });

    it('should make swap (payment from the left in domain transfer)', async () => {
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));
        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: multipleDomainsSwap.address,
            success: true,
        });
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        transactionRes = await leftDomains[0].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.leftDomainsReceived).toBe(1);
        expect(multipleDomainsSwapConfig.leftPaymentReceived).toBe(toNano('0.01'));
        expect(multipleDomainsSwapConfig.lastActionTime).toBe(blockchain.now);

        blockchain.now! += 10;
        transactionRes = await leftDomains[1].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + multipleDomainsSwapConfig.leftPaymentTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: leftParticipant.address,
            body: readyNotification,
            value: toNano('0.01'),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: rightParticipant.address,
            body: offerCancelledNotification,
            value: Tons.OFFER_NOTIFICATION,
        });
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.leftDomainsReceived).toBe(2);
        expect(multipleDomainsSwapConfig.leftPaymentReceived).toBe(multipleDomainsSwapConfig.leftPaymentTotal);
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);
        expect(multipleDomainsSwapConfig.lastActionTime).toBe(blockchain.now);

        for (let i = 0; i < rightDomains.length - 1; ++i) {
            blockchain.now! += 10;
            transactionRes = await rightDomains[i].sendTransfer(rightParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.1'));
            multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
            expect(multipleDomainsSwapConfig.rightDomainsReceived).toBe(i + 1);
            expect(multipleDomainsSwapConfig.lastActionTime).toBe(blockchain.now);
            expect(multipleDomainsSwapConfig.rightPaymentReceived).toBe(toNano('0.1') * BigInt(i + 1));
        }

        transactionRes = await rightDomains[rightDomains.length - 1].sendTransfer(rightParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + multipleDomainsSwapConfig.rightPaymentTotal);
        await checkSwapSuccess();
    });

    it('should make swap (payment from the right after all domains are transferred)', async () => {
        multipleDomainsSwapConfig.rightPaymentTotal = toNano(10);
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));

        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
            multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
            expect(multipleDomainsSwapConfig.leftDomainsReceived).toBe(i + 1);
            expect(multipleDomainsSwapConfig.leftPaymentReceived).toBe(toNano('0.01') * BigInt(i + 1));
            expect(multipleDomainsSwapConfig.lastActionTime).toBe(blockchain.now);
        }
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);
        
        transactionRes = await multipleDomainsSwap.sendAddPayment(leftParticipant.getSender(), multipleDomainsSwapConfig.leftPaymentTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: leftParticipant.address,
            value: toNano('0.01') * BigInt(leftDomains.length),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: leftParticipant.address,
            body: readyNotification,
            value: toNano('0.02'),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: rightParticipant.address,
            body: offerCancelledNotification,
            value: Tons.OFFER_NOTIFICATION,
        });
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        for (let i = 0; i < rightDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await rightDomains[i].sendTransfer(rightParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.1'));
            multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
            expect(multipleDomainsSwapConfig.rightDomainsReceived).toBe(i + 1);
            expect(multipleDomainsSwapConfig.lastActionTime).toBe(blockchain.now);
            expect(multipleDomainsSwapConfig.rightPaymentReceived).toBe(toNano('0.1') * BigInt(i + 1));
        }
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        transactionRes = await multipleDomainsSwap.sendAddPayment(rightParticipant.getSender(), multipleDomainsSwapConfig.rightPaymentTotal);
        await checkSwapSuccess();
    });

    it('should cancel deal before the right participant joined', async () => {
        multipleDomainsSwapConfig.rightPaymentTotal = toNano(10);
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));
        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }

        // Cancel before the right participant joined
        transactionRes = await multipleDomainsSwap.sendCancelDeal(leftParticipant.getSender());
        // printTransactionFees(transactionRes.transactions);
        await checkSwapCancelled("The offer was cancelled by its creator");

        // Transfer after deal is cancelled should be rejected
        transactionRes = await leftDomains[0].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        expect((await leftDomains[0].getStorageData()).ownerAddress?.toString()).toEqual(leftParticipant.address.toString());

    });

    it('should cancel deal after the right participant joined', async () => {
        multipleDomainsSwapConfig.leftPaymentTotal = 0n;
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));
        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        // One hour didn't pass so cancellation by left owner is not possible
        blockchain.now! += 60 * 60 - 1;
        transactionRes = await multipleDomainsSwap.sendCancelDeal(leftParticipant.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: leftParticipant.address,
            to: multipleDomainsSwap.address,
            exitCode: Exceptions.CANT_CANCEL_DEAL,
        });

        // transfer right domain
        await rightDomains[0].sendTransfer(rightParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.02'));
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.rightDomainsReceived).toBe(1);
        
        // One hour passed, accept cancellation by left owner
        blockchain.now! += 60 * 60;
        transactionRes = await multipleDomainsSwap.sendCancelDeal(leftParticipant.getSender());
        await checkSwapCancelled("The offer was cancelled by its creator");
    });

    it('should cancel deal by right owner', async () => {
        multipleDomainsSwapConfig.leftPaymentTotal = toNano('0.03');
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));
        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData();
        expect(multipleDomainsSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        // Cancel by right owner
        transactionRes = await multipleDomainsSwap.sendCancelDeal(rightParticipant.getSender());
        await checkSwapCancelled("The offer was cancelled by the second participant");
    });

    it('should cancel deal by external message after offer expiration', async () => {
        multipleDomainsSwapConfig.leftPaymentTotal = toNano('0.02');
        multipleDomainsSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainsSwapConfig, multipleDomainsSwapCode));
        transactionRes = await multipleDomainsSwap.sendDeploy(admin.getSender(), toNano('0.215'));

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        await rightDomains[0].sendTransfer(rightParticipant.getSender(), multipleDomainsSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.2'));

        transactionRes = await multipleDomainsSwap.sendChangeValidUntil(leftParticipant.getSender(), blockchain.now! + 60 * 120 + 50);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainsSwap.address,
            to: leftParticipant.address,
            op: OpCodes.EXCESSES,
        });
        multipleDomainsSwapConfig = await multipleDomainsSwap.getStorageData(); 
        expect(multipleDomainsSwapConfig.validUntil).toBe(blockchain.now! + 60 * 120 + 50);
        
        blockchain.now! = multipleDomainsSwapConfig.validUntil;
        transactionRes = await multipleDomainsSwap.sendExternalCancel()
        await checkSwapCancelled("offer has expired");
    });
});

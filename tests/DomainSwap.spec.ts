import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, Dictionary, toNano } from '@ton/core';
import { DomainSwap, DomainSwapConfig } from '../wrappers/DomainSwap';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { DomainConfig } from '../wrappers/Domain';
import { Domain } from '../wrappers/Domain';
import { TonMultipleSaleConfig } from '../wrappers/TonMultipleSale';
import { Exceptions, MIN_PRICE_START_TIME, OpCodes, Tons } from '../wrappers/helpers/constants';

describe('DomainSwap', () => {
    let multipleDomainSwapCode: Cell;
    let dnsCollectionCode: Cell;
    let domainCode: Cell;

    beforeAll(async () => {
        multipleDomainSwapCode = await compile('DomainSwap');
        dnsCollectionCode = await compile('DnsCollection');
        domainCode = await compile('Domain');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let leftParticipant: SandboxContract<TreasuryContract>;
    let rightParticipant: SandboxContract<TreasuryContract>;
    let marketplace: SandboxContract<TreasuryContract>;

    let multipleDomainSwap: SandboxContract<DomainSwap>;
    let dnsCollection: SandboxContract<DnsCollection>;
    let domains: Array<SandboxContract<Domain>>;
    let leftDomains: Array<SandboxContract<Domain>>;
    let rightDomains: Array<SandboxContract<Domain>>;

    const DOMAIN_NAMES = ["test100000000.ton", "test200000000.ton", "test300000000.ton", "idzqnziqdnuzdn.ton", "mxmxmx.ton"];
    let transactionRes: SendMessageResult;

    let multipleDomainSwapConfig: DomainSwapConfig;
    
    let tmp = 0;

    const readyNotification = beginCell().storeUint(0, 32).storeStringTail("The offer is ready, wait for the second participant.").endCell();
    const offerCancelledNotification = beginCell().storeUint(0, 32).storeStringTail("You have a new domains swap offer on webdom.market!").endCell();
    const payoutNotification = beginCell().storeUint(0, 32).storeStringTail("webdom.market payout for domains swap").endCell();
    
    async function checkSwapSuccess() {
        if (multipleDomainSwapConfig.rightPaymentReceived - multipleDomainSwapConfig.rightPaymentTotal + multipleDomainSwapConfig.leftPaymentTotal > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainSwap.address,
                to: rightParticipant.address,
                body: payoutNotification,
                value(x) {
                    return x! > multipleDomainSwapConfig.rightPaymentReceived - multipleDomainSwapConfig.rightPaymentTotal + multipleDomainSwapConfig.leftPaymentTotal - toNano('0.001');
                }
            });
        }
        if (multipleDomainSwapConfig.rightPaymentTotal > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainSwap.address,
                to: leftParticipant.address,
                body: payoutNotification,
                value(x) {
                    return x! > multipleDomainSwapConfig.rightPaymentTotal - toNano('0.001');
                }
            });
        }
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: marketplace.address,
            value(x) {
                return x! > multipleDomainSwapConfig.commission - toNano('0.001');
            }
        });
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_COMPLETED);
        for (let domain of leftDomains) {
            const domainOwnerAddress = (await domain.getStorageData()).ownerAddress?.toString();
            expect(domainOwnerAddress).toBe(rightParticipant.address.toString());
        }
        for (let domain of rightDomains) {
            const domainOwnerAddress = (await domain.getStorageData()).ownerAddress?.toString();
            expect(domainOwnerAddress).toBe(leftParticipant.address.toString());
        }
        expect((await blockchain.getContract(multipleDomainSwap.address)).balance).toBe(0n);
    }

    async function checkSwapCancelled(cancelNotification: string) {
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_CANCELLED);

        if (multipleDomainSwapConfig.leftDomainsReceived > 0) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: leftDomains[0].address,
                to: leftParticipant.address,
                body(x) {
                    return x!.refs.length > 0 && x!.beginParse().loadRef().beginParse().skip(32).loadStringTail() == cancelNotification;
                }
            });
        }
        if (multipleDomainSwapConfig.rightDomainsReceived > 0) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: rightDomains[0].address,
                to: rightParticipant.address,
                body(x) {
                    return x!.refs.length > 0 && x!.beginParse().loadRef().beginParse().skip(32).loadStringTail() == cancelNotification;
                }
            });
        }
        if (multipleDomainSwapConfig.rightPaymentReceived > Tons.MIN_EXCESS) {
            expect(transactionRes.transactions).toHaveTransaction({
                from: multipleDomainSwap.address,
                to: rightParticipant.address,
                op: OpCodes.EXCESSES,
                value(x) {
                    return x! > multipleDomainSwapConfig.rightPaymentReceived - toNano('0.001');
                },
            });
        }
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: leftParticipant.address,
            op: OpCodes.EXCESSES,
        });
        for (let domain of leftDomains) {
            expect((await domain.getStorageData()).ownerAddress?.toString()).toBe(leftParticipant.address.toString());
        }
        for (let domain of rightDomains) {
            expect((await domain.getStorageData()).ownerAddress?.toString()).toBe(rightParticipant.address.toString());
        }
        expect((await blockchain.getContract(multipleDomainSwap.address)).balance).toBe(0n);
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

        multipleDomainSwapConfig = {
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
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));
        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: multipleDomainSwap.address,
            success: true,
        });
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        transactionRes = await leftDomains[0].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.leftDomainsReceived).toBe(1);
        expect(multipleDomainSwapConfig.leftPaymentReceived).toBe(toNano('0.01'));
        expect(multipleDomainSwapConfig.lastActionTime).toBe(blockchain.now);

        blockchain.now! += 10;
        transactionRes = await leftDomains[1].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + multipleDomainSwapConfig.leftPaymentTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: leftParticipant.address,
            body: readyNotification,
            value: toNano('0.01'),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: rightParticipant.address,
            body: offerCancelledNotification,
            value: Tons.OFFER_NOTIFICATION,
        });
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.leftDomainsReceived).toBe(2);
        expect(multipleDomainSwapConfig.leftPaymentReceived).toBe(multipleDomainSwapConfig.leftPaymentTotal);
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);
        expect(multipleDomainSwapConfig.lastActionTime).toBe(blockchain.now);

        for (let i = 0; i < rightDomains.length - 1; ++i) {
            blockchain.now! += 10;
            transactionRes = await rightDomains[i].sendTransfer(rightParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.1'));
            multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
            expect(multipleDomainSwapConfig.rightDomainsReceived).toBe(i + 1);
            expect(multipleDomainSwapConfig.lastActionTime).toBe(blockchain.now);
            expect(multipleDomainSwapConfig.rightPaymentReceived).toBe(toNano('0.1') * BigInt(i + 1));
        }

        transactionRes = await rightDomains[rightDomains.length - 1].sendTransfer(rightParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + multipleDomainSwapConfig.rightPaymentTotal);
        await checkSwapSuccess();
    });

    it('should make swap (payment from the right after all domains are transferred)', async () => {
        multipleDomainSwapConfig.rightPaymentTotal = toNano(10);
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));

        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
            multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
            expect(multipleDomainSwapConfig.leftDomainsReceived).toBe(i + 1);
            expect(multipleDomainSwapConfig.leftPaymentReceived).toBe(toNano('0.01') * BigInt(i + 1));
            expect(multipleDomainSwapConfig.lastActionTime).toBe(blockchain.now);
        }
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);
        
        transactionRes = await multipleDomainSwap.sendAddPayment(leftParticipant.getSender(), multipleDomainSwapConfig.leftPaymentTotal);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: leftParticipant.address,
            value: toNano('0.01') * BigInt(leftDomains.length),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: leftParticipant.address,
            body: readyNotification,
            value: toNano('0.02'),
        });
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: rightParticipant.address,
            body: offerCancelledNotification,
            value: Tons.OFFER_NOTIFICATION,
        });
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        for (let i = 0; i < rightDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await rightDomains[i].sendTransfer(rightParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.1'));
            multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
            expect(multipleDomainSwapConfig.rightDomainsReceived).toBe(i + 1);
            expect(multipleDomainSwapConfig.lastActionTime).toBe(blockchain.now);
            expect(multipleDomainSwapConfig.rightPaymentReceived).toBe(toNano('0.1') * BigInt(i + 1));
        }
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        transactionRes = await multipleDomainSwap.sendAddPayment(rightParticipant.getSender(), multipleDomainSwapConfig.rightPaymentTotal);
        await checkSwapSuccess();
    });

    it('should cancel deal before the right participant joined', async () => {
        multipleDomainSwapConfig.rightPaymentTotal = toNano(10);
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));
        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }

        // Cancel before the right participant joined
        transactionRes = await multipleDomainSwap.sendCancelDeal(leftParticipant.getSender());
        // printTransactionFees(transactionRes.transactions);
        await checkSwapCancelled("The offer was cancelled by its creator");

        // Transfer after deal is cancelled should be rejected
        transactionRes = await leftDomains[0].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        expect((await leftDomains[0].getStorageData()).ownerAddress?.toString()).toEqual(leftParticipant.address.toString());

    });

    it('should cancel deal after the right participant joined', async () => {
        multipleDomainSwapConfig.leftPaymentTotal = 0n;
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));
        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_RIGHT);

        // One hour didn't pass so cancellation by left owner is not possible
        blockchain.now! += 60 * 60 - 1;
        transactionRes = await multipleDomainSwap.sendCancelDeal(leftParticipant.getSender());
        expect(transactionRes.transactions).toHaveTransaction({
            from: leftParticipant.address,
            to: multipleDomainSwap.address,
            exitCode: Exceptions.CANT_CANCEL_DEAL,
        });

        // transfer right domain
        await rightDomains[0].sendTransfer(rightParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.02'));
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.rightDomainsReceived).toBe(1);
        
        // One hour passed, accept cancellation by left owner
        blockchain.now! += 60 * 60;
        transactionRes = await multipleDomainSwap.sendCancelDeal(leftParticipant.getSender());
        await checkSwapCancelled("The offer was cancelled by its creator");
    });

    it('should cancel deal by right owner', async () => {
        multipleDomainSwapConfig.leftPaymentTotal = toNano('0.03');
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));
        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));
        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData();
        expect(multipleDomainSwapConfig.state).toBe(DomainSwap.STATE_WAITING_FOR_LEFT);

        // Cancel by right owner
        transactionRes = await multipleDomainSwap.sendCancelDeal(rightParticipant.getSender());
        await checkSwapCancelled("The offer was cancelled by the second participant");
    });

    it('should cancel deal by external message after offer expiration', async () => {
        multipleDomainSwapConfig.leftPaymentTotal = toNano('0.02');
        multipleDomainSwap = blockchain.openContract(DomainSwap.createFromConfig(multipleDomainSwapConfig, multipleDomainSwapCode));
        transactionRes = await multipleDomainSwap.sendDeploy(admin.getSender(), toNano('0.215'));

        for (let i = 0; i < leftDomains.length; ++i) {
            blockchain.now! += 10;
            transactionRes = await leftDomains[i].sendTransfer(leftParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.01'));
        }
        await rightDomains[0].sendTransfer(rightParticipant.getSender(), multipleDomainSwap.address, null, null, DomainSwap.ADD_DOMAIN_TONS + toNano('0.2'));

        transactionRes = await multipleDomainSwap.sendChangeValidUntil(leftParticipant.getSender(), blockchain.now! + 60 * 120 + 50);
        expect(transactionRes.transactions).toHaveTransaction({
            from: multipleDomainSwap.address,
            to: leftParticipant.address,
            op: OpCodes.EXCESSES,
        });
        multipleDomainSwapConfig = await multipleDomainSwap.getStorageData(); 
        expect(multipleDomainSwapConfig.validUntil).toBe(blockchain.now! + 60 * 120 + 50);
        
        blockchain.now! = multipleDomainSwapConfig.validUntil;
        transactionRes = await multipleDomainSwap.sendExternalCancel()
        await checkSwapCancelled("offer has expired");
    });
});

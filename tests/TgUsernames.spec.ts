import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import { TonSimpleSale, TonSimpleSaleConfig } from '../wrappers/TonSimpleSale';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { DnsCollection, DnsCollectionConfig } from '../wrappers/DnsCollection';
import { Domain, DomainConfig } from '../wrappers/Domain';
import { getIndexByDomainName } from '../wrappers/helpers/dnsUtils';
import { Exceptions, MIN_PRICE_START_TIME, ONE_DAY, ONE_YEAR } from '../wrappers/helpers/constants';
import { jettonsToString } from '../wrappers/helpers/functions';
import { TgUsernamesCollection, TgUsernamesCollectionConfig } from '../wrappers/TgUsernamesCollection';

describe('TgUsernames', () => {
    let tgUsernamesCollectionCode: Cell;
    let tgUsernameCode: Cell;

    beforeAll(async () => {
        tgUsernamesCollectionCode = await compile('TgUsernamesCollection');
        tgUsernameCode = await compile('TgUsername');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let user: SandboxContract<TreasuryContract>;

    let tgUsernamesCollection: SandboxContract<TgUsernamesCollection>;
    let tgUsernamesCollectionConfig: TgUsernamesCollectionConfig;
    let tgUsername: SandboxContract<Domain>;

    let transactionRes: SendMessageResult;
    const publicKey = Buffer.from("6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8", 'hex');
    const secretKey = Buffer.from("a697139dab71a6ec0e2abf3232c4ebe2ba5c383c18a0229e9e3705aacfa3d9c96580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8", 'hex');

    const USERNAME = "test12345678";
    
    beforeAll(async () => {
        blockchain = await Blockchain.create();
        blockchain.now = MIN_PRICE_START_TIME;

        admin = await blockchain.treasury('admin');
        user = await blockchain.treasury('user');
        
        tgUsernamesCollectionConfig = {
            touched: true,
            subwalletId: 0,
            publicKey: 0x6580630b8e03d33193195e28fa60cff750c608dbb8a2dd9f1196425b353ee2c8n,
            content: beginCell().endCell(),
            itemCode: tgUsernameCode,
            fullDomain: "me\u0000t\u0000",
            royaltyParams: beginCell().storeUint(5, 16).storeUint(100, 16).storeAddress(admin.address).endCell()
        }
        tgUsernamesCollection = blockchain.openContract(TgUsernamesCollection.createFromConfig(tgUsernamesCollectionConfig, tgUsernamesCollectionCode));

        transactionRes = await tgUsernamesCollection.sendDeploy(admin.getSender(), toNano("0.05"));
        printTransactionFees(transactionRes.transactions);
        expect(transactionRes.transactions).toHaveTransaction({
            from: admin.address,
            to: tgUsernamesCollection.address,
            success: true,
        });
        console.log("tgUsernamesCollection deployed", tgUsernamesCollection.address);
    });

    it("should deploy tgUsername", async () => {
        transactionRes = await tgUsernamesCollection.sendStartAuction(
            admin.getSender(), 
            USERNAME, 
            tgUsernamesCollectionConfig, 
            secretKey, 
            toNano("5")
        );
        printTransactionFees(transactionRes.transactions);
    });
});

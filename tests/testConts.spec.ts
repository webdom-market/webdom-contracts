import { Blockchain, printTransactionFees, SandboxContract, SendMessageResult, TreasuryContract } from '@ton/sandbox';
import { Address, beginCell, Cell, toNano } from '@ton/core';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';
import { TestConts } from '../wrappers/testConts';

describe('TestConts', () => {
    let testContsCode: Cell;

    beforeAll(async () => {
        testContsCode = await compile('TestConts');
    });

    let blockchain: Blockchain;
    let admin: SandboxContract<TreasuryContract>;
    let testConts: SandboxContract<TestConts>;
    
    beforeEach(async () => {
        blockchain = await Blockchain.create();
        admin = await blockchain.treasury('admin');
        testConts = blockchain.openContract(TestConts.create(testContsCode));
        const res = await testConts.sendDeploy(admin.getSender(), toNano('0.02'));

        // const deployFunctionCell = await testConts.getDeployFunctionCell();
        // console.log(deployFunctionCell.toBoc().toString('hex'));
    });

    it('should deploy', async () => {
    });
});

import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Cell, toNano } from '@ton/core';
import { BalanceProbe } from '../../wrappers/BalanceProbe';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';

describe('getOriginalBalance: before or after storage fees', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('BalanceProbe');
    });

    it('compares originalBalance vs (preBalance + inValue) and the storage fee', async () => {
        const blockchain = await Blockchain.create();
        const deployer = await blockchain.treasury('deployer');

        const probe = blockchain.openContract(BalanceProbe.createFromConfig({}, code));
        await probe.sendDeploy(deployer.getSender(), toNano('5'));

        // Advance time a lot so the storage phase of the next tx collects a meaningful fee.
        blockchain.now = Math.floor(Date.now() / 1000) + 10 * 365 * 24 * 3600;

        // Balance held by the contract just BEFORE the ping transaction runs.
        const preBalance = (await blockchain.getContract(probe.address)).balance;

        const pingValue = toNano('1');
        const res = await probe.sendPing(deployer.getSender(), pingValue);

        // Pull the storage-phase fee that the ping transaction actually charged.
        const pingTx = res.transactions.find(
            (t) => t.inMessage?.info?.dest?.toString() === probe.address.toString(),
        )!;
        const desc: any = pingTx.description;
        const storageFee: bigint = desc.storagePhase?.storageFeesCollected ?? 0n;

        const { origBalance, inValue } = await probe.getProbe();

        const beforeStorageHypothesis = preBalance + pingValue; // storage NOT deducted yet
        const afterStorageHypothesis = preBalance + pingValue - storageFee; // storage deducted

        console.log('--- getOriginalBalance probe ---');
        console.log('preBalance       :', preBalance.toString());
        console.log('pingValue        :', pingValue.toString());
        console.log('inValue (in msg) :', inValue.toString());
        console.log('storageFee       :', storageFee.toString());
        console.log('origBalance      :', origBalance.toString());
        console.log('pre+in (before)  :', beforeStorageHypothesis.toString());
        console.log('pre+in-stor(after):', afterStorageHypothesis.toString());
        console.log('matches BEFORE   :', origBalance === beforeStorageHypothesis);
        console.log('matches AFTER    :', origBalance === afterStorageHypothesis);

        expect(storageFee).toBeGreaterThan(0n);
        expect(inValue).toBe(pingValue);
    });
});

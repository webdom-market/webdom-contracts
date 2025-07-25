import { toNano } from '@ton/core';
import { MultipleOffer } from '../wrappers/MultipleOffer';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const multipleOffer = provider.open(
        MultipleOffer.createFromConfig(
            {
                id: Math.floor(Math.random() * 10000),
                counter: 0,
            },
            await compile('MultipleOffer')
        )
    );

    await multipleOffer.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(multipleOffer.address);

    console.log('ID', await multipleOffer.getID());
}

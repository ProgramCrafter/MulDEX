import { toNano } from 'ton-core';
import { MultitokenDex } from '../wrappers/MultitokenDex';
import { NetworkProvider } from '@ton-community/blueprint';

export async function run(provider: NetworkProvider) {
    const multitokenDex = provider.open(await MultitokenDex.fromInit());

    await multitokenDex.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(multitokenDex.address);

    // run methods on `multitokenDex`
}

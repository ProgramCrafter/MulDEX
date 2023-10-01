import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { toNano } from 'ton-core';
import { MultitokenDex } from '../wrappers/MultitokenDex';
import '@ton-community/test-utils';

describe('MultitokenDex', () => {
    let blockchain: Blockchain;
    let multitokenDex: SandboxContract<MultitokenDex>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        multitokenDex = blockchain.openContract(await MultitokenDex.fromInit());

        const deployer = await blockchain.treasury('deployer');

        const deployResult = await multitokenDex.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: multitokenDex.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and multitokenDex are ready to use
    });
});

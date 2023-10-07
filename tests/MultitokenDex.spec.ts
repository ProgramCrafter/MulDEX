import { Address, Dictionary, OpenedContract, TupleBuilder, toNano } from 'ton-core';
import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { MultitokenDex } from '../wrappers/MultitokenDex';
import '@ton-community/test-utils';

describe('MultitokenDex', () => {
    let blockchain: Blockchain;
    let multitokenDex: SandboxContract<MultitokenDex>;
    const jettonMasters = [
        "EQAMcImLBgZHazWmradz51pI0uHZwvxMONlMQy0QwQTQInD5",
        "kQAbDiNBKXDn5l3AE8cx-j7zZneFITRRFM-FH-HfBJqsrTLh"
    ].map(elem => Address.parse(elem));

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        
        const deployer = await blockchain.treasury('deployer');

        multitokenDex = blockchain.openContract(
            await MultitokenDex.fromInit(1n, deployer.address, BigInt(jettonMasters.length)));

        const deployResult = await multitokenDex.send(deployer.getSender(),
            { value: toNano('0.05'), },
            { $$type: 'Deploy', queryId: 0n, });
        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: multitokenDex.address,
            deploy: true,
            success: true,
        });
    });

    it('should initialize', async () => {
        // owner
        const deployer = await blockchain.treasury('deployer');
        
        // args to get_wallet_address get-method
        let tuple = new TupleBuilder(); tuple.writeAddress(multitokenDex.address);
        let dict: Dictionary<Address, Address> = Dictionary.empty();
        
        // filling jetton wallets list
        for (let item of jettonMasters) {
            let get_result = blockchain.provider(item).get("get_wallet_address", tuple.build());
            dict.set(item, get_result.stack.readAddress());
        }
        
        const initResult = await multitokenDex.send(deployer.getSender(),
            { value: toNano('0.2'), bounce: false, },
            { $$type: 'DexDeploy', query_id: 12n, jetton_wallets: dict, });
        expect(initResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: multitokenDex.address,
            deploy: false,
            success: true
        });
    });
    
    it('should report zero balances', async () => {
        const swapBase = await multitokenDex.getGetSwapBase();
        expect(swapBase).toStrictEqual(0n);
    });
    
    it('should offer zero swap until funded', async () => {
        const offeredJettons = await multitokenDex.getCalcSwapByMasterAddrs(
            jettonMasters[0], jettonMasters[1], 1000000n);
        expect(offeredJettons).toStrictEqual(0n);
    });
});

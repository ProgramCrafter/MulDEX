import { Address, Cell, Dictionary, toNano } from 'ton-core';
import { MultitokenDex, sendDeploy } from '../wrappers/MultitokenDex';
import { NetworkProvider } from '@ton-community/blueprint';
import { inspect } from 'util';

export async function run(provider: NetworkProvider) {
    const multitokenDex = provider.open(await MultitokenDex.fromInit(BigInt(1), provider.sender().address!));


    await sendDeploy(multitokenDex, provider, ["EQAMcImLBgZHazWmradz51pI0uHZwvxMONlMQy0QwQTQInD5", "kQAbDiNBKXDn5l3AE8cx-j7zZneFITRRFM-FH-HfBJqsrTLh"].map(elem => Address.parse(elem)))

    await provider.waitForDeploy(multitokenDex.address);
    // run methods on `multitokenDex`
}

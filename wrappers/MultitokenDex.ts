import { Address, Dictionary, OpenedContract, TupleBuilder, toNano } from 'ton-core';
import { MultitokenDex } from '../build/MultitokenDex/tact_MultitokenDex';
import { NetworkProvider } from '@ton-community/blueprint';

export * from '../build/MultitokenDex/tact_MultitokenDex';

export async function sendDeploy(contract: OpenedContract<MultitokenDex>, provider: NetworkProvider, masters: Address[]) {
    let dict: Dictionary<Address, Address> = Dictionary.empty();
    let tuple = new TupleBuilder();
    tuple.writeAddress(contract.address);
    for (let item of masters) {
        dict.set(item, (await provider.provider(item).get("get_wallet_address", tuple.build())).stack.readAddress());
    }
    await contract.send(provider.sender(), {value: toNano("0.1"), bounce: false}, {$$type: 'DexDeploy', query_id: 12n, jetton_wallets: dict});
}
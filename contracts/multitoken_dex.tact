import "./imports/helper.fc";

@name(muldiv)
native mulDiv(a: Int, b: Int, c: Int): Int;

@name(fill_zeros)
native fillZeros(jetton_wallets: map<Address, Address>): map<Address, Int>;

message DexDeploy {
    query_id: Int as uint64;
    jetton_wallets: map<Address, Address>;
    assets: map<Address, Int>;
}

message(0x7362d09c) TokenNotification {
    query_id: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forward_payload: Slice as remaining;
}

message(0x0f8a7ea5) JettonTransfer {
    query_id: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address;
    custom_payload: Cell? = null;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining;
}

struct SystemInfo {
    id: Int as uint64;
    jetton_wallets: map<Address, Address>;
    assets: map<Address, Int>; // better to set type coins to values, but tact does not support it now :C
    owner_address: Address; // owner is not actually needed for current implementation, but let it be
}

contract MultitokenDex {
    const min_storage: Int = ton("0.05");
    const forward_ton_amount: Int = ton("0.000001");
    id: Int as uint64; // to create more than one pool
    jetton_wallets: map<Address, Address>;
    assets: map<Address, Int>;
    owner_address: Address; // owner is not actually needed for current implementation, but let it be
    
    init(id: Int, owner: Address) {
        self.id = id;
        self.owner_address = owner;
        self.assets = emptyMap();
        self.jetton_wallets = emptyMap(); 
    }

    receive(msg: DexDeploy) {
        require(sender() == self.owner_address, "Invalid sender");
        require(self.jetton_wallets.asCell() == null, "Already set");
        self.jetton_wallets = msg.jetton_wallets; // some jettons do not support TEP-89
        self.assets = fillZeros(msg.jetton_wallets);
        nativeReserve(self.min_storage, 2);
        self.notify(null);
    }
    
    receive(msg: TokenNotification) {
        // todo
        // let ctx: Context = context();
        // let old_balance_src: Int? = self.assets.get(ctx.sender);
        // let received: Int = msg.amount;
        
        // // unknown token
        // if (old_balance_src == null) {
        //     self.transferJettonTo(ctx.sender, self.owner_address,
        //         received, msg.query_id, "Unknown original jetton");
        //     return;
        // }
        
        // // insufficient value to process token
        // if (ctx.value <= ton("0.4")) {
        //     self.transferJettonTo(ctx.sender, msg.from, received,
        //         msg.query_id, "Insufficient value to process token");
        //     return;
        // }
        
        // let swap: Swap = msg.forwardPayload % Swap;
        // let other_jw: Address =
        //     self.jetton_wallets.get(swap.otherJettonMaster)!!;
        // let old_balance_dst: Int = self.assets.get(other_jw)!!;
        
        // let swap_value: Int = self.calcSwap(old_balance_src,
        //     old_balance_dst, received); // simple func received_token1 / token_1_balance * token2_balance
        
        // self.transferJettonTo(other_jw, msg.sender, swap_value, msg.query_id, "Swap completed");
        // self.assets.set(ctx.sender, old_balance_src + received);
        // self.assets.set(other_jw, old_balance_dst - swap_value);
    }

    fun transferJettonTo(jetton_wallet: Address, destination: Address, amount: Int, query_id: Int, message: String) {
        if (amount > 0) {
            send(SendParameters{
                to: jetton_wallet,
                value: 0,
                mode: 64,
                body: JettonTransfer{query_id: query_id, amount: amount, destination: destination, response_destination: destination, custom_payload: message.asComment(), forward_ton_amount: self.forward_ton_amount, forward_payload: emptySlice()}.toCell()
            });
        }
    }

    fun calcSwap(balance_token1: Int, balance_token2: Int, received_token1: Int): Int {
        return mulDiv(received_token1, balance_token2, balance_token1);
    }

    get fun get_system_info(): SystemInfo {
        return SystemInfo{id: self.id, jetton_wallets: self.jetton_wallets, assets: self.assets, owner_address: self.owner_address};
    }
}

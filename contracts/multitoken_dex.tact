import "./imports/helper.fc";



@name(muldiv)
native mulDiv(a: Int, b: Int, c: Int): Int;

@name(fill_zeros)
native fillZerosCheckLen(jetton_wallets: map<Address, Address>, want_len: Int): map<Address, Int>;



message DexDeploy {
    query_id: Int as uint64;
    jetton_wallets: map<Address, Address>;
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
    assets: map<Address, Int>;  // better to set type coins to values, but tact does not support it now :C
    owner_address: Address;
}

// swap#4a2663c4 other_jetton_master:MsgAddressInt other_jetton_min_expected:(VarUInteger 16) = Swap;
// the problem is that Tact doesn't support parsing slices as arbitrary structs



@interface("ton.experimental.pcrafter.multitokendex")
contract MultitokenDex {
    const forward_ton_amount: Int = ton("0.000001");
    
    id: Int as uint64;       // to create more than one pool
    owner_address: Address;  // owner is only required for initialization
    
    tokens_count: Int as uint16;
    jetton_wallets: map<Address, Address>;  // jetton master -> our wallet
    assets: map<Address, Int>;              // our jetton wallet -> balance
    swap_base: Int as uint128 = 0;          // base value for calculating swaps, == `sum(assets)`
    
    init(id: Int, owner: Address, tokens_count: Int) {
        self.id = id;
        self.owner_address = owner;
        self.tokens_count = tokens_count;
        self.assets = emptyMap();
        self.jetton_wallets = emptyMap();
    }

    receive(msg: DexDeploy) {
        require(sender() == self.owner_address, "Invalid sender");
        require(self.jetton_wallets.asCell() == null, "Already initialized");
        
        self.jetton_wallets = msg.jetton_wallets;
        // some jettons do not support TEP-89 (discovery), and even if all did, it would unnecessarily complicate transactions network
        
        self.assets = fillZerosCheckLen(msg.jetton_wallets, self.tokens_count);
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendRemainingValue,
            body: "Deployed".asComment()
        });
    }
    
    receive(msg: TokenNotification) {
        let ctx: Context = context();
        let old_balance_src: Int? = self.assets.get(ctx.sender);
        let received: Int = msg.amount;
        
        // unknown token
        if (old_balance_src == null) {
            self.transferJettonTo(ctx.sender, self.owner_address,
                received, msg.query_id, "Unknown original jetton");
            return;
        }
        
        // insufficient value to process token
        if (ctx.value <= ton("0.4")) {
            self.transferJettonTo(ctx.sender, msg.sender, received,
                msg.query_id, "Insufficient value to process token");
            return;
        }
        
        // let swap: Swap = msg.forward_payload % Swap;
        let /*mut*/ swap: Slice = msg.forward_payload;
        if (swap.loadUint(32) != 0x4a2663c4) {
            self.transferJettonTo(ctx.sender, msg.sender, received,
                msg.query_id, "Unknown operation");
            return;
        }
        let other_jetton_master: Address = swap.loadAddress();
        let other_jetton_min_expected: Int = swap.loadCoins();
        
        let other_jw: Address = self.jetton_wallets.get(other_jetton_master)!!;
        let old_balance_dst: Int = self.assets.get(other_jw)!!;
        if (other_jetton_min_expected >= old_balance_dst) {
            self.transferJettonTo(ctx.sender, msg.sender, received,
                msg.query_id, "Liquidity pool doesn't have enough funds");
            return;
        }
        // now, other_jetton_min_expected <= old_balance_dst - 1
        
        let swap_value: Int = self.calc_swap(old_balance_src!!, old_balance_dst, received);
        if (swap_value >= old_balance_dst) {  // safeguard against liquidity pool draining
            swap_value = old_balance_dst - 1; // still above other_jetton_min_expected, though we still check this next
        }
        if (swap_value < other_jetton_min_expected) {
            self.transferJettonTo(ctx.sender, msg.sender, received,
                msg.query_id, "Slippage protection: swap can't give requested count of tokens");
            return;
        }
        
        self.transferJettonTo(other_jw, msg.sender, swap_value, msg.query_id, "Swap completed");
        self.assets.set(ctx.sender, old_balance_src!! + received);
        self.assets.set(other_jw, old_balance_dst - swap_value);
        self.swap_base = self.swap_base + received - swap_value;
    }

    fun transferJettonTo(jetton_wallet: Address, destination: Address, amount: Int, query_id: Int, message: String) {
        if (amount > 0) {
            send(SendParameters{
                to: jetton_wallet,
                value: 0,
                mode: SendRemainingValue,
                body: JettonTransfer{query_id: query_id, amount: amount, destination: destination, response_destination: destination, custom_payload: message.asComment(), forward_ton_amount: self.forward_ton_amount, forward_payload: emptySlice()}.toCell()
            });
        }
    }

    fun calc_swap(had_token_src: Int, had_token_dst: Int, recv_token_src: Int): Int {
        // Swap maintains invariant
        // (balance1 * balance2 + balance1 * balance3 + ... + balance[n-1] * balance[n]) = const
        
        // It can be proven then that the swap is calculated as following:
        return mulDiv(recv_token_src, self.swap_base - had_token_src, self.swap_base + recv_token_src - had_token_dst);
        
        // for two tokens, essentially equivalent to
        // return mulDiv(recv_token_src, had_token_dst, had_token_src + recv_token_src);
    }
    
    

    get fun get_system_info(): SystemInfo {
        return SystemInfo{id: self.id, jetton_wallets: self.jetton_wallets, assets: self.assets, owner_address: self.owner_address};
    }
    
    get fun get_swap_base(): Int {
        return self.swap_base;
    }
    
    get fun calc_price_multiplied(jetton_wallet: Address, multiplier: Int): Int {
        let asset: Int = self.assets.get(jetton_wallet)!!;
        let v: Int = self.swap_base * (self.tokens_count - 1);
        return mulDiv(self.swap_base - asset, multiplier, v);
    }
    
    // get fun calc_all_prices_multiplied(multiplier: Int): map<Address, Int>
    //     Tact doesn't support iteration over maps, though
    
    get fun calc_swap_by_jw_addrs(jetton_src: Address, jetton_dst: Address, value_src: Int): Int {
        let asset_src: Int = self.assets.get(jetton_src)!!;
        let asset_dst: Int = self.assets.get(jetton_dst)!!;
        return self.calc_swap(asset_src, asset_dst, value_src);
    }
    
    get fun calc_swap_by_master_addrs(jetton_src: Address, jetton_dst: Address, value_src: Int): Int {
        let asset_src: Int = self.assets.get(self.jetton_wallets.get(jetton_src)!!)!!;
        let asset_dst: Int = self.assets.get(self.jetton_wallets.get(jetton_dst)!!)!!;
        return self.calc_swap(asset_src, asset_dst, value_src);
    }
}

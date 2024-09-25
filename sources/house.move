module suigar::house {
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::object_table::{ObjectTable};


    friend suigar::lootbox;
    friend suigar::coinflip;


    const EInsufficientBalance: u64 = 2;


    // Read table data here: https://forums.sui.io/t/read-a-move-table-object-by-using-typescript-sdk/44999

    struct House<phantom T0> has key, store {
        id: UID,
        balance: Balance<T0>,

        referee_table: ObjectTable<address, RefereeData<T0>>,
        referrer_table: ObjectTable<address, ReferrerData<T0>>,

        referrer_rewards_ratio: u64,
        referee_rewards_ratio: u64,
    }
    
    struct AdminCap has store, key {
        id: UID,
    }


    struct RefereeData<phantom T0> has key, store {
        id: UID,
        referrer: address,
        referee_balance: Balance<T0>,
    }

    struct ReferrerData<phantom T0> has key, store {
        id: UID,
        referrer_balance: Balance<T0>,
    }

  


    fun init(ctx: &mut TxContext) {
        
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));

        transfer::share_object(House<SUI> {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            referee_table: sui::object_table::new<address, RefereeData<SUI>>(ctx),
            referrer_table: sui::object_table::new<address, ReferrerData<SUI>>(ctx),
            referrer_rewards_ratio: 400,
            referee_rewards_ratio: 400,
        });

        

    }

    public fun create_house<T0>(
        _: &AdminCap, 
        coin: 0x2::coin::Coin<T0>, 
        referrer_rewards_ratio: u64,
        referee_rewards_ratio: u64,
        ctx: &mut TxContext,
        ) {

        let balance = 0x2::coin::into_balance<T0>(coin);
        transfer::share_object(House<T0> {
            id: object::new(ctx),
            balance: balance,
            referee_table: 0x2::object_table::new<address, RefereeData<T0>>(ctx),
            referrer_table: 0x2::object_table::new<address, ReferrerData<T0>>(ctx),
            referrer_rewards_ratio: referrer_rewards_ratio,
            referee_rewards_ratio: referee_rewards_ratio,
        });

    }

    public fun deposit<T0>(house: &mut House<T0>, coin: Coin<T0>) {
       coin::put<T0>(&mut house.balance, coin) 
    }

    public fun withdraw<T0>(_: &AdminCap, house: &mut House<T0>, amount: u64, ctx: &mut TxContext): Coin<T0> {
        coin::take<T0>(&mut house.balance, amount, ctx)
    }

    public(friend) fun take_fund_balance<T0>(house: &mut House<T0>, amount: u64): Balance<T0> {
        balance::split(&mut house.balance, amount)
    }

    public(friend) fun join_balance<T0>(house: &mut House<T0>, balance: Balance<T0>) {
        balance::join<T0>(&mut house.balance, balance);
    }

    public fun set_referer<T0>(house: &mut House<T0>, referrer: address, ctx: &mut TxContext) {
        
        let sender = 0x2::tx_context::sender(ctx);
        if (sender == referrer) {
            return
        };
        let referee_table = &mut house.referee_table;
        let referrer_table = &mut house.referrer_table;

        if (0x2::object_table::contains<address, RefereeData<T0>>(referee_table, sender)) {
            return
        };



        let referee_data = RefereeData {
            id: object::new(ctx),
            referrer: referrer,
            referee_balance: balance::zero<T0>(),
        };
        0x2::object_table::add<address, RefereeData<T0>>(referee_table, sender, referee_data);

         if (0x2::object_table::contains<address, ReferrerData<T0>>(referrer_table, referrer)) {
            return
        } else {
            let referrer_data = ReferrerData {
                id: object::new(ctx),
                referrer_balance: balance::zero<T0>(),
            };
            0x2::object_table::add<address, ReferrerData<T0>>(referrer_table, referrer, referrer_data);
        };
    }

    public(friend) fun distribute_referral_rewards<T0>(house: &mut House<T0>, amount: u64, player: address) {
        
        if (0x2::object_table::contains<address, RefereeData<T0>>(&house.referee_table, player) == true) {
        let referrer_rewards_ratio = house.referrer_rewards_ratio;
        let referee_rewards_ratio = house.referee_rewards_ratio;
        
        let referrer = 0x2::object_table::borrow<address, RefereeData<T0>>(&house.referee_table, player).referrer;


        let referrer_rewards_amount;

        if (referrer_rewards_ratio == 0) {
            referrer_rewards_amount = 0;
        } else {
            referrer_rewards_amount = std::u64::divide_and_round_up(amount, referrer_rewards_ratio);
        };
        
        let referee_rewards_amount;

        if (referee_rewards_ratio == 0) {
            referee_rewards_amount = 0;
        } else {
            referee_rewards_amount = std::u64::divide_and_round_up(amount, referee_rewards_ratio);
        };

        

        // test if there is enough money in the house
        assert!(balance::value(&house.balance) >= referrer_rewards_amount + referee_rewards_amount, EInsufficientBalance);

        let referrer_rewards_balance = take_fund_balance<T0>(house, referrer_rewards_amount);
        let referee_rewards_balance = take_fund_balance<T0>(house, referee_rewards_amount);

        let referee_data = 0x2::object_table::borrow_mut<address, RefereeData<T0>>(&mut house.referee_table, player);
        let referrer_data = 0x2::object_table::borrow_mut<address, ReferrerData<T0>>(&mut house.referrer_table, referrer);
        
        balance::join<T0>(&mut referee_data.referee_balance, referrer_rewards_balance);
        balance::join<T0>(&mut referrer_data.referrer_balance, referee_rewards_balance);
        };
    }

    public fun claim_referee_rewards<T0>(house: &mut House<T0>, ctx: &mut TxContext) {
        let sender = 0x2::tx_context::sender(ctx);
        let referee_table = &mut house.referee_table;

        if (0x2::object_table::contains<address, RefereeData<T0>>(referee_table, sender) == false) {
            return
        };

        let referee_data = 0x2::object_table::borrow_mut<address, RefereeData<T0>>(referee_table, sender);
        let referee_rewards = balance::withdraw_all<T0>(&mut referee_data.referee_balance);
        transfer::public_transfer(coin::from_balance(referee_rewards, ctx), sender);
    }

    public fun claim_referrer_rewards<T0>(house: &mut House<T0>, ctx: &mut TxContext) {
        let sender = 0x2::tx_context::sender(ctx);
        let referrer_table = &mut house.referrer_table;

        if (0x2::object_table::contains<address, ReferrerData<T0>>(referrer_table, sender) == false) {
            return
        };

        let referrer_data = 0x2::object_table::borrow_mut<address, ReferrerData<T0>>(referrer_table, sender);
        let referrer_rewards = balance::withdraw_all<T0>(&mut referrer_data.referrer_balance);
        transfer::public_transfer(coin::from_balance(referrer_rewards, ctx), sender);
    }

    public fun edit_referal_ratios<T0>(_: &AdminCap, house: &mut House<T0>, referrer_rewards_ratio: u64, referee_rewards_ratio: u64) {
        house.referrer_rewards_ratio = referrer_rewards_ratio;
        house.referee_rewards_ratio = referee_rewards_ratio;
    }
}

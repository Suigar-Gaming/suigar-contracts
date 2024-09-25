module suigar::lootbox {
    use std::vector;

    use sui::coin;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{ Balance };
    use sui::vec_map::{Self, VecMap};
    use sui::random::{Self, Random};
    use std::string::{String};

    use suigar::house::{Self, House, AdminCap};
    use suigar::events;


    // Config ====================================================
    const TotalPropability: u64 = 100_000_000;

    // Error codes ====================================================

    const EInvalidInput: u64 = 3;
    const EInsufficientPayment: u64 = 4;
    const EInvalidLooBoxId: u64 = 5;
    const EInvalidPurchasedLooBoxId: u64 = 6;
    const ELootboxNotPlayable: u64 = 7;

    //=================================================================
    // Module Structs
    //=================================================================

    /// Main struct
    struct LootboxGame<phantom T0> has key {
        id: UID,
        lootboxes: VecMap<ID, LootBox>,
        purchased_lootboxes: VecMap<ID, PurchasedLootBox<T0>>
    }

    struct LootBox has key, store {
        id: UID,
        price: u64,
        title: String,
        is_playable: bool,
        reward_amounts: vector<u64>,
        reward_probabilities: vector<u64>,
    }

    struct PurchasedLootBox<phantom T0> has key, store {
        id: UID,
        lootbox_id: ID,
        buyer: address,
        fund: Balance<T0>,
    }

    //=================================================================
    // Functions
    //=================================================================

    // Init ======================================================
    fun init(ctx: &mut TxContext) {

        transfer::share_object(
            LootboxGame<SUI> {
                id: object::new(ctx),
                lootboxes: vec_map::empty(),
                purchased_lootboxes: vec_map::empty(),
            }
        );
    }

    // Modifiers ======================================================

    /// Create a lootbox
    public fun create_lootbox<T0>(
        _: &AdminCap,
        lootbox_game: &mut LootboxGame<T0>,
        price: u64,
        title: String,
        reward_amounts: vector<u64>,
        reward_probabilities: vector<u64>,
        ctx: &mut TxContext
    ) {
        // Assertion
        assert_reward(
            reward_amounts,
            reward_probabilities
        );

        let id = object::new(ctx);
        let lootbox = LootBox {
            id,
            is_playable: true,
            price,
            title,
            reward_amounts,
            reward_probabilities,
        };
        vec_map::insert(
            &mut lootbox_game.lootboxes,
            object::uid_to_inner(&lootbox.id),
            lootbox
        );
    }

    public fun edit_lootbox<T0>(
        _: &AdminCap,
        lootbox_game: &mut LootboxGame<T0>,
        lootbox_id: ID,
        lootbox_is_playable: bool,
        price: u64,
        title: String,
        reward_amounts: vector<u64>,
        reward_probabilities: vector<u64>,
    ) {
        // Assertion
        assert_reward(
            reward_amounts,
            reward_probabilities
        );

        let lootbox = get_mut_lootbox(
            &mut lootbox_game.lootboxes,
            &lootbox_id
        );

        lootbox.price = price;
        lootbox.reward_amounts = reward_amounts;
        lootbox.reward_probabilities = reward_probabilities;
        lootbox.is_playable = lootbox_is_playable;
        lootbox.title = title;
    }

    public fun purchase_lootbox<T0>(
        lootbox_game: &mut LootboxGame<T0>,
        house: &mut House<T0>,
        lootbox_id: ID,
        payment_coin: &mut coin::Coin<T0>,
        ctx: &mut TxContext
    ) {
        // Get lootbox
        let lootbox = get_mut_lootbox(
            &mut lootbox_game.lootboxes,
            &lootbox_id
        );

        // Assertion
        assert!(
            coin::value(payment_coin) >= lootbox.price,
            EInsufficientPayment
        );

        assert!(
            lootbox.is_playable == true,
            ELootboxNotPlayable
        );

        // Take payment
        let coin = coin::split(payment_coin, lootbox.price, ctx);
        let amount = coin::value(&coin);
        house::deposit(house, coin);

        // Create purchased lootbox
        let max_reward = *vector::borrow(
            &lootbox.reward_amounts,
            vector::length(&lootbox.reward_amounts) - 1
        );
        let id = object::new(ctx);
        let purchased_lootbox = PurchasedLootBox {
            id,
            lootbox_id: object::uid_to_inner(&lootbox.id),
            buyer: tx_context::sender(ctx),
            fund: house::take_fund_balance(house, max_reward)
        };

        house::distribute_referral_rewards(
            house,
            amount,
            tx_context::sender(ctx)
        );

        events::emit_purchased_lootbox_event(
            object::uid_to_inner(&lootbox.id),
            object::uid_to_inner(&purchased_lootbox.id),
            tx_context::sender(ctx),
        );

        vec_map::insert(
            &mut lootbox_game.purchased_lootboxes,
            object::uid_to_inner(&purchased_lootbox.id),
            purchased_lootbox
        );

    }

    entry fun reveal_lootbox_onchain_randomness<T0>(
        lootbox_game: &mut LootboxGame<T0>,
        house: &mut House<T0>,
        purchased_lootbox_id: ID,
        r: &Random,
        ctx: &mut TxContext
    ) {
        // Assertion
        assert!(
            vec_map::contains(
                &lootbox_game.purchased_lootboxes,
                &purchased_lootbox_id
            ),
            EInvalidPurchasedLooBoxId
        );

        let (_, purchased_lootbox) = vec_map::remove(
            &mut lootbox_game.purchased_lootboxes,
            &purchased_lootbox_id
        );
        let PurchasedLootBox {id, lootbox_id, buyer, fund} = purchased_lootbox;

        let lootbox = get_lootbox(
            &lootbox_game.lootboxes,
            &lootbox_id
        );

        let generator = random::new_generator(r, ctx);
        let rand = random::generate_u64_in_range(&mut generator, 0, TotalPropability);
        let reward_index = get_reward_index(rand, &lootbox.reward_probabilities);
        let reward = *vector::borrow(
            &lootbox.reward_amounts,
            reward_index
        );

        let reward_coin = coin::take(&mut fund, reward, ctx);
        house::join_balance(house, fund);

        transfer::public_transfer(reward_coin, buyer);

        events::emit_revealed_lootbox_event(
            object::uid_to_inner(&id),
            lootbox_id,
            buyer,
            reward
        );

        object::delete(id);

    }

    fun assert_reward(
        amounts: vector<u64>,
        probabilities: vector<u64>
    ) {
        assert!(
            vector::length(&amounts) == vector::length(&probabilities),
            EInvalidInput
        );
        let sum = 0;
        let i = 0;
        while (i < vector::length(&probabilities)) {
            sum = sum + *vector::borrow(&probabilities, i);
            i = i + 1;
        };
        assert!(
            sum == TotalPropability,
            EInvalidInput
        );

        let prev = 0;
        i = 0;
        while (i < vector::length(&amounts)) {
            let cur = *vector::borrow(&amounts, i);
            assert!(prev < cur, EInvalidInput);
            prev = cur;
            i = i + 1;
        };
    }

    // Accessors ======================================================
    fun get_mut_lootbox(
        lootbox: &mut VecMap<ID, LootBox>,
        id: &ID
    ): &mut LootBox {
        assert!(
            vec_map::contains(lootbox, id),
            EInvalidLooBoxId
        );
        vec_map::get_mut(lootbox, id)
    }

    fun get_lootbox(lootbox: &VecMap<ID, LootBox>, id: &ID): &LootBox {
        assert!(
            vec_map::contains(lootbox, id),
            EInvalidLooBoxId
        );
        vec_map::get(lootbox, id)
    }

    fun get_reward_index(
        rand: u64,
        probabilities: &vector<u64>
    ): u64 {
        let sum = 0;
        let i = 0;
        while (i < vector::length(probabilities)) {
            sum = sum + *vector::borrow(probabilities, i);
            if (rand < sum) {return i};
            i = i + 1;
        };
        vector::length(probabilities) - 1
    }

}

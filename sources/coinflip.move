#[allow(unused_const)]
module suigar::coinflip {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::random::{Self, Random};
    use std::uq32_32::{Self};

    use suigar::house::{Self, House, AdminCap};

    //=================================================================
    // Constants
    //=================================================================

    // Config =========================================================
    const TotalProbability: u64 = 100_000_000;

    // Error codes ====================================================
    const EInsufficientBet: u64 = 4;
    const EInvalidBetId: u64 = 5;
    const EInvalidMaxBetConfig: u64 = 6;
    const EInvalidThresholdConfig: u64 = 7;

    //=================================================================
    // Module Structs
    //=================================================================

    /// Main struct
    struct CoinFlipGame<phantom T0> has key {
        id: UID,
        max_bet: u64,
        threshold: u64,
        bets: VecMap<ID, Bet<T0>>,
    }

    struct Bet<phantom T0> has key, store {
        id: UID,
        gambler: address,
        fund: Balance<T0>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            CoinFlipGame<SUI> {
                id: object::new(ctx),
                max_bet: 51_000_000_000,
                threshold: 53_000_000,
                bets: vec_map::empty(),
            }
        );
    }

    public fun create_coinflip_game<T0>(
        _: &AdminCap,
        max_bet: u64,
        threshold: u64,
        ctx: &mut TxContext
    ) {
        assert_valid_config(max_bet, threshold);
        transfer::share_object(
            CoinFlipGame<T0> {
                id: object::new(ctx),
                max_bet,
                threshold,
                bets: vec_map::empty(),
            }
        );
    }

    public fun edit_coinflip_game<T0>(
        _: &AdminCap,
        coinflip: &mut CoinFlipGame<T0>,
        max_bet: u64,
        threshold: u64,
    ) {
        assert_valid_config(max_bet, threshold);
        coinflip.max_bet = max_bet;
        coinflip.threshold = threshold;
    }

    // Modifiers ======================================================
    fun assert_valid_config(max_bet: u64, threshold: u64) {
        let min_threshold = TotalProbability / 2;
        let max_threshold = 6 * TotalProbability / 10;
        assert!(max_bet > 0, EInvalidMaxBetConfig);
        assert!(threshold >= min_threshold && threshold <= max_threshold, EInvalidThresholdConfig);
    }

    // public fun bet<T0>(
    //     coinflip: &mut CoinFlipGame<T0>,
    //     house: &mut House<T0>,
    //     bet_coin: Coin<T0>,
    //     ctx: &mut TxContext
    // ) {
    //     // Assertion
    //     let amount = coin::value(&bet_coin);

    //     assert!(
    //         amount <= coinflip.max_bet,
    //         EInsufficientBet
    //     );

    //     // Take payment
    //     let max_reward = amount * 2;
    //     house::deposit(house, bet_coin);

    //     let bet = Bet {
    //         id: object::new(ctx),
    //         gambler: tx_context::sender(ctx),
    //         fund: house::take_fund_balance<T0>(house, max_reward)
    //     };

    //      house::distribute_referral_rewards(
    //         house,
    //         amount,
    //         tx_context::sender(ctx)
    //     );
    //     // Emit the event
    //     suigar::events::emit_bet_event(
    //         object::uid_to_inner(&bet.id),
    //         amount,
    //         tx_context::sender(ctx)
    //     );

    //     vec_map::insert(
    //         &mut coinflip.bets,
    //         object::uid_to_inner(&bet.id),
    //         bet
    //     );
    // }

    // entry fun reveal_bet_onchain_randomness<T0>(
    //     coinflip: &mut CoinFlipGame<T0>,
    //     house: &mut House<T0>,
    //     bet_id: ID,
    //     r: &Random,
    //     ctx: &TxContext
    // ) {
    //     // Assertion
    //     assert!(
    //         vec_map::contains(&coinflip.bets, &bet_id),
    //         EInvalidBetId
    //     );

    //     let (_, bet) = vec_map::remove(&mut coinflip.bets, &bet_id);
    //     let Bet {id, gambler, fund} = bet;

    //     let generator = random::new_generator(r, ctx);
    //     let rand = random::generate_u64_in_range(&mut generator, 0, TotalProbability);
    //     let win = rand > coinflip.threshold;

    //     let reward = if (win) {balance::value(&fund)} else { 0 };

    //     if (win) {
    //         transfer::public_transfer(
    //             coin::from_balance(fund, ctx),
    //             gambler
    //         );
    //         house::join_balance(house, balance::zero<T0>()); // used to avoid random hack due to gas cost for happy scenarios
    //     } else {
    //         house::join_balance(house, fund);
    //     };

    //     suigar::events::emit_revealed_bet_event(bet_id, win, reward, gambler);
    //     object::delete(id);
    // }

    entry fun place_bet_and_reveal_onchain_randomness<T0>(
        coinflip: &CoinFlipGame<T0>,
        house: &mut House<T0>,
        bet_coin: Coin<T0>,
        r: &Random,
        ctx: &mut TxContext
    ) {
         // Assertion
        let amount = coin::value(&bet_coin);
        let sender = tx_context::sender(ctx);

        assert!(
            amount <= coinflip.max_bet,
            EInsufficientBet
        );

        assert!(
            amount >= 100_000_000,
            EInsufficientBet
        );

        // Take payment
        let max_reward = amount * 2;
        house::deposit(house, bet_coin);

        let fund = house::take_fund_balance<T0>(house, max_reward);

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        house::distribute_referral_rewards(
            house,
            amount,
            sender
        );

        let generator = random::new_generator(r, ctx);
        let rand = random::generate_u64_in_range(&mut generator, 0, TotalProbability);
        let win = rand > coinflip.threshold;


        let reward = if (win) {balance::value(&fund)} else { 0 };

        if (win) {
            transfer::public_transfer(
                coin::from_balance(fund, ctx),
                sender
            );
            house::join_balance(house, balance::zero<T0>()); // used to avoid random hack due to gas cost for happy scenarios
        } else {
            house::join_balance(house, fund);
        };

        let payout_multiplier = if (win) {uq32_32::from_int(2)} else {uq32_32::from_int(0)};

        suigar::events::emit_revealed_coinflip_bet_event(
            id,
            win,
            amount,
            payout_multiplier,
            reward,
            sender
        );
        object::delete(uid);

    }
}

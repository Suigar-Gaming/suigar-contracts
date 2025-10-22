#[allow(unused_const)]
module suigar::limbo {
    use sui::transfer;
    use sui::sui::SUI;
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::random::{Self, Random};
    use std::uq32_32::{Self, UQ32_32};

    use suigar::house::{Self, House, AdminCap};

    //=================================================================
    // Constants
    //=================================================================

    // 18,446,744,073,709,551,615 max u64
    // Config =========================================================
    const MaxMultiplier: u64 = 1_000_000;
    // Error codes ====================================================
    const EInvalidBetAmount: u64 = 4;
    const EInvalidBetId: u64 = 5;
    const EInvalidTargetMultiplier: u64 = 6;
    const EInvalidNumberOfBets: u64 = 7;
    const EInvalidRtpConfig: u64 = 8;

    //=================================================================
    // Module Structs
    //=================================================================

    /// Main struct
    struct LimboGame<phantom T0> has key {
        id: UID,
        min_bet: u64,
        max_bet: u64,
        max_payout: u64,
        min_target_multiplier: UQ32_32,
        max_target_multiplier: UQ32_32,
        max_number_of_bets: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
        bets: VecMap<ID, Bet<T0>>,
    }

    struct Bet<phantom T0> has key, store {
        id: UID,
        gambler: address,
        target_multiplier: UQ32_32,
        number_of_bets: u8,
        total_stake_value: u64,
        fund: Balance<T0>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            LimboGame<SUI> {
                id: object::new(ctx),
                min_bet: 100_000_000, // 0.1 SUI
                max_bet: 1_000_000_000_000, // 1000 SUI
                max_payout: 100_000_000_000, // 100 SUI
                min_target_multiplier: uq32_32::from_quotient(101, 100),
                max_target_multiplier: uq32_32::from_int(100),
                max_number_of_bets: 10,
                min_rtp: uq32_32::from_quotient(97, 100),
                max_rtp: uq32_32::from_quotient(97, 100),
                bets: vec_map::empty(),
            }
        );
    }

    public fun create_limbo_game<T0>(
        _: &AdminCap,
        min_bet: u64,
        max_bet: u64,
        max_payout: u64,
        min_target_multiplier: UQ32_32,
        max_target_multiplier: UQ32_32,
        max_number_of_bets: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
        ctx: &mut TxContext
    ) {
        assert_valid_config(
            min_bet,
            max_bet,
            max_payout,
            min_target_multiplier,
            max_target_multiplier,
            max_number_of_bets,
            min_rtp,
            max_rtp,
        );
        transfer::share_object(
            LimboGame<T0> {
                id: object::new(ctx),
                min_bet,
                max_bet,
                max_payout,
                min_target_multiplier,
                max_target_multiplier,
                max_number_of_bets,
                min_rtp,
                max_rtp,
                bets: vec_map::empty(),
            }
        );
    }

    public fun edit_limbo_game<T0>(
        _: &AdminCap,
        limbo_game: &mut LimboGame<T0>,
        min_bet: u64,
        max_bet: u64,
        max_payout: u64,
        min_target_multiplier: UQ32_32,
        max_target_multiplier: UQ32_32,
        max_number_of_bets: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
    ) {
        assert_valid_config(
            min_bet,
            max_bet,
            max_payout,
            min_target_multiplier,
            max_target_multiplier,
            max_number_of_bets,
            min_rtp,
            max_rtp,
        );
        limbo_game.min_bet = min_bet;
        limbo_game.max_bet = max_bet;
        limbo_game.max_payout = max_payout;
        limbo_game.min_target_multiplier = min_target_multiplier;
        limbo_game.max_target_multiplier = max_target_multiplier;
        limbo_game.max_number_of_bets = max_number_of_bets;
        limbo_game.min_rtp = min_rtp;
        limbo_game.max_rtp = max_rtp;
    }

    // Modifiers ======================================================

    fun assert_valid_config(
        min_bet: u64,
        max_bet: u64,
        max_payout: u64,
        min_target_multiplier: UQ32_32,
        max_target_multiplier: UQ32_32,
        max_number_of_bets: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
    ) {
        assert!(min_bet > 0, EInvalidBetAmount);
        assert!(max_bet >= min_bet, EInvalidBetAmount);
        assert!(max_number_of_bets > 0, EInvalidNumberOfBets);
        assert!(
            uq32_32::le(min_target_multiplier, max_target_multiplier),
            EInvalidTargetMultiplier
        );
        assert!(
            uq32_32::ge(min_rtp, uq32_32::from_quotient(80, 100)),
            EInvalidRtpConfig
        );
        assert!(
            uq32_32::le(min_rtp, max_rtp),
            EInvalidRtpConfig
        );
    }

    fun place_bet<T0>(
        limbo_game: &mut LimboGame<T0>,
        house: &mut House<T0>,
        bet_coin: Coin<T0>,
        target_multiplier: UQ32_32,
        number_of_bets: u8,
        ctx: &mut TxContext
    ): ID {
        let amount = coin::value(&bet_coin);
        assert!(
            number_of_bets > 0,
            EInvalidNumberOfBets
        );
        let number_of_bets_u64 = number_of_bets as u64;
        let amount_per_bet = amount / number_of_bets_u64;
        let max_reward = uq32_32::int_mul(amount, target_multiplier);
        let max_reward_per_bet = max_reward / number_of_bets_u64;


        assert!(
            number_of_bets <= limbo_game.max_number_of_bets,
            EInvalidNumberOfBets
        );

        assert!(
            max_reward_per_bet <= limbo_game.max_payout,
            EInvalidBetAmount
        );

        assert!(
            amount_per_bet >= limbo_game.min_bet,
            EInvalidBetAmount
        );

        assert!(
            amount_per_bet <= limbo_game.max_bet,
            EInvalidBetAmount
        );

        assert!(
            uq32_32::ge(
                target_multiplier,
                limbo_game.min_target_multiplier
            ),
            EInvalidTargetMultiplier
        );

        assert!(
            uq32_32::le(
                target_multiplier,
                limbo_game.max_target_multiplier
            ),
            EInvalidTargetMultiplier
        );

        house::deposit(house, bet_coin);

        let bet = Bet {
            id: object::new(ctx),
            gambler: tx_context::sender(ctx),
            target_multiplier,
            number_of_bets,
            total_stake_value: amount,
            fund: house::take_fund_balance<T0>(house, max_reward)
        };

        house::distribute_referral_rewards(
            house,
            amount,
            tx_context::sender(ctx)
        );
        // Emit the event
        suigar::events::emit_limbo_bet_event(
            object::uid_to_inner(&bet.id),
            amount,
            target_multiplier,
            number_of_bets,
            tx_context::sender(ctx)
        );

        let bet_id = object::uid_to_inner(&bet.id);
        vec_map::insert(&mut limbo_game.bets, bet_id, bet);
        return bet_id
    }

    fun reveal_bet<T0>(
        limbo_game: &mut LimboGame<T0>,
        house: &mut House<T0>,
        bet_id: ID,
        r: &Random,
        ctx: &mut TxContext
    ) {
        // Assertion
        assert!(
            vec_map::contains(&limbo_game.bets, &bet_id),
            EInvalidBetId
        );

        let (_, bet) = vec_map::remove(&mut limbo_game.bets, &bet_id);
        let Bet {
            id,
            gambler,
            target_multiplier,
            number_of_bets,
            total_stake_value,
            fund
        } = bet;

        let stake_per_bet = total_stake_value / (number_of_bets as u64);
        let generator = random::new_generator(r, ctx);

        let total_payout_amount = 0;
        let payout_per_bet_if_win = balance::value(&fund) / (number_of_bets as u64);
        let payouts_history: vector<u64> = vector::empty();
        let win_history: vector<bool> = vector::empty();
        let multipliers_history: vector<UQ32_32> = vector::empty();

        let edge: u64 = MaxMultiplier; 

        let i: u8 = 0;
        while (i < number_of_bets) {
            let rand = random::generate_u64_in_range(&mut generator, 0, edge - 1);

            let random_multiplier = uq32_32::from_quotient(edge, rand + 1);
            
            // actual_rtp = max_rtp - ((target_multiplier - 1) / (max_multiplier - 1)) * (min_max - max_min)
            let actual_rtp = uq32_32::sub(
                limbo_game.max_rtp,
                uq32_32::mul(
                    uq32_32::div(
                        uq32_32::sub(target_multiplier, uq32_32::from_int(1)),
                        uq32_32::sub(limbo_game.max_target_multiplier, uq32_32::from_int(1))
                    ),
                    uq32_32::sub(limbo_game.max_rtp, limbo_game.min_rtp)
                )
            );

            random_multiplier = uq32_32::mul(random_multiplier, actual_rtp);
            
            let win = uq32_32::le(
                target_multiplier,
                random_multiplier
            );

            let reward = if (win) { payout_per_bet_if_win } else { 0 };
            vector::push_back(&mut payouts_history, reward);
            vector::push_back(&mut win_history, win);
            vector::push_back(
                &mut multipliers_history,
                random_multiplier
            );
            total_payout_amount = total_payout_amount + reward;
            i = i + 1;

        };

        let balance_coin = coin::from_balance(fund, ctx);
        let balance_coin_mut = &mut balance_coin;
        let payout_coin: Coin<T0> = coin::split(
            balance_coin_mut,
            total_payout_amount,
            ctx
        );

        // transfer the payout coins to the player
        transfer::public_transfer(payout_coin, gambler);

        // add the rest into the bank
        house::deposit(house, balance_coin);

        while (vector::length(&payouts_history) > 0) {
            let reward = vector::pop_back(&mut payouts_history);
            let win = vector::pop_back(&mut win_history);
            let multiplier = vector::pop_back(&mut multipliers_history);

            let payout_multiplier = if (win) {target_multiplier} else {uq32_32::from_int(0)};

            suigar::events::emit_revealed_limbo_bet_event(
                bet_id,
                stake_per_bet,
                payout_multiplier,
                target_multiplier,
                multiplier,
                win,
                reward,
                gambler
            );
        };
        object::delete(id);
    }

    // public fun bet<T0>(
    //     limbo_game: &mut LimboGame<T0>,
    //     house: &mut House<T0>,
    //     bet_coin: Coin<T0>,
    //     target_multiplier_numerator: u64,
    //     target_multiplier_denominator: u64,
    //     number_of_bets: u8,
    //     ctx: &mut TxContext
    // ) {
    //     let target_multiplier = uq32_32::from_quotient(
    //         target_multiplier_numerator,
    //         target_multiplier_denominator
    //     );
    //     place_bet(
    //         limbo_game,
    //         house,
    //         bet_coin,
    //         target_multiplier,
    //         number_of_bets,
    //         ctx
    //     );
    // }

    // entry fun reveal_bet_onchain_randomness<T0>(
    //     limbo_game: &mut LimboGame<T0>,
    //     house: &mut House<T0>,
    //     bet_id: ID,
    //     r: &Random,
    //     ctx: &mut TxContext
    // ) {
    //     reveal_bet(limbo_game, house, bet_id, r, ctx);
    // }

    entry fun bet_and_reveal_onchain_randomness<T0>(
        limbo_game: &mut LimboGame<T0>,
        house: &mut House<T0>,
        bet_coin: Coin<T0>,
        target_multiplier_numerator: u64,
        target_multiplier_denominator: u64,
        number_of_bets: u8,
        r: &Random,
        ctx: &mut TxContext
    ) {
        let target_multiplier = uq32_32::from_quotient(
            target_multiplier_numerator,
            target_multiplier_denominator
        );
        
        let bet_id = place_bet(
            limbo_game,
            house,
            bet_coin,
            target_multiplier,
            number_of_bets,
            ctx
        );
        reveal_bet(limbo_game, house, bet_id, r, ctx);
    }
}

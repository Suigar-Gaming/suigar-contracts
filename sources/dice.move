#[allow(unused_const)]
module suigar::dice {
    use sui::transfer;
    use std::vector;
    use sui::sui::SUI;
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

    // Config =========================================================
    const MaxRange: u64 = 100_000_000;
    const DefaultMinBetThreshold: u64 = 6_000_000; // 6% of the max range

    // Error codes ====================================================
    const EInsufficientBet: u64 = 4;
    const EInvalidBetId: u64 = 5;
    const EInvalidNumberOfDices: u64 = 6;
    const EInvalidBetThreshold: u64 = 7;
    const EInvalidConfig: u64 = 8;
    const EInvalidRtpConfig: u64 = 9;

    //=================================================================
    // Module Structs
    //=================================================================

    /// Main struct
    struct DiceGame<phantom T0> has key {
        id: UID,
        min_bet: u64,
        max_bet: u64,
        min_bet_threshold: u64, // used to limit the maximum payout
        max_number_of_dices: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
        bets: VecMap<ID, Bet<T0>>,
    }

    struct Bet<phantom T0> has key, store {
        id: UID,
        gambler: address,
        bet_threshold: u64,
        roll_under: bool,
        number_of_dices: u8,
        total_stake_value: u64,
        fund: Balance<T0>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            DiceGame<SUI> {
                id: object::new(ctx),
                min_bet: 100_000_000, // 0.1 SUI
                max_bet: 50_000_000_000, // 50 SUI
                max_number_of_dices: 10,
                min_bet_threshold: DefaultMinBetThreshold,
                min_rtp: uq32_32::from_quotient(95, 100),
                max_rtp: uq32_32::from_quotient(98, 100),
                bets: vec_map::empty(),
            }
        );
    }

    public fun create_dice_game<T0>(
        _: &AdminCap,
        min_bet: u64,
        max_bet: u64,
        min_bet_threshold: u64,
        max_number_of_dices: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
        ctx: &mut TxContext
    ) {
        assert_valid_config(
            min_bet,
            max_bet,
            min_bet_threshold,
            max_number_of_dices,
            min_rtp,
            max_rtp,
        );
        transfer::share_object(
            DiceGame<T0> {
                id: object::new(ctx),
                min_bet,
                max_bet,
                min_bet_threshold,
                max_number_of_dices,
                min_rtp,
                max_rtp,
                bets: vec_map::empty(),
            }
        );
    }

    public fun edit_dice_game<T0>(
        _: &AdminCap,
        dice_game: &mut DiceGame<T0>,
        max_bet: u64,
        min_bet_threshold: u64,
        max_number_of_dices: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
    ) {
        assert_valid_config(
            dice_game.min_bet,
            max_bet,
            min_bet_threshold,
            max_number_of_dices,
            min_rtp,
            max_rtp,
        );
        dice_game.max_bet = max_bet;
        dice_game.min_bet_threshold = min_bet_threshold;
        dice_game.min_rtp = min_rtp;
        dice_game.max_rtp = max_rtp;
        dice_game.max_number_of_dices = max_number_of_dices;
    }

    fun assert_valid_config(
        min_bet: u64,
        max_bet: u64,
        min_bet_threshold: u64,
        max_number_of_dices: u8,
        min_rtp: UQ32_32,
        max_rtp: UQ32_32,
    ) {
        assert!(min_bet > 0, EInvalidConfig);
        assert!(max_bet >= min_bet, EInvalidConfig);
        assert!(min_bet_threshold > 0 && min_bet_threshold < MaxRange, EInvalidConfig);
        assert!(max_number_of_dices > 0, EInvalidConfig);
        assert!(
            uq32_32::le(min_rtp, max_rtp),
            EInvalidRtpConfig
        );
        assert!(
            uq32_32::ge(min_rtp, uq32_32::from_quotient(80, 100)),
            EInvalidRtpConfig
        );
    }

    // Modifiers ======================================================
    fun place_bet<T0>(
        dice_game: &mut DiceGame<T0>,
        house: &mut House<T0>,
        bet_coin: Coin<T0>,
        bet_threshold: u64,
        roll_under: bool,
        number_of_dices: u8,
        ctx: &mut TxContext
    ): ID {
        // Assertion
        let amount = coin::value(&bet_coin);

        assert!(
            number_of_dices > 0,
            EInvalidNumberOfDices
        );

        assert!(
            number_of_dices <= dice_game.max_number_of_dices,
            EInvalidNumberOfDices
        );

        let amount_per_dice = amount / (number_of_dices as u64);

        assert!(
            amount_per_dice <= dice_game.max_bet,
            EInsufficientBet
        );

        assert!(
            amount_per_dice >= dice_game.min_bet,
            EInsufficientBet
        );

        assert!(
            bet_threshold < MaxRange,
            EInvalidBetThreshold
        );

        if (roll_under) {
            assert!(
                bet_threshold >= dice_game.min_bet_threshold,
                EInvalidBetThreshold
            );
        } else {
            assert!(
                bet_threshold <= MaxRange - dice_game.min_bet_threshold,
                EInvalidBetThreshold
            );
        };

        

        // Take payment
        
        let bet_multiplier = if (roll_under) {
            uq32_32::from_quotient(MaxRange, bet_threshold)
        } else {
            uq32_32::from_quotient(MaxRange, MaxRange - bet_threshold)
        };
        
        // ACTUAL_RTP = MIN_RTP + (player_bet / MAX_RANGE) * (MAX_RTP - MIN_RTP) \in [MIN_RTP, MAX_RTP]
        let actual_rtp = uq32_32::add(
            dice_game.min_rtp,
            uq32_32::mul(
                if (roll_under) {
                    uq32_32::from_quotient(bet_threshold, MaxRange)
                } else {
                    uq32_32::from_quotient(MaxRange - bet_threshold, MaxRange)
                },
                uq32_32::sub(dice_game.max_rtp, dice_game.min_rtp)
            )
        );

        let max_reward = uq32_32::int_mul(
            amount,
            uq32_32::mul(bet_multiplier, actual_rtp)
        );
        house::deposit(house, bet_coin);

        let bet = Bet {
            id: object::new(ctx),
            gambler: tx_context::sender(ctx),
            bet_threshold,
            roll_under,
            number_of_dices,
            total_stake_value: amount,
            fund: house::take_fund_balance<T0>(house, max_reward)
        };

        house::distribute_referral_rewards(
            house,
            amount,
            tx_context::sender(ctx)
        );
        // Emit the event
        suigar::events::emit_dice_bet_event(
            object::uid_to_inner(&bet.id),
            amount,
            bet_threshold,
            roll_under,
            number_of_dices,
            tx_context::sender(ctx)
        );
        let bet_id = object::uid_to_inner(&bet.id);
        vec_map::insert(&mut dice_game.bets, bet_id, bet);
        return bet_id
    }

    fun reveal_bet<T0>(
        dice_game: &mut DiceGame<T0>,
        house: &mut House<T0>,
        bet_id: ID,
        r: &Random,
        ctx: &mut TxContext
    ) {
        assert!(
            vec_map::contains(&dice_game.bets, &bet_id),
            EInvalidBetId
        );

        let (_, bet) = vec_map::remove(&mut dice_game.bets, &bet_id);
        let Bet {
            id,
            gambler,
            bet_threshold,
            roll_under,
            number_of_dices,
            total_stake_value,
            fund
        } = bet;

        let generator = random::new_generator(r, ctx);

        let total_payout_amount = 0;
        let payout_per_dice_if_win = balance::value(&fund) / (number_of_dices as u64);
        let payouts_history: vector<u64> = vector::empty();
        let win_history: vector<bool> = vector::empty();
        let value_history: vector<u64> = vector::empty();
        let stake_per_dice = total_stake_value / (number_of_dices as u64);

        let i = 0;

        while (i < number_of_dices) {
            let rand = random::generate_u64_in_range(&mut generator, 0, MaxRange);
            let win = if (roll_under) { rand <= bet_threshold } else { rand >= bet_threshold };
            let reward = if (win) { payout_per_dice_if_win } else { 0 };
            vector::push_back(&mut payouts_history, reward);
            vector::push_back(&mut win_history, win);
            vector::push_back(&mut value_history, rand);
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

        // edit code below : emit multiple events
        while (vector::length(&payouts_history) > 0) {
            let reward = vector::pop_back(&mut payouts_history);
            let win = vector::pop_back(&mut win_history);
            let value = vector::pop_back(&mut value_history);
            
            let payout_multiplier = if (win) {uq32_32::from_quotient(reward, stake_per_dice)} else {uq32_32::from_int(0)};

            suigar::events::emit_revealed_dice_bet_event(
                bet_id,
                win,
                stake_per_dice,
                payout_multiplier,
                bet_threshold,
                roll_under,
                value,
                reward,
                gambler
            );
        };

        object::delete(id);
    }

    // public fun bet<T0>(
    //     dice_game: &mut DiceGame<T0>,
    //     house: &mut House<T0>,
    //     bet_coin: Coin<T0>,
    //     bet_threshold: u64,
    //     roll_under: bool,
    //     number_of_dices: u8,
    //     ctx: &mut TxContext
    // ) {
    //     place_bet(
    //         dice_game,
    //         house,
    //         bet_coin,
    //         bet_threshold,
    //         roll_under,
    //         number_of_dices,
    //         ctx
    //     );
    // }

    // entry fun reveal_bet_onchain_randomness<T0>(
    //     dice_game: &mut DiceGame<T0>,
    //     house: &mut House<T0>,
    //     bet_id: ID,
    //     r: &Random,
    //     ctx: &mut TxContext
    // ) {
    //     reveal_bet(dice_game, house, bet_id, r, ctx);
    // }

    entry fun bet_and_reveal_onchain_randomness<T0>(
        dice_game: &mut DiceGame<T0>,
        house: &mut House<T0>,
        bet_coin: Coin<T0>,
        bet_threshold: u64,
        roll_under: bool,
        number_of_dices: u8,
        r: &Random,
        ctx: &mut TxContext
    ) {

        let bet_id = place_bet(
            dice_game,
            house,
            bet_coin,
            bet_threshold,
            roll_under,
            number_of_dices,
            ctx
        );
        reveal_bet(dice_game, house, bet_id, r, ctx);
    }
}

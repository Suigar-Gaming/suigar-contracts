module suigar::events {

    use sui::object::{ID};
    use sui::event;
    use std::string::{Self};
    use std::uq32_32::{UQ32_32};
    
    friend suigar::house;
    friend suigar::lootbox;
    friend suigar::coinflip;
    friend suigar::nft;
    friend suigar::dice;
    friend suigar::limbo;
    friend suigar::plinko;


    struct PurchasedLootBoxEvent has copy, drop {
        lootbox_id: ID,
        purchased_lootbox_id: ID,
        buyer: address,
    }

    struct RevealedLootBoxEvent has copy, drop {
        purchased_lootbox_id: ID,
        lootbox_id: ID,
        buyer: address,
        reward: u64,
    }

    struct LootboxRevealedEvent has copy, drop {
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        lootbox_id: ID,
        gambler: address,
        reward: u64,
    }

    struct BetEvent has copy, drop {
        bet_id: ID,
        amount: u64,
        gambler: address,
    }

    struct RevealedBetEvent has copy, drop {
        bet_id: ID,
        win: bool,
        reward: u64,
        gambler: address,
    }

    struct CoinFlipBetEvent has copy, drop {
        bet_id: ID,
        amount: u64,
        gambler: address,
    }

    struct CoinFlipRevealedEvent has copy, drop {
        bet_id: ID,
        win: bool,
        stake: u64,
        payout_multiplier: UQ32_32,
        reward: u64,
        gambler: address,
    }
    
    
    
    
    struct DiceBetEvent has copy, drop {
        bet_id: ID,
        amount: u64,
        bet_threshold: u64,
        roll_under: bool,
        number_of_dices: u8,
        gambler: address,
    }

    struct RevealedDiceBetEvent has copy, drop {
        bet_id: ID,
        win: bool,
        stake: u64,
        payout_multiplier: UQ32_32,
        bet_threshold: u64,
        roll_under: bool,
        random_number: u64,
        reward: u64,
        gambler: address,
    }

    struct LimboBetEvent has copy, drop {
        bet_id: ID,
        amount: u64,
        target_multiplier: UQ32_32,
        number_of_bets: u8,
        gambler: address,
    }

    struct LimboRevealedEvent has copy, drop {
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        target_multiplier: UQ32_32,
        multiplier: UQ32_32,
        win: bool,
        reward: u64,
        gambler: address,
    }

    struct PlinkoBetEvent has copy, drop {
        bet_id: ID,
        amount: u64,
        number_of_balls: u8,
        total_stake_value: u64,
        plinko_config_number: u8,
        number_of_rows: u8,
        gambler: address,
    }

    struct PlinkoRevealedEvent has copy, drop {
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        multiplier_index: u8,
        reward: u64,
        plinko_config_number: u8,
        number_of_rows: u8,
        gambler: address,
    }


    struct NFTMinted has copy, drop {
        object_id: ID,
        creator: address,
        name: string::String,
    }

    struct RefereeRewardsClaimedEvent has copy, drop {
        referee_rewards: u64,
    }

    struct ReferrerRewardsClaimedEvent has copy, drop {
        referrer_rewards: u64,
    }


    public(friend) fun emit_referee_rewards_claimed_event(
        referee_rewards: u64
    ) {
        let event = RefereeRewardsClaimedEvent { referee_rewards, };
        event::emit<RefereeRewardsClaimedEvent>(event);
    }

    public(friend) fun emit_referrer_rewards_claimed_event(
        referrer_rewards: u64
    ) {
        let event = ReferrerRewardsClaimedEvent { referrer_rewards, };
        event::emit<ReferrerRewardsClaimedEvent>(event);
    }

    public(friend) fun emit_purchased_lootbox_event(
        lootbox_id: ID,
        purchased_lootbox_id: ID,
        buyer: address
    ) {
        let event = PurchasedLootBoxEvent {
            lootbox_id,
            purchased_lootbox_id,
            buyer,
        };
        event::emit<PurchasedLootBoxEvent>(event);
    }

    public(friend) fun emit_revealed_lootbox_event(
        purchased_lootbox_id: ID,
        lootbox_id: ID,
        buyer: address,
        reward: u64
    ) {
        let event = RevealedLootBoxEvent {
            purchased_lootbox_id,
            lootbox_id,
            buyer,
            reward,
        };
        event::emit<RevealedLootBoxEvent>(event);
    }

    public(friend) fun emit_lootbox_revealed_event(
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        lootbox_id: ID,
        gambler: address,
        reward: u64,
    ) {
        let event    = LootboxRevealedEvent {
            bet_id,
            stake,
            payout_multiplier,
            lootbox_id,
            gambler,
            reward,
        };
        event::emit<LootboxRevealedEvent>(event);
    }

    public(friend) fun emit_bet_event(
        bet_id: ID,
        amount: u64,
        gambler: address
    ) {
        let event = BetEvent {bet_id, amount, gambler,};
        event::emit<BetEvent>(event);
    }

    public(friend) fun emit_coinflip_bet_event(
        bet_id: ID,
        amount: u64,
        gambler: address
    ) {
        let event = CoinFlipBetEvent {bet_id, amount, gambler,};
        event::emit<CoinFlipBetEvent>(event);
    }

    public(friend) fun emit_revealed_coinflip_bet_event(
        bet_id: ID,
        win: bool,
        stake: u64,
        payout_multiplier: UQ32_32,
        reward: u64,
        gambler: address
    ) {
        let event = CoinFlipRevealedEvent {bet_id, win, stake, payout_multiplier, reward, gambler,};
        event::emit<CoinFlipRevealedEvent>(event);
    }

    public(friend) fun emit_dice_bet_event(
        bet_id: ID,
        amount: u64,
        bet_threshold: u64,
        roll_under: bool,
        number_of_dices: u8,
        gambler: address
    ) {
        let event = DiceBetEvent {bet_id, amount, bet_threshold, roll_under, number_of_dices, gambler,};
        event::emit<DiceBetEvent>(event);
    }

    public(friend) fun emit_revealed_dice_bet_event(
        bet_id: ID,
        win: bool,
        stake: u64,
        payout_multiplier: UQ32_32,
        bet_threshold: u64,
        roll_under: bool,
        random_number: u64,
        reward: u64,
        gambler: address
    ) {
        let event = RevealedDiceBetEvent {bet_id, win, stake, payout_multiplier, bet_threshold, roll_under, random_number, reward, gambler,};
        event::emit<RevealedDiceBetEvent>(event);
    }

    public(friend) fun emit_limbo_bet_event(
        bet_id: ID,
        amount: u64,
        target_multiplier: UQ32_32,
        number_of_bets: u8,
        gambler: address
    ) {
        let event = LimboBetEvent {bet_id, amount, target_multiplier, number_of_bets, gambler,};
        event::emit<LimboBetEvent>(event);
    }

    public(friend) fun emit_revealed_limbo_bet_event(
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        target_multiplier: UQ32_32,
        multiplier: UQ32_32,
        win: bool,
        reward: u64,
        gambler: address
    ) {
        let event = LimboRevealedEvent {bet_id, stake, payout_multiplier, target_multiplier, multiplier, win, reward, gambler,};
        event::emit<LimboRevealedEvent>(event);
    }

    public(friend) fun emit_plinko_bet_event(
        bet_id: ID,
        amount: u64,
        number_of_balls: u8,
        total_stake_value: u64,
        plinko_config_number: u8,
        number_of_rows: u8,
        gambler: address
    ) {
        let event: PlinkoBetEvent = PlinkoBetEvent {bet_id, amount, number_of_balls, total_stake_value, plinko_config_number, number_of_rows, gambler,};
        event::emit<PlinkoBetEvent>(event);
    }

    public(friend) fun emit_plinko_revealed_event(
        bet_id: ID,
        stake: u64,
        payout_multiplier: UQ32_32,
        multiplier_index: u8,
        reward: u64,
        plinko_config_number: u8,
        number_of_rows: u8,
        gambler: address
    ) {
        let event = PlinkoRevealedEvent {bet_id, stake, payout_multiplier, multiplier_index, reward, plinko_config_number, number_of_rows, gambler,};
        event::emit<PlinkoRevealedEvent>(event);
    }

    public(friend) fun emit_revealed_bet_event(
        bet_id: ID,
        win: bool,
        reward: u64,
        gambler: address
    ) {
        let event = RevealedBetEvent {bet_id, win, reward, gambler,};
        event::emit<RevealedBetEvent>(event);
    }

    public(friend) fun emit_nft_minted_event(
        object_id: ID,
        creator: address,
        name: string::String
    ) {
        let event = NFTMinted {object_id, creator, name,};
        event::emit<NFTMinted>(event);
    }
}

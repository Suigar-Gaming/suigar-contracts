module suigar::events {

    use sui::object::{ID};
    use sui::event;
    use std::string::{Self};

    friend suigar::lootbox;
    friend suigar::coinflip;
    friend suigar::nft;


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

    struct NFTMinted has copy, drop {
        object_id: ID,
        creator: address,
        name: string::String,
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

    public(friend) fun emit_bet_event(
        bet_id: ID,
        amount: u64,
        gambler: address
    ) {
        let event = BetEvent {bet_id, amount, gambler,};
        event::emit<BetEvent>(event);
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

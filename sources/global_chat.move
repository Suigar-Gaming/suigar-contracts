#[allow(unused_const)]
module suigar::global_chat {
    use std::string::{Self, String};
    use std::vector;

    use sui::event;
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};

    //=================================================================
    // Constants
    //=================================================================

    // Error codes ====================================================
    const E_INVALID_MAX_MSG_AMOUNT: u64 = 100;
    const E_INVALID_MAX_MSG_LENGTH: u64 = 101;
    const E_INVALID_TEXT_LENGTH: u64 = 102;

    //=================================================================
    // Module Structs
    //=================================================================

    struct ChatRoom has key, store {
        id: UID,
        name: String, // name/title
        description: String, // description/rules/welcome message/etc
        max_msg_amount: u64, // maximum amount of messages this chat room can hold
        max_msg_length: u64, // maximum length (in characters) of any given chat message
        last_index: u64, // indicates the position of the newest ChatMessage in `messages`
        messages: vector<ChatMessage>,
    }

    struct ChatMessage has store, drop {
        timestamp: u64, // user time from their browser
        author: address,
        text: String,
        // reply: u64, // distance of an older message to which this message is replying (0 = not a reply)
    }

    // Event Structs ==================================================
    struct NewMessageEvent has copy, drop {
        room_id: ID,
        author: address,
        text: String,
        timestamp: u64
    }

    //=================================================================
    // Functions
    //=================================================================

    // Init ======================================================
    fun init(ctx: &mut TxContext) {
        create(b"Global", b"Suigar global on-chain chat", 10000, 10000, ctx);
    }

    // Modifiers ======================================================
    /* Core logic */
    public fun create(
        name: vector<u8>,
        description: vector<u8>,
        max_msg_amount: u64,
        max_msg_length: u64,
        ctx: &mut TxContext)
    {
        // assert!(max_msg_amount >= 1 && max_msg_amount <= 400, E_INVALID_MAX_MSG_AMOUNT);
        // assert!(max_msg_length >= 1 && max_msg_length <= 1000, E_INVALID_MAX_MSG_LENGTH);
        let chat = ChatRoom {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            max_msg_amount,
            max_msg_length,
            last_index: max_msg_amount - 1,
            messages: vector::empty(),
        };
        transfer::share_object(chat);
    }

    public fun add_message(
        chat: &mut ChatRoom,
        timestamp: u64,
        text: vector<u8>,
        // reply: u64,
        ctx: &mut TxContext)
    {
        let text_len = vector::length(&text);
        assert!(text_len > 0 && text_len <= chat.max_msg_length, E_INVALID_TEXT_LENGTH);

        // Add the new message to the end of the vector
        let newMessage = ChatMessage {
            timestamp,
            author: tx_context::sender(ctx),
            text: string::utf8(text),
        };
        vector::push_back(&mut chat.messages, newMessage);
        let event = NewMessageEvent {
            room_id: object::uid_to_inner(&chat.id),
            author: tx_context::sender(ctx),
            text: string::utf8(text),
            timestamp
        };

        // Wrap around by moving the new message to the current index (replacing the oldest message)
        chat.last_index = (chat.last_index + 1) % chat.max_msg_amount;
        if ( vector::length(&chat.messages) > chat.max_msg_amount ) {
            vector::swap_remove(&mut chat.messages, chat.last_index);
        };
        event::emit(event);
    }

    /* Accessors */

    #[test_only]
    public fun messages(room: &ChatRoom): &vector<ChatMessage> {
        &room.messages
    }

    #[test_only]
    public fun message_text(message: &ChatMessage): &String {
        &message.text
    }
}

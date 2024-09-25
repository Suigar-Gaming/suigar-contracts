#[allow(unused_const)]
module suigar::nft {
    use std::string::{Self, utf8, String};

    use sui::package;
    use sui::display;
    use sui::tx_context::{Self, TxContext};

    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::url::{Self, Url};
    use sui::object::{Self, ID, UID};
    use sui::vec_map::{Self, VecMap};

    use suigar::house::{Self, House, AdminCap};

    //=================================================================
    // Constants
    //=================================================================

    // Error codes ====================================================
    const ESpecIdNotFound: u64 = 4;
    const ESpecIdNotAvailable: u64 = 5;
    const EInsufficientPayment: u64 = 6;

    //=================================================================
    // Module Structs
    //=================================================================

    struct Factory has key {
        id: UID,
        specs: VecMap<ID, Spec>,
    }

    struct Spec has key, store {
        id: UID,
        name: String,
        description: String,
        url: Url,
        supply: u64,
        available: u64,
        price: u64
    }

    struct Nft has key, store {
        id: UID,
        spec_id: ID,
        name: String,
        description: String,
        url: Url,
        image_url: Url,
    }

    /// One-Time-Witness for the module.
    struct NFT has drop {}

    //=================================================================
    // Functions
    //=================================================================

    // Init ======================================================
    fun init(otw: NFT, ctx: &mut TxContext) {

        transfer::share_object(
            Factory {
                id: object::new(ctx),
                specs: vec_map::empty(),
            }
        );

        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            // For `name` one can use the `Hero.name` property
            utf8(b"{name}"),
            // For `link` one can build a URL using an `id` property
            utf8(b"{url}"),
            // For `image_url` use an IPFS template + `image_url` property.
            utf8(b"{image_url}"),
            // Description is static for all `Hero` objects.
            utf8(
                b"{description}"
            ),
            // Project URL is usually static
            utf8(b"https://suigar.com"),
            // Creator field can be any
            utf8(b"Suigar Team"),
        ];

        let publisher = package::claim(otw, ctx);

        let display = display::new_with_fields<Nft>(&publisher, keys, values, ctx);

        // Commit first version of `Display` to apply changes.
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));

    }

    // Modifiers ======================================================

    public fun create_spec(
        _: &AdminCap,
        factory: &mut Factory,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        supply: u64,
        price: u64,
        ctx: &mut TxContext
    ) {
        let s = Spec {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            supply,
            available: supply,
            price,
        };
        vec_map::insert(
            &mut factory.specs,
            object::uid_to_inner(&s.id),
            s
        );
    }

    public fun mint_to_sender(
        factory: &mut Factory,
        house: &mut House<SUI>,
        spec_id: ID,
        payment_coin: Coin<SUI>,
        ctx: &mut TxContext
    ): suigar::nft::Nft {
        assert!(
            vec_map::contains(&factory.specs, &spec_id),
            ESpecIdNotFound
        );
        let s = vec_map::get_mut(&mut factory.specs, &spec_id);
        assert!(s.available != 0, ESpecIdNotAvailable);
        s.available = s.available - 1;

        assert!(
            coin::value(&payment_coin) >= s.price,
            EInsufficientPayment
        );
        house::deposit(house, payment_coin);

        let nft = Nft {
            id: object::new(ctx),
            spec_id,
            name: s.name,
            description: s.description,
            url: s.url,
            image_url: s.url,
        };

        suigar::events::emit_nft_minted_event(
            object::id(&nft),
            tx_context::sender(ctx),
            nft.name
        );
        nft

    }

    /// Permanently delete `nft`
    public fun burn(nft: Nft, _: &mut TxContext) {
        let Nft {
            id,
            spec_id: _,
            name: _,
            description: _,
            url: _,
            image_url: _
        } = nft;
        object::delete(id)
    }
}

#[allow(unused_const)]
module suigar::plinko {
    // === Imports ===
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::vec_map::{Self, VecMap};
    use sui::balance::{Balance};
    use sui::sui::SUI;
    use std::uq32_32::{Self, UQ32_32};
    use sui::random::{Random};

    use suigar::house::{Self, House, AdminCap};
    use suigar::math::{pow};

    // === Errors ===
    const EStakeTooLow: u64 = 0;
    const EStakeTooHigh: u64 = 1;
    const EInvalidBlsSig: u64 = 2;
    const EInsufficientHouseBalance: u64 = 5;
    const EGameDoesNotExist: u64 = 6;
    const EInvalidBetId: u64 = 7;
    const EInvalidNumberOfBalls: u64 = 8;
    const EInvalidPlinkoConfigNumber: u64 = 9;
    const EVectorIsEmpty: u64 = 10;
    const EInvalidMultipliersLength: u64 = 11;
    const EPlinkoConfigNotPlayable: u64 = 12;

    // === Structs ===

    struct PlinkoConfig<phantom T0> has store {
        num_rows: u8,
        multipliers: vector<UQ32_32>,
        min_bet: u64,
        max_bet: u64,
        is_playable: bool,
    }

    struct PlinkoGame<phantom T0> has key, store {
        id: UID,
        min_bet: u64,
        max_bet: u64,
        max_number_of_balls: u8,
        bets: VecMap<ID, Bet<T0>>,
        configs: VecMap<u8, PlinkoConfig<T0>>,
    }

    struct Bet<phantom T0> has key, store {
        id: UID,
        gambler: address,
        number_of_balls: u8,
        total_stake_value: u64,
        fund: Balance<T0>,
        plinko_config_number: u8,
    }


    fun private_initialize_plinko_configs<T0>(game: &mut PlinkoGame<T0>) {

        private_create_plinko_config_and_add_to_game(
            game,
            6,
            vector[
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(3, 2),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(1, 2),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(3, 2),
                uq32_32::from_quotient(4, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            0
        );
        private_create_plinko_config_and_add_to_game(
            game,
            6,
            vector[
                uq32_32::from_quotient(6, 1),
                uq32_32::from_quotient(9, 5),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(2, 5),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(9, 5),
                uq32_32::from_quotient(6, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            1
        );
        private_create_plinko_config_and_add_to_game(
            game,
            6,
            vector[
                uq32_32::from_quotient(8, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(3, 5),
                uq32_32::from_quotient(1, 5),
                uq32_32::from_quotient(3, 5),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(8, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            2
        );

        private_create_plinko_config_and_add_to_game(
            game,
            7,
            vector[
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(7, 5),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(7, 5),
                uq32_32::from_quotient(5, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            3
        );
        private_create_plinko_config_and_add_to_game(
            game,
            7,
            vector[
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(1, 2),
                uq32_32::from_quotient(1, 2),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(10, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            4
        );
        private_create_plinko_config_and_add_to_game(
            game,
            7,
            vector[
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(29, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(1, 5),
                uq32_32::from_quotient(1, 5),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(29, 10),
                uq32_32::from_quotient(20, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            5
        );

        private_create_plinko_config_and_add_to_game(
            game,
            8,
            vector[
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(1, 2),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(5, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            6
        );
        private_create_plinko_config_and_add_to_game(
            game,
            8,
            vector[
                uq32_32::from_quotient(11, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(2, 5),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(11, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            7
        );
        private_create_plinko_config_and_add_to_game(
            game,
            8,
            vector[
                uq32_32::from_quotient(26, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(15, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(15, 10),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(26, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            8
        );
  


        private_create_plinko_config_and_add_to_game(
            game,
            9,
            vector[
                uq32_32::from_quotient(51, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(15, 10),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(1, 1),
                uq32_32::from_quotient(15, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(51, 10),
            ],
            100_000_000,
            50_000_000_000,
            true,
            9
        );
        private_create_plinko_config_and_add_to_game(
            game,
            9,
            vector[
                uq32_32::from_quotient(16, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(16, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            10
        );
        private_create_plinko_config_and_add_to_game(
            game,
            9,
            vector[
                uq32_32::from_quotient(45, 1),
                uq32_32::from_quotient(6, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(6, 1),
                uq32_32::from_quotient(45, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            11
        );




        private_create_plinko_config_and_add_to_game(
            game,
            10,
            vector[
                uq32_32::from_quotient(8, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(8, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            12
        );
        private_create_plinko_config_and_add_to_game(
            game,
            10,
            vector[
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(4, 10),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(20, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            13
        );
        private_create_plinko_config_and_add_to_game(
            game,
            10,
            vector[
                uq32_32::from_quotient(65, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(65, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            14
        );
        private_create_plinko_config_and_add_to_game(
            game,
            11,
            vector[
                uq32_32::from_quotient(84, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(84, 10),
            ],
            100_000_000,
            50_000_000_000,
            true,
            15
        );
        private_create_plinko_config_and_add_to_game(
            game,
            11,
            vector[
                uq32_32::from_quotient(24, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(17, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(17, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(24, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            16
        );
        private_create_plinko_config_and_add_to_game(
            game,
            11,
            vector[
                uq32_32::from_quotient(100, 1),
                uq32_32::from_quotient(14, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(4, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(4, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(14, 1),
                uq32_32::from_quotient(100, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            17
        );
        private_create_plinko_config_and_add_to_game(
            game,
            12,
            vector[
                uq32_32::from_quotient(9, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(9, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            18
        );
        private_create_plinko_config_and_add_to_game(
            game,
            12,
            vector[
                uq32_32::from_quotient(30, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(35, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(6, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(35, 10),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(30, 1),
            ],
            100_000_000,
            50_000_000_000,
            true,
            19
        );
        private_create_plinko_config_and_add_to_game(
            game,
            12,
            vector[
                uq32_32::from_quotient(150, 1),
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(8, 1),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(8, 1),
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(150, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            20
        );

        private_create_plinko_config_and_add_to_game(
            game,
            13,
            vector[
                uq32_32::from_quotient(8, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(12, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(12, 10),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(8, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            21
        );
        private_create_plinko_config_and_add_to_game(
            game,
            13,
            vector[
                uq32_32::from_quotient(40, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(4, 10),
                uq32_32::from_quotient(4, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(40, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            22
        );
        private_create_plinko_config_and_add_to_game(
            game,
            13,
            vector[
                uq32_32::from_quotient(220, 1),
                uq32_32::from_quotient(33, 1),
                uq32_32::from_quotient(11, 1),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(11, 1),
                uq32_32::from_quotient(33, 1),
                uq32_32::from_quotient(220, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            23
        );

        private_create_plinko_config_and_add_to_game(
            game,
            14,
            vector[
                uq32_32::from_quotient(7, 1),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(14, 10),
                uq32_32::from_quotient(16, 10),
                uq32_32::from_quotient(4, 1),
                uq32_32::from_quotient(7, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            24
        );
        private_create_plinko_config_and_add_to_game(
            game,
            14,
            vector[
                uq32_32::from_quotient(50, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(50, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            25
        );
        private_create_plinko_config_and_add_to_game(
            game,
            14,
            vector[
                uq32_32::from_quotient(400, 1),
                uq32_32::from_quotient(50, 1),
                uq32_32::from_quotient(17, 1),
                uq32_32::from_quotient(50, 10),
                uq32_32::from_quotient(19, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(19, 10),
                uq32_32::from_quotient(50, 10),
                uq32_32::from_quotient(17, 1),
                uq32_32::from_quotient(50, 1),
                uq32_32::from_quotient(400, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            26
        );


        private_create_plinko_config_and_add_to_game(
            game,
            15,
            vector[
                uq32_32::from_quotient(11, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(7, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(3, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(11, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            27
        );
        private_create_plinko_config_and_add_to_game(
            game,
            15,
            vector[
                uq32_32::from_quotient(80, 1),
                uq32_32::from_quotient(15, 1),
                uq32_32::from_quotient(12, 1),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(12, 1),
                uq32_32::from_quotient(15, 1),
                uq32_32::from_quotient(80, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            28
        );
        private_create_plinko_config_and_add_to_game(
            game,
            15,
            vector[
                uq32_32::from_quotient(600, 1),
                uq32_32::from_quotient(80, 1),
                uq32_32::from_quotient(23, 1),
                uq32_32::from_quotient(80, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(80, 10),
                uq32_32::from_quotient(23, 1),
                uq32_32::from_quotient(80, 1),
                uq32_32::from_quotient(600, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            29
        );
        private_create_plinko_config_and_add_to_game(
            game,
            16,
            vector[
                uq32_32::from_quotient(12, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(12, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(9, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(11, 10),
                uq32_32::from_quotient(12, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(2, 1),
                uq32_32::from_quotient(5, 1),
                uq32_32::from_quotient(12, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            30
        );
        private_create_plinko_config_and_add_to_game(
            game,
            16,
            vector[
                uq32_32::from_quotient(100, 1),
                uq32_32::from_quotient(40, 1),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(50, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(3, 10),
                uq32_32::from_quotient(5, 10),
                uq32_32::from_quotient(10, 10),
                uq32_32::from_quotient(13, 10),
                uq32_32::from_quotient(30, 10),
                uq32_32::from_quotient(50, 10),
                uq32_32::from_quotient(10, 1),
                uq32_32::from_quotient(40, 1),
                uq32_32::from_quotient(100, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            31
        );
        private_create_plinko_config_and_add_to_game(
            game,
            16,
            vector[
                uq32_32::from_quotient(1000, 1),
                uq32_32::from_quotient(110, 1),
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(90, 10),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(2, 10),
                uq32_32::from_quotient(20, 10),
                uq32_32::from_quotient(40, 10),
                uq32_32::from_quotient(90, 10),
                uq32_32::from_quotient(20, 1),
                uq32_32::from_quotient(110, 1),
                uq32_32::from_quotient(1000, 1),
            ],
            100_000_000,
            50_000_000_000,
            false,
            32
        );

    }

    public fun initialize_plinko_configs<T0>(_: &AdminCap, plinko_game: &mut PlinkoGame<T0>, _ctx: &mut TxContext) {
        private_initialize_plinko_configs(plinko_game);
    }

    fun init(ctx: &mut TxContext) {
        
        let first_plinko_game = PlinkoGame<SUI> {
                id: object::new(ctx),
                min_bet: 100_000_000, // 0.1 SUI
                max_bet: 50_000_000_000, // 50 SUI
                max_number_of_balls: 10,
                bets: vec_map::empty(),
                configs: vec_map::empty(),
            };

        private_initialize_plinko_configs(&mut first_plinko_game);



        transfer::share_object(
            first_plinko_game
        );
    }

    public fun create_plinko_game<T0>(
        _: &AdminCap,
        min_bet: u64,
        max_bet: u64,
        max_number_of_balls: u8,
        ctx: &mut TxContext
    ) {
        transfer::share_object(
            PlinkoGame<T0> {
                id: object::new(ctx),
                min_bet,
                max_bet,
                max_number_of_balls,
                bets: vec_map::empty(),
                configs: vec_map::empty(),
            }
        );
    }

    public fun edit_plinko_game<T0>(
        _: &AdminCap,
        plinko_game: &mut PlinkoGame<T0>,
        min_bet: u64,
        max_bet: u64,
        max_number_of_balls: u8,
    ) {
        plinko_game.min_bet = min_bet;
        plinko_game.max_bet = max_bet;
        plinko_game.max_number_of_balls = max_number_of_balls;
    }

    public fun edit_plinko_config<T0>(
        _: &AdminCap,
        plinko_game: &mut PlinkoGame<T0>,
        plinko_config_number: u8,
        num_rows: u8,
        multipliers: vector<UQ32_32>,
        min_bet: u64,
        max_bet: u64,
        is_playable: bool,
    ) {
        assert!(vector::length(&multipliers) == (num_rows as u64) + 1, EInvalidMultipliersLength);
        let plinko_config: &mut PlinkoConfig<T0> = vec_map::get_mut(&mut plinko_game.configs, &plinko_config_number);
        plinko_config.num_rows = num_rows;
        plinko_config.multipliers = multipliers;
        plinko_config.min_bet = min_bet;
        plinko_config.max_bet = max_bet;
        plinko_config.is_playable = is_playable;
    }

    public fun set_plinko_config_playable<T0>(
        _: &AdminCap,
        plinko_game: &mut PlinkoGame<T0>,
        plinko_config_number: u8,
        is_playable: bool,
    ) {
        let plinko_config: &mut PlinkoConfig<T0> = vec_map::get_mut(&mut plinko_game.configs, &plinko_config_number);
        plinko_config.is_playable = is_playable;
    }

    public fun set_plinko_config_min_max_bet<T0>(
        _: &AdminCap,
        plinko_game: &mut PlinkoGame<T0>,
        plinko_config_number: u8,
        min_bet: u64,
        max_bet: u64,
    ) {
        let plinko_config: &mut PlinkoConfig<T0> = vec_map::get_mut(&mut plinko_game.configs, &plinko_config_number);
        plinko_config.min_bet = min_bet;
        plinko_config.max_bet = max_bet;
    }

    fun private_create_plinko_config_and_add_to_game<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        num_rows: u8,
        multipliers: vector<UQ32_32>,
        min_bet: u64,
        max_bet: u64,
        is_playable: bool,
        config_number: u8,
    ) {

        // test if the length of the multipliers is equal to 2^num_rows
        assert!(vector::length(&multipliers) == (num_rows as u64) + 1, EInvalidMultipliersLength);

        // Can add a EV check here

        // create the config
        let plinko_config = PlinkoConfig<T0> {
            num_rows,
            multipliers,
            min_bet,
            max_bet,
            is_playable,
        };  

        vec_map::insert(
            &mut plinko_game.configs,
            config_number,
            plinko_config
        );
    }

    public fun create_plinko_config_and_add_to_game<T0>(
        _: &AdminCap,
        plinko_game: &mut PlinkoGame<T0>,
        num_rows: u8,
        multipliers: vector<UQ32_32>,
        min_bet: u64,
        max_bet: u64,
        is_playable: bool,
        config_number: u8,
    ) {
        private_create_plinko_config_and_add_to_game(
            plinko_game, 
            num_rows, 
            multipliers, 
            min_bet, 
            max_bet, 
            is_playable,
            config_number
            );
    }

    fun place_bet<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        house: &mut House<T0>,
        plinko_config_number: u8,
        bet_coin: Coin<T0>,
        num_balls: u8,
        ctx: &mut TxContext
    ) : ID {
        // test if the plinko config number is valid / exists
        assert!(
            vec_map::contains(&plinko_game.configs, &plinko_config_number),
            EInvalidPlinkoConfigNumber
        );

        let plinko_config: &PlinkoConfig<T0> = vec_map::get(&plinko_game.configs, &plinko_config_number);

        let multipliers: vector<UQ32_32> = plinko_config.multipliers;
        let max_multiplier: UQ32_32 = get_max_value(multipliers);

        
        let amount: u64 = coin::value(&bet_coin);
        let max_reward: u64 = uq32_32::int_mul(amount, max_multiplier);

        let gambler: address = tx_context::sender(ctx);

        let stake_per_ball = amount / (num_balls as u64);
        // Ensure that the stake is not higher than the max stake.
        assert!(
            stake_per_ball <= plinko_game.max_bet,
            EStakeTooHigh
        );
        // Ensure that the stake is not lower than the min stake.
        assert!(
            stake_per_ball >= plinko_game.min_bet,
            EStakeTooLow
        );

        assert!(
            stake_per_ball >= plinko_config.min_bet,
            EStakeTooLow
        );

        assert!(
            stake_per_ball <= plinko_config.max_bet,
            EStakeTooHigh
        );

        assert!(
            plinko_config.is_playable,
            EPlinkoConfigNotPlayable
        );

        // Ensure that the number of balls is not higher than the max number of balls.
        assert!(
            num_balls <= plinko_game.max_number_of_balls,
            EInvalidNumberOfBalls
        );


        house::deposit(house, bet_coin);

        let bet = Bet {
            id: object::new(ctx),
            gambler: tx_context::sender(ctx),
            number_of_balls: num_balls,
            total_stake_value: amount,
            fund: house::take_fund_balance<T0>(house, max_reward),
            plinko_config_number: plinko_config_number,
        };

        house::distribute_referral_rewards(house, amount, gambler);
        // Emit the event
        suigar::events::emit_plinko_bet_event(
            object::uid_to_inner(&bet.id),
            amount,
            num_balls,
            amount,
            copy plinko_config_number,
            plinko_config.num_rows,
            gambler
        );

        let bet_id = object::uid_to_inner(&bet.id);
        vec_map::insert(
            &mut plinko_game.bets,
            bet_id,
            bet
        );
        return bet_id
    }

    fun reveal_bet<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        house: &mut House<T0>,
        bet_id: ID,
        r: &Random,
        ctx: &mut TxContext
    ) {
        // Ensure that the bet exists.
        assert!(
            vec_map::contains(&plinko_game.bets, &bet_id),
            EInvalidBetId
        );



        // Retrieves and removes the game from HouseData, preparing for outcome calculation.
        let (_, bet) = vec_map::remove(&mut plinko_game.bets, &bet_id);
        let Bet {id, gambler: gambler_address, number_of_balls, total_stake_value, fund, plinko_config_number} = bet;


        // get the plinko config from the plinko_config_number
        let plinko_config: &PlinkoConfig<T0> = vec_map::get(&plinko_game.configs, &plinko_config_number);

        let multipliers: vector<UQ32_32> = plinko_config.multipliers;




        let stake_per_ball = total_stake_value / (number_of_balls as u64);
        let total_payout_amount: u64 = 0;

        // Calculates outcome for each ball based on the extended beacon.
        let ball_index = 0;
        let payout_multipliers_history: vector<UQ32_32> = vector::empty();
        let payout_multipliers_index_history: vector<u8> = vector::empty();
        let value_history: vector<u64> = vector::empty();
        while (ball_index < number_of_balls) {

            let multiplier_index: u8 = generate_ball_roll(multipliers, r, ctx);
            // Calculate multiplier index based on state
            // Retrieve the multiplier from the house data
            let result_multiplier: UQ32_32 = *vector::borrow(&multipliers, (multiplier_index as u64));
            

            // Calculate funds amount for this particular ball

            let funds_amount_per_ball = uq32_32::int_mul(stake_per_ball, result_multiplier);

            vector::push_back(&mut payout_multipliers_history, result_multiplier);
            vector::push_back(&mut payout_multipliers_index_history, multiplier_index);
            vector::push_back(&mut value_history, funds_amount_per_ball);

            // Add the funds amount to the total funds amount
            total_payout_amount = total_payout_amount + funds_amount_per_ball;
            ball_index = ball_index + 1;
        };

        // Processes the payout to the player and returns the game outcome.



        let balance_coin = coin::from_balance(fund, ctx);
        let balance_coin_mut = &mut balance_coin;
        let payout_coin: Coin<T0> = coin::split(balance_coin_mut, total_payout_amount, ctx);


        // transfer the payout coins to the player
        transfer::public_transfer(payout_coin, gambler_address);

        // add the rest into the bank
        house::deposit(house, balance_coin);



        while (vector::length(&payout_multipliers_history) > 0) {
            let mult = vector::pop_back(&mut payout_multipliers_history);
            let value = vector::pop_back(&mut value_history);
            let multiplier_index = vector::pop_back(&mut payout_multipliers_index_history);
            suigar::events::emit_plinko_revealed_event(
                bet_id,
                stake_per_ball,
                mult,
                multiplier_index,
                value,
                plinko_config_number,
                plinko_config.num_rows,
                gambler_address
            );

            
        };

        object::delete(id);

    }


    public fun bet<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        house: &mut House<T0>,
        plinko_config_number: u8,
        bet_coin: Coin<T0>,
        num_balls: u8,
        ctx: &mut TxContext
    ) {
        place_bet(plinko_game, house, plinko_config_number, bet_coin, num_balls, ctx);

    }

    entry fun reveal_bet_onchain_randomness<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        house: &mut House<T0>,
        bet_id: ID,
        r: &Random,
        ctx: &mut TxContext
    ) {
        reveal_bet(plinko_game, house, bet_id, r, ctx);

    }

    entry fun place_bet_and_reveal_onchain_randomness<T0>(
        plinko_game: &mut PlinkoGame<T0>,
        house: &mut House<T0>,
        plinko_config_number: u8,
        bet_coin: Coin<T0>,
        num_balls: u8,
        r: &Random,
        ctx: &mut TxContext
    ) {
        let bet_id = place_bet(plinko_game, house, plinko_config_number, bet_coin, num_balls, ctx);
        reveal_bet(plinko_game, house, bet_id, r, ctx);
    }


    fun generate_ball_roll(
        weights: vector<UQ32_32>, 
        random_generator: &0x2::random::Random, 
        tx_context: &mut TxContext
    ) : u8 {
        let num_paths = 0x1::vector::length<UQ32_32>(&weights) - 1;
        let derived_generator = 0x2::random::new_generator(random_generator, tx_context);
        let path_binary: vector<u8> = u64_to_binary(
            0x2::random::generate_u64_in_range(&mut derived_generator, 0, pow(2, ((num_paths) as u8)) - 1), 
            num_paths
        );
        let roll_sum: u8 = 0;
        let index = 0;
        while (index < 0x1::vector::length<u8>(&path_binary)) {
            roll_sum = roll_sum + (*0x1::vector::borrow<u8>(&path_binary, index));
            index = index + 1;
        };
        roll_sum
    }

    fun u64_to_binary(number: u64, desired_length: u64): vector<u8> {
        let binary_vector = b"";
        let current_value = number;

        while (current_value > 0) {
            0x1::vector::push_back<u8>(&mut binary_vector, ((current_value % 2) as u8));
            current_value = current_value / 2;
        };

        while (0x1::vector::length<u8>(&binary_vector) < desired_length) {
            0x1::vector::push_back<u8>(&mut binary_vector, 0);
        };

        0x1::vector::reverse<u8>(&mut binary_vector);
        binary_vector
    }


    fun get_max_value(vec: vector<UQ32_32>): UQ32_32 {
        assert!(vector::length(&vec) > 0, EVectorIsEmpty);

        let max_value = *vector::borrow(&vec, 0); // Initialize with first element
        let len = vector::length(&vec);
        
        let i = 1;
        while (i < len) {
            let current_value = *vector::borrow(&vec, i);
            if (uq32_32::gt(current_value, max_value)) {
                max_value = current_value;
            };
            i = i + 1;
        };
        max_value
    }

}

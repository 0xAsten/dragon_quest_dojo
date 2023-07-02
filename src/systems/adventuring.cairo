#[system]
mod InitQuest {
    use array::ArrayTrait;
    use traits::Into;

    use dragon_quest_dojo::events::emit;
    use dragon_quest_dojo::components::game::{Game};
    use dragon_quest_dojo::components::adventurer::{Adventurer};
    use dragon_quest_dojo::components::monsters::{Dragon};
    use dragon_quest_dojo::constants::{
        ADVENTURER_HEALTH, ADVENTURER_LELVE, ADVENTURER_STR, DRAGON_HEALTH, DRAGON_LELVE, DRAGON_STR
    };

    #[derive(Drop, Serde)]
    struct QuestInitiated {
        game_id: u32,
        creator: felt252
    }

    fn execute(ctx: Context) {
        // getting the the caller from context
        let adventurer_id: felt252 = ctx.caller_account.into();

        // generate an id that is unique to to this world
        let game_id = ctx.world.uuid();

        // create game entity
        set !(
            ctx,
            game_id.into(),
            (Game {
                adventurer: adventurer_id, dragon: 0, next_to_move: 0, num_moves: 0, winner: 0, 
            })
        )

        // init adventurer entity
        set !(
            ctx,
            (game_id, adventurer_id).into(),
            (Adventurer { health: MAX_HEALTH, level: ADVENTURER_LELVE, strength: ADVENTURER_STR })
        )

        // init dragon entity
        set !(
            ctx,
            (game_id, dragon_id).into(),
            (Dragon { health: DRAGON_HEALTH, level: DRAGON_LELVE, strength: DRAGON_STR })
        )

        let mut values = array::ArrayTrait::new();
        serde::Serde::serialize(@QuestInitiated { game_id, creator: adventurer_id }, ref values);
        emit(ctx, 'QuestInitiated', values.span());

        ()
    }
}


#[system]
mod Adventuring {
    use array::ArrayTrait;
    use box::BoxTrait;
    use traits::Into;

    use dragon_quest_dojo::events::emit;
    use dragon_quest_dojo::components::game::{Game};
    use dragon_quest_dojo::components::adventurer::{Adventurer};
    use dragon_quest_dojo::components::monsters::{Dragon};
    use dragon_quest_dojo::constants::{
        ADVENTURER_HEALTH, ADVENTURER_LELVE, ADVENTURER_STR, DRAGON_HEALTH, DRAGON_LELVE, DRAGON_STR
    };

    const ADVENTURER: felt252 = 'adventurer';
    const DRAGON: felt252 = 'dragon';

    #[derive(Drop, Serde)]
    struct PlayerAttacked {
        game_id: u32,
        player_id: felt252,
        opponent_id: felt252,
        damage: u8,
    }

    #[derive(Drop, Serde)]
    struct GameOver {
        game_id: u32,
        winner: felt252,
        loser: felt252,
    }

    fn execute(ctx: Context, game_id: u32) {
        // gets adventurer address
        let adventurer_id: felt252 = ctx.caller_account.into();

        // read game entity
        let game_sk: Query = game_id.into();
        let game = get !(ctx, game_sk, Game);

        // game condition checking
        assert(game.winner == 0, 'game already over or not start');

        let adventurer_sk: Query = (game_id, adventurer_id).into();
        let adventurer = get !(ctx, adventurer_sk, Adventurer);

        let dragon_sk: Query = (game_id, 0).into();
        let dragon = get !(ctx, dragon_sk, Dragon);

        // pseudorandom number generator seed, use VRF for seed in the future
        let seed = starknet::get_tx_info().unbox().transaction_hash;
        set !(ctx, 'seed', seed.into());

        attack(adventurer, dragon, adventurer.health, dragon.health);
    // let mut values = array::ArrayTrait::new();
    // serde::Serde::serialize(
    //     @PlayerAttacked { game_id, player_id, opponent_id, action, damage }, ref values
    // );
    // emit(ctx, 'PlayerAttacked', values.span());
    }

    fn attack(
        adventurer: @Adventurer,
        dragon: @Dragon,
        adventurerHealth: u8,
        dragonHealth: u8,
    ) -> felt252 {
        if adventurerHealth <= 0 {
            DRAGON
        };

        if dragonHealth <= 0 {
            ADVENTURER
        }

        // attack
        let (adventurerHealth, dragonHealth) = attack_action(
            ADVENTURER,
            DRAGON,
            adventurer.strength,
            dragon.dexterity,
            adventurer.level,
            dragon.level,
            adventurerHealth,
            dragonHealth
        );

        // defend
        let (dragonHealth, adventurerHealth) = attack_action(
            count,
            DRAGON,
            ADVENTURER,
            dragon.strength,
            adventurer.dexterity,
            dragon.level,
            adventurer.level,
            dragonHealth,
            adventurerHealth
        );

        let r = attack(adventurer, dragon, adventurerHealth, dragonHealth);

        r
    }

    fn attack_action(
        attacker: felt252,
        defender: felt252,
        attackerStrength: u8,
        defenderDexterity: u8,
        attackerLevel: u8,
        defenderLevel: u8,
        attackerHealth: u8,
        defenderHealth: u8,
    ) -> (felt252, felt252) {
        let roll_d20 = roll_dice(8);
        let damage = damage(attackerStrength);

        if roll_d20 == 20 {
            damage = damage * 2;

            // emit log

            defenderHealth = defenderHealth - damage * 5;
        } else {
            let ab = attack_bonus(attackerStrength, attackerLevel, roll_d20);
            let ac = armor_class(defenderDexterity, defenderLevel);

            let is_hit = is_le(ac, ab);

            if ac < ab {
                defenderHealth = defenderHealth - damage * 5;
            };
        // emit log
        };

        (attackerHealth, defenderHealth)
    }

    fn roll_dice(x: u8) -> u8 {
        let a = 1664525
        let c = 1013904223
        let m = 2**32

        let meta_sk: Query = (game_id, 'meta').into();
        let seed = get !(ctx, 'seed', u256)
  
        let result: u128 = seed.low % x.into();

        set !(ctx, 'seed', (seed * a + c) % m);

        result.into()
    }

    fn damage(str: u8) -> u8 {
        let modifer = ability_modifier(str);
        let r = roll_dice(6);

        modifer + r
    }

    // calculate the ability modifer 
    fn ability_modifier(score: u8) -> u8 {
        let q = score / 2;

        q - 4
    }
    // get attack bonus
    // increases by 1 for each level
    fn attack_bonus(str: u8, level: u8, roll_d20: u8) -> u8 {
        let modifer = ability_modifier(str);
        roll_d20 + modifer + level
    }

    // get armor class
    // increases by 1 for every 5 levels
    fn armor_class(dex: u8, level: u8) -> u8 {
        let modifer = ability_modifier(dex);
        let q = level / 5;

        10 + modifer + q
    }
}

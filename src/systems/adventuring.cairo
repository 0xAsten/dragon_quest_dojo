#[system]
mod InitQuest {
    use array::ArrayTrait;
    use traits::Into;
    use box::BoxTrait;

    use dragon_quest_dojo::events::emit;
    use dragon_quest_dojo::components::game::{Game};
    use dragon_quest_dojo::components::adventurers::{Adventurer};
    use dragon_quest_dojo::components::monsters::{Dragon};
    use dragon_quest_dojo::constants::{
        ADVENTURER_HEALTH, ADVENTURER_LELVE, ADVENTURER_STR, ADVENTURER_DEX, DRAGON_HEALTH, DRAGON_LELVE, DRAGON_STR, DRAGON_DEX
    };

    #[derive(Drop, Serde)]
    struct QuestInitiated {
        game_id: u32,
        creator: felt252,
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
                adventurer: adventurer_id, dragon: 0, winner: 0
            })
        )

        // init adventurer entity
        set !(
            ctx,
            (game_id, adventurer_id).into(),
            (Adventurer { health: ADVENTURER_HEALTH, level: ADVENTURER_LELVE, strength: ADVENTURER_STR, dexterity: ADVENTURER_DEX })
        )

        // init dragon entity
        set !(
            ctx,
            (game_id, 0).into(),
            (Dragon { health: DRAGON_HEALTH, level: DRAGON_LELVE, strength: DRAGON_STR, dexterity: DRAGON_DEX })
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
    use traits::TryInto;

    use dragon_quest_dojo::events::emit;
    use dragon_quest_dojo::components::game::{Game};
    use dragon_quest_dojo::components::adventurers::{Adventurer};
    use dragon_quest_dojo::components::monsters::{Dragon};
    use dragon_quest_dojo::constants::{
        ADVENTURER_HEALTH, ADVENTURER_LELVE, ADVENTURER_STR, DRAGON_HEALTH, DRAGON_LELVE, DRAGON_STR
    };

    const ADVENTURER: felt252 = 'adventurer';
    const DRAGON: felt252 = 'dragon';

    #[derive(Drop, Serde)]
    struct Attacked {
        attacker: felt252,
        defender: felt252,
        damage: u8,
        attackerHealth: u8,
        defenderHealth: u8,
    }

    #[derive(Drop, Serde)]
    struct GameOver {
        game_id: u32,
        winner: felt252
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

        let winner = attack(ctx, game_id, adventurer, dragon, adventurer.health, dragon.health);

        let mut values = array::ArrayTrait::new();
        serde::Serde::serialize(
            @GameOver { game_id: game_id, winner: winner}, ref values
        );
        emit(ctx, 'GameOver', values.span());

        set !(
            ctx,
            game_id.into(),
            (GameOver {
                game_id: game_id, winner: winner
            })
        )
        
    }

    fn attack(
        ctx: Context,
        game_id: u32,
        adventurer: Adventurer,
        dragon: Dragon,
        adventurerHealth: u8,
        dragonHealth: u8,
    ) -> felt252 {
        if adventurerHealth <= 0_u8 {
            return DRAGON;
        };

        if dragonHealth <= 0_u8 {
           return ADVENTURER;
        };

        // attack
        let (adventurerHealth, dragonHealth) = attack_action(
            ctx,
            game_id,
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
            ctx,
            game_id,
            DRAGON,
            ADVENTURER,
            dragon.strength,
            adventurer.dexterity,
            dragon.level,
            adventurer.level,
            dragonHealth,
            adventurerHealth
        );

        let r = attack(ctx, game_id, adventurer, dragon, adventurerHealth, dragonHealth);

        r
    }

    fn attack_action(
        ctx: Context,
        game_id: u32,
        attacker: felt252,
        defender: felt252,
        attackerStrength: u8,
        defenderDexterity: u8,
        attackerLevel: u8,
        defenderLevel: u8,
        attackerHealth: u8,
        defenderHealth: u8,
    ) -> (u8, u8) {
        let roll_d20 = roll_dice(ctx, game_id, 8);
        let damage = damage(ctx, game_id, attackerStrength);

        if roll_d20 == 20 {
            let damage = damage * 2;

            let defenderHealth = defenderHealth - damage * 5;
        } else {
            let ab = attack_bonus(attackerStrength, attackerLevel, roll_d20);
            let ac = armor_class(defenderDexterity, defenderLevel);

            if ac < ab {
                let defenderHealth = defenderHealth - damage * 5;
            };
        };

        let mut values = array::ArrayTrait::new();
        serde::Serde::serialize(
            @Attacked { attacker, defender, damage,  attackerHealth, defenderHealth}, ref values
        );
        emit(ctx, 'Attacked', values.span());

        (attackerHealth, defenderHealth)
    }

    // TODO: can't update state out of excute function
    // TODO: use VRF insted
    fn roll_dice(ctx: Context, game_id: u32, x: u8) -> u8 {
        let a: u128 = 1664525_u128;
        let c: u128 = 1013904223_u128;
        let m: u128 = pow(2_u128, 32_u128);

        let seed = (a * 1 + c) % m;

        let r: u128 = seed % x.into();
        let r_felt: felt252 = r.into();
        let result: u8 = r_felt.try_into().unwrap();
        result
    }

    fn damage(ctx: Context, game_id: u32, str: u8) -> u8 {
        
        let modifer = ability_modifier(str);
        let r = roll_dice(ctx, game_id, 6);

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

    fn pow(base: u128, mut exp: u128) -> u128 {
        if exp == 0 {
            1
        } else {
            base * pow(base, exp - 1)
        }
    }
}

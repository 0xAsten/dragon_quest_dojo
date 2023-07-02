#[derive(Component, Copy, Drop, Serde)]
struct Game {
    adventurer: felt252,
    dragon: felt252,
    winner: felt252,
}
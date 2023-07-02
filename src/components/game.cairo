#[derive(Component, Copy, Drop, Serde)]
struct Game {
    adventurer: felt252,
    dragon: felt252,
    next_to_move: felt252,
    num_moves: u32,
    winner: felt252,
}
#[derive(Component, Copy, Drop, Serde)]
struct Adventurer {
    health: u8,
    level: u8,
    // Physical
    strength: u8,
    dexterity: u8,
// vitality: u8,
// Mental
// intelligence: u8,
// wisdom: u8,
// charisma: u8,
}

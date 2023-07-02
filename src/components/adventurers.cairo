#[derive(Component, Copy, Drop, Serde)]
struct Adventurer {
    health: u32,
    level: u32,
    // Physical
    strength: u32,
    dexterity: u32,
// vitality: u32,
// Mental
// intelligence: u32,
// wisdom: u32,
// charisma: u32,
}

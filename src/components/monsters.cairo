#[derive(Component, Copy, Drop, Serde)]
struct Dragon {
    Health: u8,
    level: u8,
    // Physical
    Strength: u8,
    Dexterity: u8,
    Vitality: u8,
    // Mental
    Intelligence: u8,
    Wisdom: u8,
    Charisma: u8,
}

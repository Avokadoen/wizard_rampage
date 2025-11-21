pub const array = [_]type{
    AttackRate,
    Melee,
    Health,
    HostileTag,
    DiedThisFrameTag,
    BloodSplatterGroundTag,
    BloodGoreGroundTag,
};

pub const AttackRate = struct {
    cooldown: u8,
    active_cooldown: u8,
};

pub const Melee = struct {
    dmg: i32,
    range: f32,
};

pub const Health = struct {
    max: i32,
    value: i32,
};

pub const HostileTag = struct {};
pub const DiedThisFrameTag = struct {};
pub const BloodSplatterGroundTag = struct {};
pub const BloodGoreGroundTag = struct {};

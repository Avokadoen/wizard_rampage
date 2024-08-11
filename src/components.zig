const zm = @import("zmath");
const ecez = @import("ecez");

pub const all = .{
    Position,
    Rotation,
    Scale,
    Velocity,
    RectangleCollider,
    CircleCollider,
    Collision,
    DrawRectangleTag,
    Texture,
    OrientationBasedDrawOrder,
    OrientationTexture,
    AnimTexture,
    DrawCircleTag,
    Camera,
    FireRate,
    PlayerTag,
    LifeTime,
    InactiveTag,
    ChildOf,
    HostileTag,
    FarmerTag,
    FarmersWifeTag,
    Staff,
    Projectile,
    Health,
    DiedThisFrameTag,
    BloodSplatterGroundTag,
    BloodGoreGroundTag,
    Vocals,
};

pub const Position = struct {
    vec: zm.Vec,
};

pub const Rotation = struct {
    value: f32,
};

pub const Scale = struct {
    x: f32,
    y: f32,
};

pub const Velocity = struct {
    vec: zm.Vec,
    drag: f32,
};

pub const RectangleCollider = packed struct {
    width: f32,
    height: f32,
};

pub const CircleCollider = packed struct {
    x: f16,
    y: f16,
    radius: f32,
};

pub const Collision = struct {
    this_point: zm.Vec,
    other_point: zm.Vec,
};

pub const DrawRectangleTag = struct {};
pub const DrawCircleTag = struct {};

pub const Texture = struct {
    pub const DrawOrder = enum(u8) {
        o0,
        o1,
        o2,
        o3,
    };

    type: u8,
    index: u8,
    draw_order: DrawOrder,
};

pub const OrientationBasedDrawOrder = struct {
    draw_orders: [8]Texture.DrawOrder,
};

pub const OrientationTexture = packed struct {
    start_texture_index: u8,
};

pub const AnimTexture = struct {
    start_frame: u8,
    current_frame: u8,
    frame_count: u8,
    frames_per_frame: u8,
    frames_drawn_current_frame: u8,
};

pub const Camera = struct {
    width: f32,
    height: f32,
};
pub const FireRate = struct {
    base_fire_rate: u8,
    cooldown_fire_rate: u8,
};
pub const PlayerTag = struct {};

pub const LifeTime = struct {
    value: f32,
};
pub const InactiveTag = struct {};

pub const ChildOf = struct {
    parent: ecez.Entity,
    offset_x: f32,
    offset_y: f32,
};

pub const HostileTag = struct {};
pub const FarmerTag = struct {};
pub const FarmersWifeTag = struct {};

pub const Staff = struct {
    pub const ProjectileType = enum {
        bolt,
        red_gem,
    };
    pub const ProjectileAttribs = struct {
        type: ProjectileType,
        attrs: struct {
            dmg: i32,
            weight: f32,
        },
    };
    pub const Modifier = enum {
        piercing,
        dmg_amp,
    };
    pub const Slot = union(enum) {
        none: void,
        projectile: ProjectileAttribs,
        modifier: Modifier,
    };
    pub const max_slots = 32;

    slot_capacity: u8,
    used_slots: u8,
    slot_cursor: u8,
    slots: [max_slots]Slot,
};

pub const Projectile = struct {
    dmg: i32,
    weight: f32, // knockback modifier

    modifier_len: u8,
    modifiers: [Staff.max_slots - 1]Staff.Modifier,
};

pub const Health = struct {
    max: i32,
    value: i32,
};

pub const DiedThisFrameTag = struct {};
pub const BloodSplatterGroundTag = struct {};
pub const BloodGoreGroundTag = struct {};

pub const Vocals = struct {
    // on_attack: u8,
    on_death_start: u8,
    on_death_end: u8,
    on_dmg_start: u8,
    on_dmg_end: u8,
};

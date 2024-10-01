const rl = @import("raylib");
const ecez = @import("ecez");

pub const all = .{
    Position,
    Rotation,
    Scale,
    Velocity,
    Drag,
    MoveSpeed,
    DesiredMovedDir,
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
    AttackRate,
    PlayerTag,
    LifeTime,
    InactiveTag,
    ChildOf,
    HostileTag,
    FarmerTag,
    FarmersWifeTag,
    Staff,
    OldSlot,
    Projectile,
    InventoryItem,
    Inventory,
    Melee,
    Health,
    DiedThisFrameTag,
    BloodSplatterGroundTag,
    BloodGoreGroundTag,
    AttachToCursor,
    Vocals,
};

pub const Position = struct {
    vec: rl.Vector2,
};

pub const Rotation = struct {
    value: f32,
};

pub const Scale = struct {
    vec: rl.Vector2,
};

pub const Velocity = struct {
    vec: rl.Vector2,
};

pub const DesiredMovedDir = struct {
    vec: rl.Vector2,
};

pub const MoveSpeed = struct {
    max: f32,
    accelerate: f32,
};

pub const Drag = struct {
    value: f32,
};

pub const RectangleCollider = struct {
    dim: rl.Vector2,
};

pub const CircleCollider = packed struct {
    x: f16,
    y: f16,
    radius: f32,
};

pub const Collision = struct {
    this_point: rl.Vector2,
    other_point: rl.Vector2,
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
    resolution: rl.Vector2,
};
pub const AttackRate = struct {
    cooldown: u8,
    active_cooldown: u8,
};
pub const PlayerTag = struct {};

pub const LifeTime = struct {
    value: f32,
};
pub const InactiveTag = struct {};

pub const ChildOf = struct {
    parent: ecez.Entity,
    offset: rl.Vector2,
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

pub const OldSlot = struct {
    pub const Type = union(enum) {
        staff_index: u32,
        inventory_pos: Position,
    };

    type: Type,
};

pub const Inventory = struct {
    pub const max_items = 32;

    items_len: u32,
    items: [max_items]ecez.Entity,
};

pub const InventoryItem = struct {
    pub const Item = union(enum) {
        projectile: Staff.ProjectileAttribs,
        modifier: Staff.Modifier,
    };

    item: Item,
};

pub const Melee = struct {
    dmg: i32,
    range: f32,
};

pub const Health = struct {
    max: i32,
    value: i32,
};

pub const DiedThisFrameTag = struct {};
pub const BloodSplatterGroundTag = struct {};
pub const BloodGoreGroundTag = struct {};

pub const AttachToCursor = struct {
    offset: rl.Vector2,
};

pub const Vocals = struct {
    // on_attack: u8,
    on_death_start: u8,
    on_death_end: u8,
    on_dmg_start: u8,
    on_dmg_end: u8,
};

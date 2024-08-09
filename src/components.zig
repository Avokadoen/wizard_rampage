const zm = @import("zmath");

pub const all = .{
    Position,
    Rotation,
    Scale,
    Velocity,
    RectangleCollider,
    CircleCollider,
    Collision,
    DrawRectangleTag,
    StaticTexture,
    AnimTexture,
};

pub const Position = struct {
    vec: zm.Vec,
};

pub const Rotation = struct {
    value: f32,
};

pub const Scale = struct {
    value: f32,
};

pub const Velocity = struct {
    vec: zm.Vec,
};

pub const RectangleCollider = struct {
    width: f32,
    height: f32,
};

pub const CircleCollider = struct {
    radius: f32,
};

pub const Collision = struct {
    this_point: zm.Vec,
    other_point: zm.Vec,
};

pub const DrawRectangleTag = struct {};

pub const StaticTexture = struct { index: u8 };

pub const AnimTexture = packed struct {
    current_frame: u8,
    frame_count: u8,
    frames_per_frame: u8,
};

const rl = @import("raylib");

pub const array = [_]type{
    Position,
    Rotation,
    Scale,
    Velocity,
    DesiredMovedDir,
    MoveSpeed,
    Drag,
    RectangleCollider,
    CircleCollider,
    Collision,
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

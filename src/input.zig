const rl = @import("raylib");
const components = @import("components.zig");

fn moveUp(pos: *components.Position, delta_time: f32) void {
    _ = delta_time; // autofix
    pos.vec[1] -= 10;
}

fn moveDown(pos: *components.Position, delta_time: f32) void {
    _ = delta_time; // autofix
    pos.vec[1] += 10;
}

fn moveRight(pos: *components.Position, delta_time: f32) void {
    _ = delta_time; // autofix
    pos.vec[0] += 10;
}

fn moveLeft(pos: *components.Position, delta_time: f32) void {
    _ = delta_time; // autofix
    pos.vec[0] -= 10;
}

const action = struct {
    key: rl.KeyboardKey,
    callback: fn (player: *components.Position, delta_time: f32) void,
};

pub const key_down_actions = [_]action{
    .{
        .key = .key_w,
        .callback = moveUp,
    },
    .{
        .key = .key_s,
        .callback = moveDown,
    },
    .{
        .key = .key_d,
        .callback = moveRight,
    },
    .{
        .key = .key_a,
        .callback = moveLeft,
    },
};

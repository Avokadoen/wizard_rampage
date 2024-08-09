const rl = @import("raylib");

fn moveUp(player: *rl.Rectangle, delta_time: f32) void {
    _ = delta_time; // autofix
    player.y -= 10;
}

fn moveDown(player: *rl.Rectangle, delta_time: f32) void {
    _ = delta_time; // autofix
    player.y += 10;
}

fn moveRight(player: *rl.Rectangle, delta_time: f32) void {
    _ = delta_time; // autofix
    player.x += 10;
}

fn moveLeft(player: *rl.Rectangle, delta_time: f32) void {
    _ = delta_time; // autofix
    player.x -= 10;
}

const action = struct {
    key: rl.KeyboardKey,
    callback: fn (player: *rl.Rectangle, delta_time: f32) void,
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

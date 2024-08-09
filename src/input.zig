const rl = @import("raylib");
const components = @import("components.zig");
const ecez = @import("ecez");
const zm = @import("zmath");
const delta_time: f32 = 1.0 / 60.0;
fn moveUp(_: *components.Position, vel: *components.Velocity, _: anytype) void {
    vel.vec[1] -= 10;
    if (vel.vec[1] > -500) {
        vel.vec[1] -= 100;
    }
}

fn moveDown(_: *components.Position, vel: *components.Velocity, _: anytype) void {
    if (vel.vec[1] < 500) {
        vel.vec[1] += 100;
    }
}

fn moveRight(_: *components.Position, vel: *components.Velocity, _: anytype) void {
    if (vel.vec[0] < 500) {
        vel.vec[0] += 100;
    }
}

fn moveLeft(_: *components.Position, vel: *components.Velocity, _: anytype) void {
    if (vel.vec[0] > -500) {
        vel.vec[0] -= 100;
    }
}

fn shootUp(pos: *components.Position, _: *components.Velocity, storage: anytype) void {
    const vel = zm.f32x4(
        0,
        -1000,
        0,
        0,
    );
    fireProjectile(pos.*, storage, vel);
}

fn shootDown(pos: *components.Position, _: *components.Velocity, storage: anytype) void {
    const vel = zm.f32x4(
        0,
        1000,
        0,
        0,
    );
    fireProjectile(pos.*, storage, vel);
}

fn shootRight(pos: *components.Position, _: *components.Velocity, storage: anytype) void {
    const vel = zm.f32x4(
        1000,
        0,
        0,
        0,
    );
    fireProjectile(pos.*, storage, vel);
}

fn shootLeft(pos: *components.Position, _: *components.Velocity, storage: anytype) void {
    const vel = zm.f32x4(
        -1000,
        0,
        0,
        0,
    );
    fireProjectile(pos.*, storage, vel);
}

fn fireProjectile(pos: components.Position, storage: anytype, vel: zm.Vec) void {
    const Projectile = struct {
        pos: components.Position,
        vel: components.Velocity,
        collider: components.CircleCollider,
        tag: components.DrawCircleTag,
    };

    _ = storage.createEntity(Projectile{
        .pos = pos,
        .vel = components.Velocity{ .vec = vel },
        .collider = components.CircleCollider{
            .radius = 30,
        },
        .tag = components.DrawCircleTag{},
    }) catch (@panic("rip projectiles"));
}

const action = struct {
    key: rl.KeyboardKey,
    callback: fn (player: *components.Position, velocity: *components.Velocity, storage: anytype) void,
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
    .{
        .key = .key_up,
        .callback = shootUp,
    },
    .{
        .key = .key_down,
        .callback = shootDown,
    },
    .{
        .key = .key_right,
        .callback = shootRight,
    },
    .{
        .key = .key_left,
        .callback = shootLeft,
    },
};

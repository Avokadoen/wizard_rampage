const rl = @import("raylib");
const components = @import("components.zig");
const ecez = @import("ecez");
const zm = @import("zmath");
const TextureRepo = @import("TextureRepo.zig");
const delta_time: f32 = 1.0 / 60.0;
fn moveUp(_: *components.Position, vel: *components.Velocity, _: *components.FireRate, _: anytype) void {
    vel.vec[1] -= 10;
    if (vel.vec[1] > -500) {
        vel.vec[1] -= 100;
    }
}

fn moveDown(_: *components.Position, vel: *components.Velocity, _: *components.FireRate, _: anytype) void {
    if (vel.vec[1] < 500) {
        vel.vec[1] += 100;
    }
}

fn moveRight(_: *components.Position, vel: *components.Velocity, _: *components.FireRate, _: anytype) void {
    if (vel.vec[0] < 500) {
        vel.vec[0] += 100;
    }
}

fn moveLeft(_: *components.Position, vel: *components.Velocity, _: *components.FireRate, _: anytype) void {
    if (vel.vec[0] > -500) {
        vel.vec[0] -= 100;
    }
}

fn shootUp(pos: *components.Position, vel: *components.Velocity, fire_rate: *components.FireRate, storage: anytype) void {
    const projectile_vel = zm.f32x4(
        0,
        -1000 + vel.vec[1],
        0,
        0,
    );
    fireProjectile(pos.*, projectile_vel, fire_rate, storage);
}

fn shootDown(pos: *components.Position, vel: *components.Velocity, fire_rate: *components.FireRate, storage: anytype) void {
    const projectile_vel = zm.f32x4(
        0,
        1000 + vel.vec[1],
        0,
        0,
    );
    fireProjectile(pos.*, projectile_vel, fire_rate, storage);
}

fn shootRight(pos: *components.Position, vel: *components.Velocity, fire_rate: *components.FireRate, storage: anytype) void {
    const projectile_vel = zm.f32x4(
        1000 + vel.vec[0],
        0,
        0,
        0,
    );
    fireProjectile(pos.*, projectile_vel, fire_rate, storage);
}

fn shootLeft(pos: *components.Position, vel: *components.Velocity, fire_rate: *components.FireRate, storage: anytype) void {
    const projectile_vel = zm.f32x4(
        -1000 + vel.vec[0],
        0,
        0,
        0,
    );
    fireProjectile(pos.*, projectile_vel, fire_rate, storage);
}

fn fireProjectile(pos: components.Position, vel: zm.Vec, fire_rate: *components.FireRate, storage: anytype) void {
    const Projectile = struct {
        pos: components.Position,
        vel: components.Velocity,
        collider: components.CircleCollider,
        texture: components.Texture,
        tag: components.DrawCircleTag,
        life_time: components.LifeTime,
    };
    if (fire_rate.cooldown_fire_rate == 0) {
        _ = storage.createEntity(Projectile{
            .pos = pos,
            .vel = components.Velocity{ .vec = vel, .drag = 0.98 },
            .collider = components.CircleCollider{
                .radius = 30,
            },
            .texture = components.Texture{
                .type = @intFromEnum(TextureRepo.texture_type.projectile),
                .index = @intFromEnum(TextureRepo.which_projectile.Bolt0001),
            },
            .tag = components.DrawCircleTag{},
            .life_time = components.LifeTime{
                .value = 1.3,
            },
        }) catch (@panic("rip projectiles"));
        fire_rate.cooldown_fire_rate = fire_rate.base_fire_rate;
    }
}

const action = struct {
    key: rl.KeyboardKey,
    callback: fn (player: *components.Position, velocity: *components.Velocity, fire_rate: *components.FireRate, storage: anytype) void,
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

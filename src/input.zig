const std = @import("std");

const rl = @import("raylib");
const ecez = @import("ecez");

const components = @import("components.zig");
const GameTextureRepo = @import("GameTextureRepo.zig");

const delta_time: f32 = 1.0 / 60.0;

pub fn CreateInput(Storage: type) type {
    return struct {
        fn moveUp(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const move_dir = storage.getComponent(player_entity, *components.DesiredMovedDir).?;
            move_dir.vec.y += -1;
        }

        fn moveDown(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const move_dir = storage.getComponent(player_entity, *components.DesiredMovedDir).?;
            move_dir.vec.y += 1;
        }

        fn moveRight(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const move_dir = storage.getComponent(player_entity, *components.DesiredMovedDir).?;
            move_dir.vec.x += 1;
        }

        fn moveLeft(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            _ = staff_entity;
            const move_dir = storage.getComponent(player_entity, *components.DesiredMovedDir).?;
            move_dir.vec.x -= 1;
        }

        fn shootUp(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity).?;

            const projectile_vel = vel.vec.subtract(rl.Vector2{ .x = 0, .y = 1000 });
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootDown(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity).?;

            const projectile_vel = vel.vec.add(rl.Vector2{ .x = 0, .y = 1000 });
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootRight(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity).?;

            const projectile_vel = vel.vec.add(rl.Vector2{ .x = 1000, .y = 0 });
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn shootLeft(storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const vel = storage.getComponent(player_entity, components.Velocity).?;

            const projectile_vel = vel.vec.subtract(rl.Vector2{ .x = 1000, .y = 0 });
            fireProjectile(projectile_vel, storage, player_entity, staff_entity);
        }

        fn fireProjectile(vel: rl.Vector2, storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void {
            const ProjectileQuery = ecez.QueryAny(
                struct {
                    entity: ecez.Entity,
                    pos: *components.Position,
                    rot: *components.Rotation,
                    vel: *components.Velocity,
                    drag: *components.Drag,
                    collider: *components.CircleCollider,
                    texture: *components.Texture,
                    anim: *components.AnimTexture,
                    life_time: *components.LifeTime,
                    projectile: *components.Projectile,
                },
                .{components.InactiveTag},
                .{},
            );

            const fire_rate = storage.getComponent(staff_entity, *components.AttackRate).?;
            if (fire_rate.active_cooldown <= 0) {
                const pos = storage.getComponent(player_entity, components.Position).?;
                const staff_comp_ptr = storage.getComponent(staff_entity, *components.Staff).?;
                const next_projectile = findNextStaffProjectile(staff_comp_ptr) orelse return;

                const start_frame, const frame_count = switch (next_projectile.type) {
                    .bolt => .{
                        @intFromEnum(GameTextureRepo.which_projectile.Bolt_01),
                        @intFromEnum(GameTextureRepo.which_projectile.Bolt_05) - @intFromEnum(GameTextureRepo.which_projectile.Bolt_01),
                    },
                    .red_gem => .{
                        @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_01),
                        @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_10) - @intFromEnum(GameTextureRepo.which_projectile.Red_Gem_01),
                    },
                };

                const norm_vel = vel.normalize();
                const rotation = std.math.atan2(norm_vel.y, norm_vel.x);
                const collider_offset_x: f32 = 50;
                const collider_offset_y: f32 = 33;

                const cs = @cos(rotation);
                const sn = @sin(rotation);

                const proj_offset = norm_vel.multiply(rl.Vector2.init(15, 15));

                var projectile_iter = ProjectileQuery.prepare(storage);
                if (projectile_iter.getAny()) |projectile| {
                    projectile.pos.* = components.Position{ .vec = pos.vec.add(proj_offset) };
                    projectile.rot.* = components.Rotation{ .value = 0 };
                    projectile.vel.* = components.Velocity{ .vec = vel };
                    projectile.drag.* = components.Drag{ .value = 0.98 };
                    projectile.collider.* = components.CircleCollider{
                        .x = @floatCast(collider_offset_x * cs - collider_offset_y * sn),
                        .y = @floatCast(collider_offset_x * sn + collider_offset_y * cs),
                        .radius = 10,
                    };
                    projectile.texture.* = components.Texture{
                        .type = @intFromEnum(GameTextureRepo.texture_type.projectile),
                        .index = start_frame,
                        .draw_order = .o3,
                    };
                    projectile.anim.* = components.AnimTexture{
                        .start_frame = start_frame,
                        .current_frame = 0,
                        .frame_count = frame_count,
                        .frames_per_frame = 4,
                        .frames_drawn_current_frame = 0,
                    };
                    projectile.life_time.* = components.LifeTime{
                        .value = 1.3,
                    };
                    projectile.projectile.* = next_projectile.proj;

                    storage.unsetComponents(projectile.entity, .{components.InactiveTag});
                } else {
                    _ = storage.createEntity(.{
                        components.Position{
                            .vec = pos.vec.add(proj_offset),
                        },
                        components.Rotation{ .value = 0 },
                        components.Velocity{ .vec = vel },
                        components.Drag{ .value = 0.98 },
                        components.CircleCollider{
                            .x = @floatCast(collider_offset_x * cs - collider_offset_y * sn),
                            .y = @floatCast(collider_offset_x * sn + collider_offset_y * cs),
                            .radius = 10,
                        },
                        components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.projectile),
                            .index = start_frame,
                            .draw_order = .o3,
                        },
                        components.AnimTexture{
                            .start_frame = start_frame,
                            .current_frame = 0,
                            .frame_count = frame_count,
                            .frames_per_frame = 4,
                            .frames_drawn_current_frame = 0,
                        },
                        components.DrawCircleTag{},
                        components.LifeTime{
                            .value = 1.3,
                        },
                        next_projectile.proj,
                    }) catch (@panic("rip projectiles"));
                }

                fire_rate.active_cooldown = fire_rate.cooldown;
            }
        }

        const action = struct {
            key: rl.KeyboardKey,
            callback: fn (storage: *Storage, player_entity: ecez.Entity, staff_entity: ecez.Entity) void,
        };

        pub const key_down_actions = [_]action{
            .{
                .key = .w,
                .callback = moveUp,
            },
            .{
                .key = .s,
                .callback = moveDown,
            },
            .{
                .key = .d,
                .callback = moveRight,
            },
            .{
                .key = .a,
                .callback = moveLeft,
            },
            .{
                .key = .up,
                .callback = shootUp,
            },
            .{
                .key = .down,
                .callback = shootDown,
            },
            .{
                .key = .right,
                .callback = shootRight,
            },
            .{
                .key = .left,
                .callback = shootLeft,
            },
        };
    };
}

pub fn nextStaffProjectileIndex(staff: components.Staff) ?u8 {
    var slots_checked: u8 = 0;
    var cursor = staff.slot_cursor;
    while (staff.slots[cursor] != .projectile and slots_checked < staff.slot_capacity) {
        slots_checked += 1;
        cursor = @mod((cursor + 1), staff.slot_capacity);
    }

    // If we found our next projectile
    if (staff.slots[cursor] == .projectile) {
        return cursor;
    }

    return null;
}

const NextProjectile = struct {
    type: components.Staff.ProjectileType,
    proj: components.Projectile,
};
pub fn findNextStaffProjectile(staff: *components.Staff) ?NextProjectile {
    var modifier_len: u8 = 0;
    var modifiers: [components.Staff.max_slots - 1]components.Staff.Modifier = undefined;
    var slots_checked: u8 = 0;
    while (staff.slots[staff.slot_cursor] != .projectile and slots_checked < staff.slot_capacity) {
        if (staff.slots[staff.slot_cursor] == .modifier) {
            modifiers[modifier_len] = staff.slots[staff.slot_cursor].modifier;
            modifier_len += 1;
        }

        slots_checked += 1;
        staff.slot_cursor = @mod((staff.slot_cursor + 1), staff.slot_capacity);
    }

    // If we found our next projectile
    if (staff.slots[staff.slot_cursor] == .projectile) {
        const proj = staff.slots[staff.slot_cursor].projectile;
        staff.slot_cursor = @mod((staff.slot_cursor + 1), staff.slot_capacity);
        return NextProjectile{
            .type = proj.type,
            .proj = components.Projectile{
                .dmg = proj.attrs.dmg,
                .weight = proj.attrs.weight,
                .modifier_len = modifier_len,
                .modifiers = modifiers,
            },
        };
    }

    return null;
}

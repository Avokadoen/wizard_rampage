const std = @import("std");

const rl = @import("raylib");
const ecez = @import("ecez");
const zm = @import("zmath");
const tracy = @import("ztracy");

const physics = @import("physics_2d.zig");
const components = @import("components.zig");

const delta_time: f32 = 1.0 / 60.0;

pub fn CreateUpdateSystems(Storage: type) type {
    return struct {
        pub const Context = struct {
            storage: Storage,
            sound_repo: []const rl.Sound,
            rng: std.Random,
            farmer_kill_count: *u64,
            the_wife_kill_count: *u64,
            cursor_position: rl.Vector2,
        };

        pub const MovableToImmovableRecToRecCollisionResolve = struct {
            const QueryImmovableRecColliders = Storage.Query(
                struct {
                    pos: components.Position,
                    col: components.RectangleCollider,
                },
                // exclude type
                .{
                    components.Velocity,
                    components.InactiveTag,
                },
            ).Iter;
            pub fn movableToImmovableRecToRecCollisionResolve(
                a_pos: *components.Position,
                a_vel: *components.Velocity,
                a_col: components.RectangleCollider,
                immovable_iter: *QueryImmovableRecColliders,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.Projectile }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                while (immovable_iter.next()) |b| {
                    const maybe_collision = physics.Intersection.rectAndRectResolve(
                        a_col,
                        a_pos.*,
                        b.col,
                        b.pos,
                    );
                    if (maybe_collision) |collision| {
                        // TODO: reflect
                        a_vel.vec += collision;

                        a_pos.vec += collision;
                    }
                }
            }
        };

        pub const MovableToMovableRecToRecCollisionResolve = struct {
            const QueryMovableRecColliders = Storage.Query(
                struct {
                    pos: components.Position,
                    vel: components.Velocity,
                    col: components.RectangleCollider,
                },
                // exclude type
                .{
                    components.InactiveTag,
                },
            ).Iter;
            pub fn movableToMovableRecToRecCollisionResolve(
                a_pos: *components.Position,
                a_vel: *components.Velocity,
                a_col: components.RectangleCollider,
                invocation_count: ecez.InvocationCount,
                immovable_iter: *QueryMovableRecColliders,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.Projectile }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                // skip previous colliders
                immovable_iter.skip(invocation_count.number + 1);

                while (immovable_iter.next()) |b| {
                    const maybe_collision = physics.Intersection.rectAndRectResolve(
                        a_col,
                        a_pos.*,
                        b.col,
                        b.pos,
                    );
                    if (maybe_collision) |collision| {
                        // TODO: reflect
                        a_vel.vec += collision;

                        a_pos.vec += collision;
                    }
                }
            }

            const HostileMeleeQuery = Storage.Query(
                struct {
                    pos: components.Position,
                    attack_rate: *components.AttackRate,
                    hostile: components.HostileTag,
                    melee: components.Melee,
                },
                .{components.InactiveTag},
            ).Iter;
            pub fn hostileMeleePlayer(
                player_pos: components.Position,
                player_col: components.RectangleCollider,
                _: components.PlayerTag,
                health: *components.Health,
                player_vocals: components.Vocals,
                context: Context,
                hostile_iter: *HostileMeleeQuery,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.Projectile }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                // If the wife has been killed, then farmers are fleeing
                if (context.the_wife_kill_count.* >= 1) {
                    return;
                }

                const on_dmg_index = context.rng.intRangeAtMost(u8, player_vocals.on_dmg_start, player_vocals.on_dmg_end);
                const on_dmg_sound = context.sound_repo[on_dmg_index];

                const player_circle = components.CircleCollider{
                    .x = 0,
                    .y = 0,
                    .radius = @max(player_col.height, player_col.height),
                };

                while (hostile_iter.next()) |hostile| {
                    if (hostile.attack_rate.active_cooldown > 0) continue;

                    const hostile_circle = components.CircleCollider{
                        .x = 0,
                        .y = 0,
                        .radius = hostile.melee.range,
                    };

                    const collision = physics.Intersection.circleAndCircle(
                        player_circle,
                        player_pos,
                        hostile_circle,
                        hostile.pos,
                    );
                    if (collision) {
                        hostile.attack_rate.active_cooldown = hostile.attack_rate.cooldown;
                        health.value -= hostile.melee.dmg;

                        rl.setSoundPitch(on_dmg_sound, 1.0);
                        rl.setSoundPan(on_dmg_sound, 0.5);
                        rl.playSound(on_dmg_sound);
                    }
                }
            }
        };

        pub const RotateAfterVelocity = struct {
            pub fn rotateAfterVelocity(rotation: *components.Rotation, vel: components.Velocity) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                rotation.value = std.math.radiansToDegrees(std.math.atan2(vel.vec[1], vel.vec[0]));
            }
        };

        const CameraQuery = Storage.Query(
            struct {
                pos: components.Position,
                scale: components.Scale,
                cam: components.Camera,
            },
            // exclude type
            .{components.InactiveTag},
        ).Iter;

        pub const ProjectileHitKillable = struct {
            const QueryKillable = Storage.Query(
                struct {
                    entity: ecez.Entity,
                    pos: components.Position,
                    col: components.RectangleCollider,
                    health: *components.Health,
                },
                // exclude type
                .{components.InactiveTag},
            ).Iter;

            pub fn projectileHitKillable(
                entity: ecez.Entity,
                pos: components.Position,
                vel: components.Velocity,
                circle: components.CircleCollider,
                proj: components.Projectile,
                killable_iter: *QueryKillable,
                camera_iter: *CameraQuery,
                edit_queue: *Storage.StorageEditQueue,
                context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const offset = zm.f32x4(@floatCast(circle.x), @floatCast(circle.y), 0, 0);
                while (killable_iter.next()) |killable| {
                    if (physics.Intersection.circleAndRect(circle, components.Position{ .vec = pos.vec + offset }, killable.col, killable.pos)) {
                        if (killable.health.value <= 0) continue;

                        const maybe_vocals = context.storage.getComponent(killable.entity, components.Vocals) catch null;
                        if (maybe_vocals) |vocals| {
                            const on_dmg_index = context.rng.intRangeAtMost(u8, vocals.on_dmg_start, vocals.on_dmg_end);
                            const on_dmg_sound = context.sound_repo[on_dmg_index];

                            const pitch_range = 0.2;
                            const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                            rl.setSoundPitch(on_dmg_sound, pitch);

                            const camera = camera_iter.next().?;
                            const pan = ((pos.vec - camera.pos.vec)[0] * camera.scale.x) / camera.cam.width;
                            rl.setSoundPan(on_dmg_sound, pan);

                            rl.playSound(on_dmg_sound);
                        }

                        var extra_dmg: i32 = 0;
                        var has_piercing: bool = false;
                        for (proj.modifiers[0..proj.modifier_len]) |mod| {
                            switch (mod) {
                                .piercing => has_piercing = true,
                                .dmg_amp => extra_dmg += 10,
                            }
                        }

                        const maybe_vel = context.storage.getComponent(killable.entity, *components.Velocity) catch null;
                        if (maybe_vel) |kill_vel| {
                            kill_vel.vec += zm.normalize2(vel.vec) * @as(zm.Vec, @splat(proj.weight));
                        }

                        killable.health.value -= proj.dmg + extra_dmg;

                        if (!has_piercing) {
                            edit_queue.queueSetComponent(entity, components.InactiveTag{}) catch @panic("oom");
                        }

                        return;
                    }
                }
            }
        };

        pub const RegisterDead = struct {
            pub fn registerDead(
                entity: ecez.Entity,
                pos: components.Position,
                health: components.Health,
                camera_iter: *CameraQuery,
                edit_queue: *Storage.StorageEditQueue,
                context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                if (health.value <= 0) {
                    const maybe_vocals = context.storage.getComponent(entity, components.Vocals) catch null;
                    if (maybe_vocals) |vocals| {
                        const on_death_index = context.rng.intRangeAtMost(u8, vocals.on_death_start, vocals.on_death_end);
                        const on_death_sound = context.sound_repo[on_death_index];

                        const pitch_range = 0.2;
                        const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                        rl.setSoundPitch(on_death_sound, pitch);

                        const camera = camera_iter.next().?;
                        const pan = ((pos.vec - camera.pos.vec)[0] * camera.scale.x) / camera.cam.width;
                        rl.setSoundPan(on_death_sound, pan);

                        rl.playSound(on_death_sound);
                    }

                    const maybe_farmer = context.storage.getComponent(entity, components.FarmerTag) catch null;
                    if (maybe_farmer) |_| {
                        context.farmer_kill_count.* += 1;
                    }

                    const maybe_wife = context.storage.getComponent(entity, components.FarmersWifeTag) catch null;
                    if (maybe_wife) |_| {
                        context.the_wife_kill_count.* += 1;
                    }

                    edit_queue.queueSetComponent(entity, components.InactiveTag{}) catch @panic("registerDead: wtf");
                    edit_queue.queueSetComponent(entity, components.DiedThisFrameTag{}) catch @panic("registerDead: wtf");
                }
            }
        };

        pub const UpdateCamera = struct {
            const QueryPlayer = Storage.Query(
                struct {
                    pos: components.Position,
                    rec: components.RectangleCollider,
                    player_tag: components.PlayerTag,
                },
                // exclude type
                .{},
            ).Iter;
            pub fn updateCamera(pos: *components.Position, scale: components.Scale, camera: components.Camera, player_iter: *QueryPlayer) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const player = player_iter.next() orelse @panic("no player panic");
                const camera_offset = zm.f32x4((camera.width * 0.5 - player.rec.width * 0.5) / scale.x, (camera.height * 0.5 - player.rec.height * 0.5) / scale.y, 0, 0);
                pos.vec = player.pos.vec - camera_offset;
            }
        };

        pub const UpdateVelocityBasedMoveDir = struct {
            pub fn updateVelocityBasedMoveDir(
                vel: *components.Velocity,
                move_speed: components.MoveSpeed,
                move_dir: *components.DesiredMovedDir,
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const vel_dir = zm.normalize2(vel.vec);
                // if max speed has been reached or npc want to move in another direction
                if (zm.length2(vel.vec)[0] < move_speed.max or zm.dot2(move_dir.vec, vel_dir)[0] < 0.6) {
                    vel.vec += move_dir.vec * @as(zm.Vec, @splat(move_speed.accelerate));
                }

                move_dir.vec = zm.f32x4s(0);
            }
        };

        pub const UpdatePositionBasedOnVelocity = struct {
            pub fn updatePositionBasedOnVelocity(
                pos: *components.Position,
                vel: components.Velocity,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.ChildOf }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                pos.vec += vel.vec * @as(zm.Vec, @splat(delta_time));
            }
        };

        pub const UpdateVelocityBasedOnDrag = struct {
            pub fn updateVelocityBasedOnDrag(
                vel: *components.Velocity,
                drag: components.Drag,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.ChildOf }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                vel.vec = vel.vec * @as(zm.Vec, @splat(drag.value));
            }
        };

        pub const InherentFromParent = struct {
            pub fn inherentParentVelocity(
                vel: *components.Velocity,
                child_of: components.ChildOf,
                update_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const parent_vel = update_context.storage.getComponent(child_of.parent, components.Velocity) catch return;
                vel.* = parent_vel;
            }

            pub fn inherentParentPosition(
                pos: *components.Position,
                child_of: components.ChildOf,
                update_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const parent_pos = update_context.storage.getComponent(child_of.parent, components.Position) catch return;
                const offset = zm.f32x4(child_of.offset_x, child_of.offset_y, 0, 0);
                pos.vec = parent_pos.vec + offset;
            }

            pub fn inherentParentScale(
                scale: *components.Scale,
                child_of: components.ChildOf,
                update_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const parent_scale = update_context.storage.getComponent(child_of.parent, components.Scale) catch return;
                scale.* = parent_scale;
            }

            pub fn inherentInactiveFromParent(
                entity: ecez.Entity,
                child_of: components.ChildOf,
                update_context: Context,
                edit_queue: *Storage.StorageEditQueue,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const parent_tag = update_context.storage.getComponent(child_of.parent, components.InactiveTag) catch return;
                edit_queue.queueSetComponent(entity, parent_tag) catch @panic("inherentInactiveFromParent: wtf");
            }

            pub fn inherentActiveFromParent(
                entity: ecez.Entity,
                _: components.InactiveTag,
                child_of: components.ChildOf,
                update_context: Context,
                edit_queue: *Storage.StorageEditQueue,
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                _ = update_context.storage.getComponent(child_of.parent, components.InactiveTag) catch {
                    edit_queue.queueRemoveComponent(entity, components.InactiveTag) catch @panic("inherentActiveFromParent: wtf");
                };
            }
        };

        pub const OrientTexture = struct {
            pub fn orientTexture(
                velocity: components.Velocity,
                texture: *components.Texture,
                orientation_texture: components.OrientationTexture,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                {
                    // early out if velocity is none
                    const speed_estimate = zm.lengthSq2(velocity.vec)[0];
                    if (speed_estimate > -0.05 and speed_estimate < 0.05) {
                        return;
                    }
                }

                var smalled_index: usize = 0;
                var smallest_dist = std.math.floatMax(f32);
                for (&[_][2]f32{
                    .{ 0, -1 },
                    .{ -0.5, -0.5 },
                    .{ -1, 0 },
                    .{ -0.5, 0.5 },
                    .{ 0, 1 },
                    .{ 0.5, 0.5 },
                    .{ 1, 0 },
                    .{ 0.5, -0.5 },
                }, 0..) |direction_values, index| {
                    const move_dir = zm.normalize2(velocity.vec);
                    const direction = zm.f32x4(direction_values[0], direction_values[1], 0, 0);
                    const dist = zm.lengthSq2(move_dir - direction)[0];
                    if (dist < smallest_dist) {
                        smallest_dist = dist;
                        smalled_index = index;
                    }
                }

                texture.index = @intCast(orientation_texture.start_texture_index + smalled_index);
            }
        };

        pub const OrientationBasedDrawOrder = struct {
            pub fn orientationBasedDrawOrder(
                texture: *components.Texture,
                orientation_draw_order: components.OrientationBasedDrawOrder,
                orientation_texture: components.OrientationTexture,
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const draw_order_index = texture.index - orientation_texture.start_texture_index;
                texture.draw_order = orientation_draw_order.draw_orders[draw_order_index];
            }
        };

        pub const AnimateTexture = struct {
            pub fn animateTexture(
                texture: *components.Texture,
                anim: *components.AnimTexture,
                _: ecez.ExcludeEntityWith(.{components.OrientationTexture}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                if (anim.frames_drawn_current_frame >= anim.frames_per_frame) {
                    anim.frames_drawn_current_frame = 0;
                    anim.current_frame = @mod((anim.current_frame + 1), anim.frame_count);
                    texture.index = anim.start_frame + anim.current_frame;
                }

                // TODO: if we split update and draw tick then this must be moved to draw
                anim.frames_drawn_current_frame += 1;
            }
        };

        pub const LifeTime = struct {
            pub fn lifeTime(
                entity: ecez.Entity,
                life_time: *components.LifeTime,
                storage_edit: *Storage.StorageEditQueue,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                if (life_time.value <= 0) {
                    storage_edit.queueSetComponent(entity, components.InactiveTag{}) catch (@panic("oom"));
                }
                life_time.value -= delta_time;
            }
        };

        pub const TickAttackRate = struct {
            pub fn tickAttackRate(
                attack_rate: *components.AttackRate,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                if (attack_rate.active_cooldown > 0) {
                    attack_rate.active_cooldown -= 1;
                }
            }
        };

        pub const TargetPlayerOrFlee = struct {
            const QueryPlayer = Storage.Query(
                struct {
                    pos: components.Position,
                    player_tag: components.PlayerTag,
                },
                // exclude type
                .{},
            ).Iter;

            pub fn targetPlayerOrFlee(
                pos: components.Position,
                mov_dir: *components.DesiredMovedDir,
                _: components.HostileTag,
                context: Context,
                player_iter: *QueryPlayer,
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const player = player_iter.next() orelse @panic("targetPlayer: wtf");

                const moving_in_dir = zm.normalize2(player.pos.vec - pos.vec);

                const target_or_flee_vector = if (context.the_wife_kill_count.* >= 1) @as(zm.Vec, @splat(-1)) else @as(zm.Vec, @splat(1));
                mov_dir.vec = moving_in_dir * target_or_flee_vector;
            }
        };
    };
}

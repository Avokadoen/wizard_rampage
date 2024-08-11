const std = @import("std");

const rl = @import("raylib");
const ecez = @import("ecez");
const zm = @import("zmath");
const tracy = @import("ztracy");

const physics = @import("physics_2d.zig");
const components = @import("components.zig");

const delta_time: f32 = 1.0 / 60.0;

pub fn CreateDrawSystems(Storage: type) type {
    return struct {
        pub const Context = struct {
            texture_repo: []const []const rl.Texture,
            storage: Storage,
        };

        pub const Rectangle = struct {
            pub fn rectangleDraw(
                pos: components.Position,
                rectangle: components.RectangleCollider,
                draw_rectangle_tag: components.DrawRectangleTag,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                _ = draw_rectangle_tag;

                const draw_rectangle = rl.Rectangle{
                    .x = pos.vec[0],
                    .y = pos.vec[1],
                    .width = rectangle.width,
                    .height = rectangle.height,
                };

                rl.drawRectanglePro(draw_rectangle, rl.Vector2.init(0, 0), 0, rl.Color.red);
            }
        };

        pub const Circle = struct {
            pub fn circleDraw(
                pos: components.Position,
                circle: components.CircleCollider,
                _: components.DrawCircleTag,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const offset = zm.f32x4(@floatCast(circle.x), @floatCast(circle.y), 0, 0);
                rl.drawCircle(
                    @intFromFloat(pos.vec[0] + @as(f32, @floatCast(offset[0]))),
                    @intFromFloat(pos.vec[1] + @as(f32, @floatCast(offset[1]))),
                    circle.radius,
                    rl.Color.blue,
                );
            }
        };

        fn StaticTextureOrderN(comptime order: components.Texture.DrawOrder) type {
            return struct {
                pub fn staticTextureDraw(
                    entity: ecez.Entity,
                    pos: components.Position,
                    static_texture: components.Texture,
                    draw_context: Context,
                ) void {
                    const zone = tracy.ZoneN(@src(), @src().fn_name ++ " " ++ @tagName(order));
                    defer zone.End();

                    if (static_texture.draw_order != order) return;

                    const rotation = draw_context.storage.getComponent(entity, components.Rotation) catch components.Rotation{ .value = 0 };
                    const scale = draw_context.storage.getComponent(entity, components.Scale) catch components.Scale{ .x = 1, .y = 1 };
                    const texture = draw_context.texture_repo[static_texture.type][static_texture.index];
                    const rect_texture = rl.Rectangle{
                        .x = 0,
                        .y = 0,
                        .height = @floatFromInt(texture.height),
                        .width = @floatFromInt(texture.width),
                    };
                    const rect_render_target = rl.Rectangle{
                        .x = pos.vec[0],
                        .y = pos.vec[1],
                        .height = @as(f32, @floatFromInt(texture.height)) * scale.x,
                        .width = @as(f32, @floatFromInt(texture.width)) * scale.y,
                    };
                    const center = rl.Vector2{ .x = 0, .y = 0 };
                    rl.drawTexturePro(texture, rect_texture, rect_render_target, center, rotation.value, rl.Color.white);
                }
            };
        }

        pub const StaticTextureOrder0 = struct {
            pub fn draw(
                entity: ecez.Entity,
                pos: components.Position,
                static_texture: components.Texture,
                draw_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                StaticTextureOrderN(.o0).staticTextureDraw(entity, pos, static_texture, draw_context);
            }
        };

        pub const StaticTextureOrder1 = struct {
            pub fn draw(
                entity: ecez.Entity,
                pos: components.Position,
                static_texture: components.Texture,
                draw_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                StaticTextureOrderN(.o1).staticTextureDraw(entity, pos, static_texture, draw_context);
            }
        };

        pub const StaticTextureOrder2 = struct {
            pub fn draw(
                entity: ecez.Entity,
                pos: components.Position,
                static_texture: components.Texture,
                draw_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                StaticTextureOrderN(.o2).staticTextureDraw(entity, pos, static_texture, draw_context);
            }
        };

        pub const StaticTextureOrder3 = struct {
            pub fn draw(
                entity: ecez.Entity,
                pos: components.Position,
                static_texture: components.Texture,
                draw_context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                StaticTextureOrderN(.o3).staticTextureDraw(entity, pos, static_texture, draw_context);
            }
        };
    };
}

pub fn CreateUpdateSystems(Storage: type) type {
    return struct {
        pub const Context = struct {
            storage: Storage,
            sound_repo: []const rl.Sound,
            rng: std.Random,
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
        };

        pub const RotateAfterVelocity = struct {
            pub fn rotateAfterVelocity(rotation: *components.Rotation, vel: components.Velocity) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                rotation.value = std.math.radiansToDegrees(std.math.atan2(vel.vec[1], vel.vec[0]));
            }
        };

        pub const ProjectileHitKillable = struct {
            const QueryKillablesMov = Storage.Query(
                struct {
                    entity: ecez.Entity,
                    pos: components.Position,
                    vel: *components.Velocity,
                    col: components.RectangleCollider,
                    health: *components.Health,
                },
                // exclude type
                .{components.InactiveTag},
            ).Iter;

            const QueryKillablesImMov = Storage.Query(
                struct {
                    entity: ecez.Entity,
                    pos: components.Position,
                    col: components.RectangleCollider,
                    health: *components.Health,
                },
                // exclude type
                .{ components.Velocity, components.InactiveTag },
            ).Iter;

            pub fn projectileHitKillable(
                entity: ecez.Entity,
                pos: components.Position,
                vel: components.Velocity,
                circle: components.CircleCollider,
                proj: components.Projectile,
                killable_iter_movable: *QueryKillablesMov,
                killable_iter_immovable: *QueryKillablesImMov,
                edit_queue: *Storage.StorageEditQueue,
                context: Context,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const offset = zm.f32x4(@floatCast(circle.x), @floatCast(circle.y), 0, 0);
                while (killable_iter_movable.next()) |killable| {
                    if (physics.Intersection.circleAndRect(circle, components.Position{ .vec = pos.vec + offset }, killable.col, killable.pos)) {
                        if (killable.health.value <= 0) continue;

                        const maybe_vocals = context.storage.getComponent(killable.entity, components.Vocals) catch null;
                        if (maybe_vocals) |vocals| {
                            const on_dmg_index = context.rng.intRangeAtMost(u8, vocals.on_dmg_start, vocals.on_dmg_end);
                            const on_dmg_sound = context.sound_repo[on_dmg_index];
                            rl.playSound(on_dmg_sound);
                        }

                        killable.vel.vec += zm.normalize2(vel.vec) * @as(zm.Vec, @splat(proj.weight));
                        killable.health.value -= proj.dmg;

                        edit_queue.queueSetComponent(entity, components.InactiveTag{}) catch @panic("oom");

                        return;
                    }
                }

                while (killable_iter_immovable.next()) |killable| {
                    if (physics.Intersection.circleAndRect(circle, pos, killable.col, killable.pos)) {
                        if (killable.health.value <= 0) continue;

                        const maybe_vocals = context.storage.getComponent(killable.entity, components.Vocals) catch null;
                        if (maybe_vocals) |vocals| {
                            const on_dmg_index = context.rng.intRangeAtMost(u8, vocals.on_dmg_start, vocals.on_dmg_end);
                            const on_dmg_sound = context.sound_repo[on_dmg_index];
                            rl.playSound(on_dmg_sound);
                        }

                        killable.health.value -= proj.dmg;
                        edit_queue.queueSetComponent(entity, components.InactiveTag{}) catch @panic("oom");

                        return;
                    }
                }
            }
        };

        pub const RegisterDead = struct {
            pub fn registerDead(
                entity: ecez.Entity,
                health: components.Health,
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
                        rl.playSound(on_death_sound);
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

        pub const UpdateVelocity = struct {
            pub fn updatePositionBasedOnVelocity(
                pos: *components.Position,
                vel: *components.Velocity,
                _: ecez.ExcludeEntityWith(.{ components.InactiveTag, components.ChildOf }),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                pos.vec += vel.vec * @as(zm.Vec, @splat(delta_time));
                vel.vec = vel.vec * @as(zm.Vec, @splat(vel.drag));
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

                const parent_vel = update_context.storage.getComponent(child_of.parent, components.Velocity) catch @panic("inherentParentVelocity: wtf");
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

                const parent_pos = update_context.storage.getComponent(child_of.parent, components.Position) catch @panic("inherentParentPosition: wtf");
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

                const parent_scale = update_context.storage.getComponent(child_of.parent, components.Scale) catch @panic("inherentParentScale: wtf");
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

        pub const FireRate = struct {
            pub fn fireRate(
                fire_rate: *components.FireRate,
                _: ecez.ExcludeEntityWith(.{components.InactiveTag}),
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                if (fire_rate.cooldown_fire_rate > 0) {
                    fire_rate.cooldown_fire_rate -= 5;
                }
            }
        };

        pub const TargetPlayer = struct {
            const QueryPlayer = Storage.Query(
                struct {
                    pos: components.Position,
                    player_tag: components.PlayerTag,
                },
                // exclude type
                .{},
            ).Iter;

            pub fn targetPlayer(
                pos: components.Position,
                vel: *components.Velocity,
                _: components.HostileTag,
                player_iter: *QueryPlayer,
            ) void {
                const zone = tracy.ZoneN(@src(), @src().fn_name);
                defer zone.End();

                const player = player_iter.next() orelse @panic("targetPlayer: wtf");

                const move_dir = zm.normalize2(player.pos.vec - pos.vec);
                const vel_dir = zm.normalize2(pos.vec);

                // TODO: dont hardcode this
                const npc_max_speed = 240;
                const npc_move_speed = 40;

                // if max speed has been reached or npc want to move in another direction
                if (zm.length2(vel.vec)[0] < npc_max_speed or zm.dot2(move_dir, vel_dir)[0] < 0.6) {
                    const move_vector = move_dir * @as(zm.Vec, @splat(npc_move_speed));
                    vel.vec += move_vector;
                }
            }
        };
    };
}

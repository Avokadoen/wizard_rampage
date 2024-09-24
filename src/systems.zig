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
            sound_repo: []const rl.Sound,
            rng: std.Random,
            // TODO: make atomic
            farmer_kill_count: *u64,
            the_wife_kill_count: *u64,
            cursor_position: rl.Vector2,
            camera_entity: ecez.Entity,
            player_entity: ecez.Entity,
        };

        const WriteMovableRecColliders = Storage.Query(
            struct {
                pos: *components.Position,
                vel: *components.Velocity,
                col: components.RectangleCollider,
            },
            // exclude type
            .{ components.InactiveTag, components.Projectile },
        );
        const ImmovableRecColliders = Storage.Query(
            struct {
                pos: components.Position,
                col: components.RectangleCollider,
            },
            // exclude type
            .{ components.Velocity, components.InactiveTag },
        );
        pub fn movableToImmovableRecToRecCollisionResolve(
            movable_iter: *WriteMovableRecColliders,
            immovable_iter: *ImmovableRecColliders,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            var movable_index: u32 = 0;
            while (movable_iter.next()) |movable| {
                defer {
                    immovable_iter.reset();
                    immovable_iter.skip(movable_index);
                    movable_index += 1;
                }

                while (immovable_iter.next()) |immovable| {
                    const maybe_collision = physics.Intersection.rectAndRectResolve(
                        movable.col,
                        movable.pos.*,
                        immovable.col,
                        immovable.pos,
                    );
                    if (maybe_collision) |collision| {
                        // TODO: reflect
                        movable.vel.vec += collision;

                        movable.pos.vec += collision;
                    }
                }
            }
        }

        pub fn movableToMovableRecToRecCollisionResolve(
            this_movable_iter: *WriteMovableRecColliders,
            other_movable_iter: *WriteMovableRecColliders,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            var movable_index: u32 = 0;
            while (this_movable_iter.next()) |this| {
                defer {
                    other_movable_iter.reset();
                    movable_index += 1;
                }

                other_movable_iter.skip(movable_index + 1); // skip self + all previous

                while (other_movable_iter.next()) |other| {
                    const maybe_collision = physics.Intersection.rectAndRectResolve(
                        this.col,
                        this.pos.*,
                        other.col,
                        other.pos.*,
                    );
                    if (maybe_collision) |collision| {
                        const half_col = collision * @as(@TypeOf(collision), @splat(0.5));
                        // TODO: reflect
                        this.vel.vec += half_col;
                        this.pos.vec += half_col;

                        other.vel.vec -= half_col;
                        other.pos.vec -= half_col;
                    }
                }
            }
        }

        const PlayerReadView = Storage.Subset(
            .{
                components.Position,
                components.RectangleCollider,
                components.Vocals,
                components.InactiveTag,
            },
            .read_only,
        );
        const PlayerWriteView = Storage.Subset(
            .{
                components.Health,
            },
            .read_and_write,
        );
        const HostileMeleeQuery = Storage.Query(
            struct {
                pos: components.Position,
                attack_rate: *components.AttackRate,
                hostile: components.HostileTag,
                melee: components.Melee,
            },
            .{components.InactiveTag},
        );
        pub fn hostileMeleePlayer(
            player_read_view: *PlayerReadView,
            player_write_view: *PlayerWriteView,
            hostile_iter: *HostileMeleeQuery,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            // If the wife has been killed, then farmers are fleeing
            if (context.the_wife_kill_count.* >= 1) {
                return;
            }

            if (player_read_view.hasComponents(context.player_entity, .{components.InactiveTag})) {
                return;
            }

            const player_r = player_read_view.getComponents(context.player_entity, struct {
                pos: components.Position,
                col: components.RectangleCollider,
                vocals: components.Vocals,
            }) catch @panic("player entity missing");

            const player_w = player_write_view.getComponents(context.player_entity, struct {
                health: *components.Health,
            }) catch unreachable;

            const on_dmg_index = context.rng.intRangeAtMost(
                u8,
                player_r.vocals.on_dmg_start,
                player_r.vocals.on_dmg_end,
            );
            const on_dmg_sound = context.sound_repo[on_dmg_index];

            const player_circle = components.CircleCollider{
                .x = 0,
                .y = 0,
                .radius = player_r.col.width,
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
                    player_r.pos,
                    hostile_circle,
                    hostile.pos,
                );
                if (collision) {
                    hostile.attack_rate.active_cooldown = hostile.attack_rate.cooldown;
                    player_w.health.value -= hostile.melee.dmg;

                    rl.setSoundPitch(on_dmg_sound, 1.0);
                    rl.setSoundPan(on_dmg_sound, 0.5);
                    rl.playSound(on_dmg_sound);
                }
            }
        }

        const RotateVelocityQuery = Storage.Query(
            struct {
                rot: *components.Rotation,
                vel: components.Velocity,
            },
            .{components.InactiveTag},
        );
        pub fn rotateAfterVelocity(rot_vel_iter: *RotateVelocityQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (rot_vel_iter.next()) |item| {
                item.rot.value = std.math.radiansToDegrees(std.math.atan2(
                    item.vel.vec[1],
                    item.vel.vec[0],
                ));
            }
        }

        const ProjectileQuery = Storage.Query(
            struct {
                entity: ecez.Entity,
                pos: components.Position,
                vel: components.Velocity,
                circle: components.CircleCollider,
                proj: components.Projectile,
            },
            .{components.InactiveTag},
        );
        const QueryKillable = Storage.Query(
            struct {
                entity: ecez.Entity,
                pos: components.Position,
                col: components.RectangleCollider,
                health: *components.Health,
            },
            .{components.InactiveTag},
        );
        const ProjectileHitReadView = Storage.Subset(
            .{
                components.Position,
                components.Scale,
                components.Camera,
                components.Vocals,
            },
            .read_only,
        );
        const ProjectileHitWriteView = Storage.Subset(
            .{
                components.InactiveTag,
                components.Velocity,
            },
            .read_and_write,
        );
        pub fn projectileHitKillable(
            proj_iter: *ProjectileQuery,
            killable_iter: *QueryKillable,
            read_view: *ProjectileHitReadView,
            write_view: *ProjectileHitWriteView,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = read_view.getComponents(context.camera_entity, struct {
                pos: components.Position,
                scale: components.Scale,
                cam: components.Camera,
            }) catch unreachable;

            while (proj_iter.next()) |projectile| {
                defer killable_iter.reset();

                const offset = zm.f32x4(
                    @floatCast(projectile.circle.x),
                    @floatCast(projectile.circle.y),
                    0,
                    0,
                );
                const proj_pos = components.Position{
                    .vec = projectile.pos.vec + offset,
                };

                var extra_dmg: i32 = 0;
                var has_piercing: bool = false;
                for (projectile.proj.modifiers[0..projectile.proj.modifier_len]) |mod| {
                    switch (mod) {
                        .piercing => has_piercing = true,
                        .dmg_amp => extra_dmg += 10,
                    }
                }
                const pan = ((projectile.pos.vec - camera.pos.vec)[0] + 0.5) / camera.cam.width;

                while (killable_iter.next()) |killable| {
                    if (physics.Intersection.circleAndRect(
                        projectile.circle,
                        proj_pos,
                        killable.col,
                        killable.pos,
                    )) {
                        const maybe_vocals = read_view.getComponent(killable.entity, components.Vocals) catch null;
                        if (maybe_vocals) |vocals| {
                            const on_dmg_index = context.rng.intRangeAtMost(u8, vocals.on_dmg_start, vocals.on_dmg_end);
                            const on_dmg_sound = context.sound_repo[on_dmg_index];

                            const pitch_range = 0.2;
                            const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                            rl.setSoundPitch(on_dmg_sound, pitch);
                            rl.setSoundPan(on_dmg_sound, pan);
                            rl.playSound(on_dmg_sound);
                        }

                        const maybe_vel = write_view.getComponent(killable.entity, *components.Velocity) catch null;
                        if (maybe_vel) |kill_vel| {
                            kill_vel.vec += zm.normalize2(projectile.vel.vec) * @as(zm.Vec, @splat(projectile.proj.weight));
                        }

                        killable.health.value -= projectile.proj.dmg + extra_dmg;

                        if (!has_piercing) {
                            write_view.setComponents(projectile.entity, .{components.InactiveTag{}}) catch @panic("oom");
                            break;
                        }
                    }
                }
            }
        }

        const RegisterDeadWriteView = Storage.Subset(
            .{
                components.InactiveTag,
                components.DiedThisFrameTag,
            },
            .read_and_write,
        );
        const RegisterDeadReadView = Storage.Subset(
            .{
                components.FarmerTag,
                components.FarmersWifeTag,
                components.Camera,
                components.Vocals,
                components.Position,
                components.Scale,
            },
            .read_only,
        );
        const MaybeDeadQuery = Storage.Query(
            struct {
                entity: ecez.Entity,
                pos: components.Position,
                health: components.Health,
            },
            .{components.InactiveTag},
        );
        pub fn registerDead(
            living: *MaybeDeadQuery,
            write_view: *RegisterDeadWriteView,
            read_view: *RegisterDeadReadView,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = read_view.getComponents(context.camera_entity, struct {
                pos: components.Position,
                scale: components.Scale,
                cam: components.Camera,
            }) catch unreachable;

            while (living.next()) |item| {
                if (item.health.value <= 0) {
                    const maybe_vocals = read_view.getComponent(item.entity, components.Vocals) catch null;
                    if (maybe_vocals) |vocals| {
                        const on_death_index = context.rng.intRangeAtMost(u8, vocals.on_death_start, vocals.on_death_end);
                        const on_death_sound = context.sound_repo[on_death_index];

                        const pitch_range = 0.2;
                        const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                        rl.setSoundPitch(on_death_sound, pitch);

                        const pan = ((camera.pos.vec - item.pos.vec)[0] * camera.scale.x) - 0.5 / camera.cam.width;
                        rl.setSoundPan(on_death_sound, pan);

                        rl.playSound(on_death_sound);
                    }

                    if (read_view.hasComponents(item.entity, .{components.FarmerTag})) {
                        context.farmer_kill_count.* += 1;
                    } else if (read_view.hasComponents(item.entity, .{components.FarmersWifeTag})) {
                        context.the_wife_kill_count.* += 1;
                    }

                    write_view.setComponents(item.entity, .{
                        components.InactiveTag{},
                        components.DiedThisFrameTag{},
                    }) catch @panic("registerDead: oom");
                }
            }
        }

        const PlayerCamView = Storage.Subset(
            .{
                components.Position,
                components.RectangleCollider,
            },
            .read_only,
        );
        const CameraUpdateView = Storage.Subset(
            .{
                components.Position,
                components.Scale,
                components.Camera,
            },
            .read_and_write,
        );
        pub fn updateCamera(
            camera_update_view: *CameraUpdateView,
            player_view: *PlayerCamView,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = camera_update_view.getComponents(
                context.camera_entity,
                struct {
                    pos: *components.Position,
                    scale: components.Scale,
                    cam: components.Camera,
                },
            ) catch @panic("camera missing required comp");

            const player = player_view.getComponents(context.player_entity, struct {
                pos: components.Position,
                col: components.RectangleCollider,
            }) catch @panic("player entity missing");

            const camera_offset = zm.f32x4(
                (camera.cam.width * 0.5 - player.col.width * 0.5) / camera.scale.x,
                (camera.cam.height * 0.5 - player.col.height * 0.5) / camera.scale.y,
                0,
                0,
            );
            camera.pos.vec = player.pos.vec - camera_offset;
        }

        const UpdateVelocityQuery = Storage.Query(
            struct {
                vel: *components.Velocity,
                move_speed: components.MoveSpeed,
                move_dir: *components.DesiredMovedDir,
            },
            .{},
        );
        pub fn updateVelocityBasedMoveDir(update_vel: *UpdateVelocityQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (update_vel.next()) |item| {
                const vel_dir = zm.normalize2(item.vel.vec);
                // if max speed has been reached or npc want to move in another direction
                if (zm.length2(item.vel.vec)[0] < item.move_speed.max or zm.dot2(item.move_dir.vec, vel_dir)[0] < 0.6) {
                    item.vel.vec += item.move_dir.vec * @as(zm.Vec, @splat(item.move_speed.accelerate));
                }

                item.move_dir.vec = zm.f32x4s(0);
            }
        }

        const UpdatePosBasedOnVelQuery = Storage.Query(
            struct {
                pos: *components.Position,
                vel: components.Velocity,
            },
            .{ components.InactiveTag, components.ChildOf },
        );
        pub fn updatePositionBasedOnVelocity(update_pos: *UpdatePosBasedOnVelQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (update_pos.next()) |item| {
                item.pos.vec += item.vel.vec * @as(zm.Vec, @splat(delta_time));
            }
        }

        const UpdateVelBasedOnDrag = Storage.Query(
            struct {
                vel: *components.Velocity,
                drag: components.Drag,
            },
            .{ components.InactiveTag, components.ChildOf },
        );
        pub fn updateVelocityBasedOnDrag(update_vel: *UpdateVelBasedOnDrag) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (update_vel.next()) |item| {
                item.vel.vec = item.vel.vec * @as(zm.Vec, @splat(item.drag.value));
            }
        }

        const ParentVelView = Storage.Subset(.{components.Velocity}, .read_only);
        const InherentVelQuery = Storage.Query(
            struct {
                vel: *components.Velocity,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn inherentParentVelocity(
            inherent_vel: *InherentVelQuery,
            parent_vel_view: *ParentVelView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_vel.next()) |item| {
                const parent_vel = parent_vel_view.getComponent(item.child_of.parent, components.Velocity) catch return;
                item.vel.* = parent_vel;
            }
        }

        const ParentPosView = Storage.Subset(.{components.Position}, .read_only);
        const InherentPosQuery = Storage.Query(
            struct {
                pos: *components.Position,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn inherentParentPosition(
            inherent_pos: *InherentPosQuery,
            parent_pos_view: *ParentPosView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_pos.next()) |item| {
                const parent_pos = parent_pos_view.getComponent(item.child_of.parent, components.Position) catch return;
                const offset = zm.f32x4(item.child_of.offset_x, item.child_of.offset_y, 0, 0);
                item.pos.vec = parent_pos.vec + offset;
            }
        }

        const ParentScaleView = Storage.Subset(.{components.Scale}, .read_only);
        const InherentScaleQuery = Storage.Query(
            struct {
                scale: *components.Scale,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn inherentParentScale(
            inherent_scale: *InherentScaleQuery,
            parent_scale_view: *ParentScaleView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_scale.next()) |item| {
                const parent_scale = parent_scale_view.getComponent(item.child_of.parent, components.Scale) catch return;
                item.scale.* = parent_scale;
            }
        }

        const InherentInactiveFromParentWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const InherentInactiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
        }, .{components.InactiveTag});
        pub fn inherentInactiveFromParent(
            inherent_inactive: *InherentInactiveQuery,
            write_view: *InherentInactiveFromParentWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_inactive.next()) |item| {
                const parent_tag = write_view.getComponent(item.child_of.parent, components.InactiveTag) catch continue;
                write_view.setComponents(item.entity, .{parent_tag}) catch @panic("inherentInactiveFromParent: oom");
            }
        }

        const InherentActiveFromParentWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const InherentActiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
            _: components.InactiveTag,
        }, .{});
        pub fn inherentActiveFromParent(
            inherent_active: *InherentActiveQuery,
            write_view: *InherentActiveFromParentWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_active.next()) |item| {
                _ = write_view.getComponent(item.child_of.parent, components.InactiveTag) catch {
                    write_view.unsetComponents(item.entity, .{components.InactiveTag});
                };
            }
        }

        const OrientTextureQuery = Storage.Query(struct {
            velocity: components.Velocity,
            texture: *components.Texture,
            orientation_texture: components.OrientationTexture,
        }, .{components.InactiveTag});
        pub fn orientTexture(orient_textures: *OrientTextureQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (orient_textures.next()) |item| {
                {
                    // early out if velocity is none
                    const speed_estimate = zm.lengthSq2(item.velocity.vec)[0];
                    if (speed_estimate > -0.05 and speed_estimate < 0.05) {
                        continue;
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
                    const move_dir = zm.normalize2(item.velocity.vec);
                    const direction = zm.f32x4(direction_values[0], direction_values[1], 0, 0);
                    const dist = zm.lengthSq2(move_dir - direction)[0];
                    if (dist < smallest_dist) {
                        smallest_dist = dist;
                        smalled_index = index;
                    }
                }

                item.texture.index = @intCast(item.orientation_texture.start_texture_index + smalled_index);
            }
        }

        const OrientDrawOrderQuery = Storage.Query(struct {
            texture: *components.Texture,
            orientation_draw_order: components.OrientationBasedDrawOrder,
            orientation_texture: components.OrientationTexture,
        }, .{components.InactiveTag});
        pub fn orientationBasedDrawOrder(orient_draw_order: *OrientDrawOrderQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (orient_draw_order.next()) |item| {
                const draw_order_index = item.texture.index - item.orientation_texture.start_texture_index;
                item.texture.draw_order = item.orientation_draw_order.draw_orders[draw_order_index];
            }
        }

        const AnimateQuery = Storage.Query(struct {
            texture: *components.Texture,
            anim: *components.AnimTexture,
        }, .{components.InactiveTag});
        pub fn animateTexture(animate: *AnimateQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (animate.next()) |item| {
                if (item.anim.frames_drawn_current_frame >= item.anim.frames_per_frame) {
                    item.anim.frames_drawn_current_frame = 0;
                    item.anim.current_frame = @mod((item.anim.current_frame + 1), item.anim.frame_count);
                    item.texture.index = item.anim.start_frame + item.anim.current_frame;
                }

                // TODO: if we split update and draw tick then this must be moved to draw
                item.anim.frames_drawn_current_frame += 1;
            }
        }

        const LifeTimetWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const LifetimeQuery = Storage.Query(struct {
            entity: ecez.Entity,
            life_time: *components.LifeTime,
        }, .{components.InactiveTag});
        pub fn lifeTime(
            lifetime: *LifetimeQuery,
            write_view: *LifeTimetWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (lifetime.next()) |item| {
                if (item.life_time.value <= 0) {
                    write_view.setComponents(item.entity, .{components.InactiveTag{}}) catch (@panic("oom"));
                }
                item.life_time.value -= delta_time;
            }
        }

        const AttackRateQuery = Storage.Query(struct {
            attack_rate: *components.AttackRate,
        }, .{components.InactiveTag});
        pub fn tickAttackRate(attack_rate: *AttackRateQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (attack_rate.next()) |item| {
                if (item.attack_rate.active_cooldown > 0) {
                    item.attack_rate.active_cooldown -= 1;
                }
            }
        }

        const PlayerPosView = Storage.Subset(
            .{
                components.Position,
            },
            .read_only,
        );
        const HostileQuery = Storage.Query(struct {
            pos: components.Position,
            mov_dir: *components.DesiredMovedDir,
            _: components.HostileTag,
        }, .{components.InactiveTag});
        pub fn targetPlayerOrFlee(
            hostile_iter: *HostileQuery,
            player_view: *PlayerPosView,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const player = player_view.getComponents(
                context.player_entity,
                struct {
                    pos: components.Position,
                },
            ) catch @panic("missing player entity");

            while (hostile_iter.next()) |item| {
                const moving_in_dir = zm.normalize2(player.pos.vec - item.pos.vec);

                const target_or_flee_vector = if (context.the_wife_kill_count.* >= 1) @as(zm.Vec, @splat(-1)) else @as(zm.Vec, @splat(1));
                item.mov_dir.vec = moving_in_dir * target_or_flee_vector;
            }
        }
    };
}

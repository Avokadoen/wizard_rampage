const std = @import("std");

const rl = @import("raylib");
const tracy = @import("ztracy");
const ecez = @import("ecez");

const physics = @import("../physics_2d.zig");
const components = @import("../components.zig");
const ctx = @import("context.zig");

pub fn Create(Storage: type) type {
    return struct {
        const Context = ctx.ContextType(Storage);

        const HostileMeleePlayerSubset = Storage.Subset(
            .{
                components.Position,
                components.RectangleCollider,
                components.Vocals,
                components.InactiveTag,
                *components.Health,
            },
        );
        const HostileMeleeQuery = Storage.Query(
            struct {
                pos: components.Position,
                attack_rate: *components.AttackRate,
                melee: components.Melee,
            },
            .{components.HostileTag},
            .{components.InactiveTag},
        );
        pub fn hostileMeleePlayer(
            subset: *HostileMeleePlayerSubset,
            hostile_iter: *HostileMeleeQuery,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            // If the wife has been killed, then farmers are fleeing
            if (context.the_wife_kill_count.* >= 1) {
                return;
            }

            if (subset.hasComponents(context.player_entity, .{components.InactiveTag})) {
                return;
            }

            const player_r = subset.getComponents(context.player_entity, struct {
                pos: components.Position,
                col: components.RectangleCollider,
                vocals: components.Vocals,
            }) catch @panic("player entity missing");

            const player_w = subset.getComponents(context.player_entity, struct {
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
                .radius = player_r.col.dim.x,
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

        const ProjectileHitKillableSubset = Storage.Subset(
            .{
                components.Position,
                components.Scale,
                components.Camera,
                components.Vocals,
                components.CircleCollider,
                components.RectangleCollider,
                components.Projectile,
                *components.InactiveTag,
                *components.Velocity,
                *components.Health,
            },
        );
        pub fn projectileHitKillable(
            subset: *ProjectileHitKillableSubset,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = subset.getComponents(context.camera_entity, struct {
                pos: components.Position,
                scale: components.Scale,
                cam: components.Camera,
            }) catch unreachable;

            leaf_loop: for (context.collision_as.leaf_node_storage.items) |leaf_node| {
                if (leaf_node.isActive() == false) {
                    continue :leaf_loop;
                }

                proj_loop: for (leaf_node.circle_movable_entities.items) |a| {
                    // We assume all circle colliders in the game is projectiles currently.
                    std.debug.assert(subset.hasComponents(a, .{components.Projectile}));

                    const projectile = subset.getComponents(a, struct {
                        pos: components.Position,
                        col: components.CircleCollider,
                        vel: components.Velocity,
                        proj: components.Projectile,
                    }) catch unreachable;

                    const offset = rl.Vector2.init(
                        @floatCast(projectile.col.x),
                        @floatCast(projectile.col.y),
                    );
                    const proj_pos = components.Position{
                        .vec = projectile.pos.vec.add(offset),
                    };

                    var extra_dmg: i32 = 0;
                    var has_piercing: bool = false;
                    for (projectile.proj.modifiers[0..projectile.proj.modifier_len]) |mod| {
                        switch (mod) {
                            .piercing => has_piercing = true,
                            .dmg_amp => extra_dmg += 10,
                        }
                    }

                    const pan = ((projectile.pos.vec.x - camera.pos.vec.x) + 0.5) / camera.cam.resolution.x;

                    for (leaf_node.immovable_entities.items) |b| {
                        const immovable = subset.getComponents(b, struct {
                            pos: components.Position,
                            col: components.RectangleCollider,
                        }) catch unreachable;

                        if (physics.Intersection.circleAndRect(
                            projectile.col,
                            proj_pos,
                            immovable.col,
                            immovable.pos,
                        )) {
                            // Assumption: objects without velocity does not have a health component
                            subset.setComponents(a, .{components.InactiveTag{}}) catch @panic("oom");
                            continue :proj_loop;
                        }
                    }

                    for (leaf_node.rect_movable_entities.items) |b| {
                        // Assumption: All movable are killable
                        const killable = subset.getComponents(b, struct {
                            pos: components.Position,
                            col: components.RectangleCollider,
                            health: *components.Health,
                        }) catch unreachable;

                        if (physics.Intersection.circleAndRect(
                            projectile.col,
                            proj_pos,
                            killable.col,
                            killable.pos,
                        )) {
                            const maybe_vocals = subset.getComponent(b, components.Vocals) catch null;
                            if (maybe_vocals) |vocals| {
                                const on_dmg_index = context.rng.intRangeAtMost(u8, vocals.on_dmg_start, vocals.on_dmg_end);
                                const on_dmg_sound = context.sound_repo[on_dmg_index];

                                const pitch_range = 0.2;
                                const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                                rl.setSoundPitch(on_dmg_sound, pitch);
                                rl.setSoundPan(on_dmg_sound, pan);
                                rl.playSound(on_dmg_sound);
                            }

                            const maybe_vel = subset.getComponent(b, *components.Velocity) catch null;
                            if (maybe_vel) |kill_vel| {
                                const proj_dir = projectile.vel.vec.normalize();
                                const proj_impact = rl.Vector2.init(projectile.proj.weight, projectile.proj.weight);
                                kill_vel.vec = kill_vel.vec.add(proj_dir.multiply(proj_impact));
                            }

                            killable.health.value -= projectile.proj.dmg + extra_dmg;

                            if (!has_piercing) {
                                subset.setComponents(a, .{components.InactiveTag{}}) catch @panic("oom");
                                continue :proj_loop;
                            }
                        }
                    }
                }
            }
        }

        const RegisterDeadSubset = Storage.Subset(
            .{
                *components.InactiveTag,
                *components.DiedThisFrameTag,
                components.FarmerTag,
                components.FarmersWifeTag,
                components.Camera,
                components.Vocals,
                components.Position,
                components.Scale,
            },
        );
        const MaybeDeadQuery = Storage.Query(
            struct {
                entity: ecez.Entity,
                pos: components.Position,
                health: components.Health,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn registerDead(
            living: *MaybeDeadQuery,
            subset: *RegisterDeadSubset,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = subset.getComponents(context.camera_entity, struct {
                pos: components.Position,
                scale: components.Scale,
                cam: components.Camera,
            }) catch unreachable;

            while (living.next()) |item| {
                if (item.health.value <= 0) {
                    const maybe_vocals = subset.getComponent(item.entity, components.Vocals) catch null;
                    if (maybe_vocals) |vocals| {
                        const on_death_index = context.rng.intRangeAtMost(u8, vocals.on_death_start, vocals.on_death_end);
                        const on_death_sound = context.sound_repo[on_death_index];

                        const pitch_range = 0.2;
                        const pitch = 1 - (context.rng.float(f32) - 0.5) * pitch_range;
                        rl.setSoundPitch(on_death_sound, pitch);

                        const pan = ((camera.pos.vec.x - item.pos.vec.x) * camera.scale.vec.x) - 0.5 / camera.cam.resolution.x;
                        rl.setSoundPan(on_death_sound, pan);

                        rl.playSound(on_death_sound);
                    }

                    if (subset.hasComponents(item.entity, .{components.FarmerTag})) {
                        context.farmer_kill_count.* += 1;
                    } else if (subset.hasComponents(item.entity, .{components.FarmersWifeTag})) {
                        context.the_wife_kill_count.* += 1;
                    }

                    subset.setComponents(item.entity, .{
                        components.InactiveTag{},
                        components.DiedThisFrameTag{},
                    }) catch @panic("registerDead: oom");

                    if (item.entity.id == context.player_entity.id) {
                        context.player_is_dead.* = true;
                    }
                }
            }
        }

        const TargetPlayerOrFleeSubset = Storage.Subset(
            .{
                components.Position,
            },
        );
        const HostileQuery = Storage.Query(
            struct {
                pos: components.Position,
                mov_dir: *components.DesiredMovedDir,
            },
            .{components.HostileTag},
            .{components.InactiveTag},
        );
        pub fn targetPlayerOrFlee(
            hostile_iter: *HostileQuery,
            subset: *TargetPlayerOrFleeSubset,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const player = subset.getComponents(
                context.player_entity,
                struct {
                    pos: components.Position,
                },
            ) catch @panic("missing player entity");

            while (hostile_iter.next()) |item| {
                const moving_in_dir = player.pos.vec.subtract(item.pos.vec).normalize();

                const target_or_flee_vector = if (context.the_wife_kill_count.* >= 1) rl.Vector2.init(-1, -1) else rl.Vector2.init(1, 1);
                item.mov_dir.vec = moving_in_dir.multiply(target_or_flee_vector).normalize();
            }
        }

        const AttackRateQuery = Storage.Query(
            struct {
                attack_rate: *components.AttackRate,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn tickAttackRate(attack_rate: *AttackRateQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (attack_rate.next()) |item| {
                if (item.attack_rate.active_cooldown > 0) {
                    item.attack_rate.active_cooldown -= 1;
                }
            }
        }
    };
}

const std = @import("std");
const tracy = @import("ztracy");
const rl = @import("raylib");

const physics = @import("../physics_2d.zig");
const components = @import("../components.zig");
const ctx = @import("context.zig");

pub fn Create(Storage: type) type {
    return struct {
        const Context = ctx.ContextType(Storage);

        const RecCollisionResolveSubset = Storage.Subset(
            .{
                *components.Position,
                *components.Velocity,
                components.RectangleCollider,
            },
        );
        pub fn recToRecCollisionResolve(
            subset: *RecCollisionResolveSubset,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            // for each leaf, check
            leaf_loop: for (context.collision_as.leaf_node_storage.items) |leaf_node| {
                if (leaf_node.isActive() == false) {
                    continue :leaf_loop;
                }

                movable_loop: for (leaf_node.rect_movable_entities.items, 0..) |a, a_index| {
                    const a_rect = subset.getComponents(a, struct {
                        pos: *components.Position,
                        vel: *components.Velocity,
                        col: components.RectangleCollider,
                    }) catch unreachable;

                    const immovable_value = 0;
                    const movable_value = 1;
                    inline for (0..2) |moveable_immovable| {

                        // If we are checking agains other movable
                        if (moveable_immovable == movable_value) {
                            // if we are the last movable, nothing to do.
                            const is_last_movable = a_index == leaf_node.rect_movable_entities.items.len - 1;
                            if (is_last_movable) {
                                continue :movable_loop;
                            }
                        }

                        const container = if (moveable_immovable == immovable_value)
                            leaf_node.immovable_entities.items
                        else
                            leaf_node.rect_movable_entities.items[a_index + 1 ..];

                        // Check a with all other
                        for (container) |b| {
                            const b_rect = subset.getComponents(b, struct {
                                pos: *components.Position,
                                col: components.RectangleCollider,
                            }) catch unreachable;

                            const maybe_collision = physics.Intersection.rectAndRectResolve(
                                a_rect.col,
                                a_rect.pos.*,
                                b_rect.col,
                                b_rect.pos.*,
                            );
                            if (maybe_collision) |collision| {
                                if (moveable_immovable == immovable_value) {
                                    // TODO: reflect
                                    a_rect.vel.vec = a_rect.vel.vec.add(collision);
                                    a_rect.pos.vec = a_rect.pos.vec.add(collision);
                                } else {
                                    const half_col = collision.multiply(rl.Vector2.init(0.5, 0.5));
                                    // TODO: reflect
                                    a_rect.vel.vec = a_rect.vel.vec.add(half_col);
                                    a_rect.pos.vec = a_rect.pos.vec.add(half_col);

                                    const b_vel = subset.getComponent(b, *components.Velocity) catch unreachable;
                                    b_vel.vec = b_vel.vec.subtract(half_col);
                                    b_rect.pos.vec = b_rect.pos.vec.subtract(half_col);
                                }
                            }
                        }
                    }
                }
            }
        }

        const RotateVelocityQuery = Storage.Query(
            struct {
                rot: *components.Rotation,
                vel: components.Velocity,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn rotateAfterVelocity(rot_vel_iter: *RotateVelocityQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (rot_vel_iter.next()) |item| {
                item.rot.value = std.math.radiansToDegrees(std.math.atan2(
                    item.vel.vec.y,
                    item.vel.vec.x,
                ));
            }
        }

        const UpdateVelocityQuery = Storage.Query(
            struct {
                vel: *components.Velocity,
                move_speed: components.MoveSpeed,
                move_dir: *components.DesiredMovedDir,
            },
            .{},
            .{},
        );
        pub fn updateVelocityBasedMoveDir(update_vel: *UpdateVelocityQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (update_vel.next()) |item| {
                const vel_dir = item.vel.vec.normalize();
                // if max speed has been reached or npc want to move in another direction
                if (item.vel.vec.length() < item.move_speed.max or item.move_dir.vec.dotProduct(vel_dir) < 0.6) {
                    item.vel.vec = item.vel.vec.add(item.move_dir.vec.multiply(rl.Vector2.init(item.move_speed.accelerate, item.move_speed.accelerate)));
                }

                item.move_dir.vec = rl.Vector2.zero();
            }
        }

        const UpdatePosBasedOnVelQuery = Storage.Query(
            struct {
                pos: *components.Position,
                vel: components.Velocity,
            },
            .{},
            .{ components.InactiveTag, components.ChildOf },
        );
        pub fn updatePositionBasedOnVelocity(update_pos: *UpdatePosBasedOnVelQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const dt = rl.Vector2.init(Context.delta_time, Context.delta_time);
            while (update_pos.next()) |item| {
                item.pos.vec = item.pos.vec.add(item.vel.vec.multiply(dt));
            }
        }

        const UpdateVelBasedOnDrag = Storage.Query(
            struct {
                vel: *components.Velocity,
                drag: components.Drag,
            },
            .{},
            .{ components.InactiveTag, components.ChildOf },
        );
        pub fn updateVelocityBasedOnDrag(update_vel: *UpdateVelBasedOnDrag) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (update_vel.next()) |item| {
                const drag = rl.Vector2.init(item.drag.value, item.drag.value);
                item.vel.vec = item.vel.vec.multiply(drag);
            }
        }
    };
}

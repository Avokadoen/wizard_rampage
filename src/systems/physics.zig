const std = @import("std");
const tracy = @import("ztracy");
const zm = @import("zmath");

const physics = @import("../physics_2d.zig");
const components = @import("../components.zig");
const Context = @import("Context.zig");

pub fn Create(Storage: type) type {
    return struct {
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
                item.pos.vec += item.vel.vec * @as(zm.Vec, @splat(Context.delta_time));
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
    };
}

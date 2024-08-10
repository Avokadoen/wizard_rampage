const std = @import("std");

const rl = @import("raylib");
const ecez = @import("ecez");
const zm = @import("zmath");

const physics = @import("physics_2d.zig");
const components = @import("components.zig");

pub const DrawSystems = struct {
    pub const Context = struct {
        texture_repo: []const rl.Texture,
    };

    pub const Rectangle = struct {
        pub fn draw(pos: components.Position, rectangle: components.RectangleCollider, draw_rectangle_tag: components.DrawRectangleTag) void {
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
        pub fn draw(pos: components.Position, circle: components.CircleCollider, _: components.DrawCircleTag) void {
            rl.drawCircle(@intFromFloat(pos.vec[0]), @intFromFloat(pos.vec[1]), circle.radius, rl.Color.blue);
        }
    };

    pub const StaticTexture = struct {
        // TODO: account for scale and rotation
        pub fn draw(pos: components.Position, static_texture: components.Texture, draw_context: Context) void {
            const texture = draw_context.texture_repo[static_texture.index];
            rl.drawTexture(texture, @intFromFloat(pos.vec[0]), @intFromFloat(pos.vec[1]), rl.Color.white);
        }
    };
};

pub fn CreateUpdateSystems(Storage: type) type {
    return struct {
        pub const MovableToImmovableRecToRecCollisionResolve = struct {
            const QueryImmovableRecColliders = Storage.Query(
                struct {
                    pos: components.Position,
                    col: components.RectangleCollider,
                },
                // exclude type
                .{components.Velocity},
            ).Iter;
            pub fn movableToImmovableRecToRecCollisionResolve(
                a_pos: *components.Position,
                a_vel: *components.Velocity,
                a_col: components.RectangleCollider,
                immovable_iter: *QueryImmovableRecColliders,
            ) void {
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
                const player = player_iter.next() orelse @panic("no player panic");
                const camera_offset = zm.f32x4((camera.width * 0.5 - player.rec.width * 0.5) / scale.value, (camera.height * 0.5 - player.rec.height * 0.5) / scale.value, 0, 0);
                pos.vec = player.pos.vec - camera_offset;
            }
        };
        pub const UpdateVelocity = struct {
            pub fn updatePositionBasedOnVelocity(pos: *components.Position, vel: components.Velocity) void {
                const delta_time: f32 = 1.0 / 60.0;
                pos.vec += vel.vec * @as(zm.Vec, @splat(delta_time));
            }
        };

        pub const OrientTexture = struct {
            pub fn orientTexture(velocity: components.Velocity, texture: *components.Texture, orientation_texture: components.OrientationTexture) void {
                {
                    // early out if velocity is none
                    const speed_estimate = zm.lengthSq2(velocity.vec)[0];
                    if (speed_estimate > -0.05 and speed_estimate < 0.05) {
                        return;
                    }
                }

                var smalled_index: usize = 0;
                var smallest_dist = std.math.floatMax(f32);
                for (&[_]zm.Vec{
                    zm.f32x4(0, -1, 0, 0),
                    zm.f32x4(-0.5, -0.5, 0, 0),
                    zm.f32x4(-1, 0, 0, 0),
                    zm.f32x4(-0.5, 0.5, 0, 0),
                    zm.f32x4(0, 1, 0, 0),
                    zm.f32x4(0.5, 0.5, 0, 0),
                    zm.f32x4(1, 0, 0, 0),
                    zm.f32x4(0.5, -0.5, 0, 0),
                }, 0..) |direction, index| {
                    const dist = zm.lengthSq2(velocity.vec - direction)[0];
                    if (dist < smallest_dist) {
                        smallest_dist = dist;
                        smalled_index = index;
                    }
                }

                texture.index = @intCast(orientation_texture.start_texture_index + smalled_index);
            }
        };
    };
}

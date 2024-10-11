const tracy = @import("ztracy");
const ecez = @import("ecez");
const rl = @import("raylib");

const components = @import("../components.zig");
const ctx = @import("context.zig");

pub fn Create(Storage: type) type {
    return struct {
        const Context = ctx.ContextType(Storage);

        const LifeTimetSubset = Storage.Subset(.{
            *components.InactiveTag,
        });
        const LifetimeQuery = Storage.Query(struct {
            entity: ecez.Entity,
            life_time: *components.LifeTime,
        }, .{components.InactiveTag});
        pub fn lifeTime(
            lifetime: *LifetimeQuery,
            subset: *LifeTimetSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (lifetime.next()) |item| {
                if (item.life_time.value <= 0) {
                    subset.setComponents(item.entity, .{components.InactiveTag{}}) catch (@panic("oom"));
                }
                item.life_time.value -= Context.delta_time;
            }
        }

        const CameraFollowPlayerSubset = Storage.Subset(
            .{
                *components.Position,
                components.RectangleCollider,
                *components.Scale,
                *components.Camera,
            },
        );
        pub fn cameraFollowPlayer(
            subset: *CameraFollowPlayerSubset,
            context: Context,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const camera = subset.getComponents(
                context.camera_entity,
                struct {
                    pos: *components.Position,
                    scale: components.Scale,
                    cam: components.Camera,
                },
            ) catch @panic("camera missing required comp");

            const player = subset.getComponents(context.player_entity, struct {
                pos: components.Position,
                col: components.RectangleCollider,
            }) catch @panic("player entity missing");

            const camera_offset = rl.Vector2.init(
                (camera.cam.resolution.x * 0.5 - player.col.dim.x * 0.5) / camera.scale.vec.x,
                (camera.cam.resolution.y * 0.5 - player.col.dim.y * 0.5) / camera.scale.vec.y,
            );
            camera.pos.vec = player.pos.vec.subtract(camera_offset);
        }

        const OrientTextureQuery = Storage.Query(struct {
            velocity: components.Velocity,
            texture: *components.Texture,
            orientation_texture: components.OrientationTexture,
        }, .{components.InactiveTag});
        pub fn orientTexture(orient_textures: *OrientTextureQuery) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const direction_vectors = [_]rl.Vector2{
                rl.Vector2.init(0, -1),
                rl.Vector2.init(-0.5, -0.5),
                rl.Vector2.init(-1, 0),
                rl.Vector2.init(-0.5, 0.5),
                rl.Vector2.init(0, 1),
                rl.Vector2.init(0.5, 0.5),
                rl.Vector2.init(1, 0),
                rl.Vector2.init(0.5, -0.5),
            };

            while (orient_textures.next()) |item| {
                {
                    // early out if velocity is none
                    const speed_estimate = item.velocity.vec.lengthSqr();
                    if (speed_estimate > -0.05 and speed_estimate < 0.05) {
                        continue;
                    }
                }

                const move_dir = item.velocity.vec.normalize();
                var smalled_index: usize = 0;
                var smallest_dist = @import("std").math.floatMax(f32);
                for (&direction_vectors, 0..) |direction, index| {
                    const dist = move_dir.subtract(direction).lengthSqr();
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
    };
}

const std = @import("std");
const rl = @import("raylib");
const zm = @import("zmath");

const input = @import("input.zig");

const components = @import("components.zig");
const physics = @import("physics_2d.zig");

pub fn main() anyerror!void {
    // Initialize window
    const window_width, const window_height = window_init: {
        // init window and gl
        rl.initWindow(0, 0, "raylib [texture] example - sprite anim");

        const width = rl.getScreenWidth();
        const height = rl.getScreenHeight();
        break :window_init .{
            @as(f32, @floatFromInt(width)),
            @as(f32, @floatFromInt(height)),
        };
    };
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const player_sprite: rl.Texture = rl.Texture.init("resources/textures/wizard_01.png");
    defer player_sprite.unload();

    const player_scale: f32 = 0.4;

    const player_sprite_frame = rl.Rectangle.init(
        0,
        0,
        @as(f32, @floatFromInt(player_sprite.width)) * player_scale,
        @as(f32, @floatFromInt(player_sprite.height)) * player_scale,
    );

    const room_center = zm.f32x4(
        window_width * @as(f32, 0.5),
        window_width * @as(f32, 0.5),
        0,
        0,
    );

    var debug_player_rect = rl.Rectangle{
        .x = room_center[0] - player_sprite_frame.width,
        .y = room_center[1] - player_sprite_frame.height,
        .width = player_sprite_frame.width,
        .height = player_sprite_frame.height,
    };

    const room_boundary_thickness = 100;
    // TODO: just have a single rectangle for room and reverse hit detection (problem is resolve no hit to a hit)
    const room_boundaries = [_]rl.Rectangle{
        // North
        .{
            .x = 0,
            .y = window_height - room_boundary_thickness,
            .width = window_width,
            .height = room_boundary_thickness,
        },
        // West
        .{
            .x = 0,
            .y = 0,
            .width = room_boundary_thickness,
            .height = window_height,
        },
        // South
        .{
            .x = 0,
            .y = 0,
            .width = window_width,
            .height = room_boundary_thickness,
        },
        // East
        .{
            .x = window_width - room_boundary_thickness,
            .y = 0,
            .width = room_boundary_thickness,
            .height = window_height,
        },
    };

    var camera = rl.Camera2D{
        .offset = rl.Vector2.init(
            0,
            0,
        ),
        .target = rl.Vector2.init(
            0,
            0,
        ),
        .rotation = 0,
        .zoom = 1,
    };

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    const delta_time: f32 = 1 / 60;
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        {
            // Input handling
            {
                inline for (input.key_down_actions) |input_action| {
                    if (rl.isKeyDown(input_action.key)) {
                        input_action.callback(&debug_player_rect, delta_time);
                    }
                }
            }

            // Resolve collisions
            {
                const player_collider = components.RectangleCollider{
                    .width = debug_player_rect.width,
                    .height = debug_player_rect.height,
                };
                var player_pos = components.Position{
                    .vec = .{ debug_player_rect.x, debug_player_rect.y, 0, 0 },
                };

                for (room_boundaries) |room_boundary| {
                    const room_collider = components.RectangleCollider{
                        .width = room_boundary.width,
                        .height = room_boundary.height,
                    };
                    const room_pos = components.Position{
                        .vec = .{ room_boundary.x, room_boundary.y, 0, 0 },
                    };

                    const maybe_collision = physics.Intersection.rectAndRectResolve(
                        player_collider,
                        player_pos,
                        room_collider,
                        room_pos,
                    );
                    if (maybe_collision) |collision| {
                        player_pos.vec += collision;

                        debug_player_rect.x += collision[0];
                        debug_player_rect.y += collision[1];
                    }
                }
            }
        }

        {
            // Start draw
            rl.beginDrawing();
            defer rl.endDrawing();
            {
                // Start gameplay drawing
                camera.begin();
                defer camera.end();

                rl.clearBackground(rl.Color.ray_white);

                for (room_boundaries) |room_boundary| {
                    rl.drawRectanglePro(room_boundary, rl.Vector2.init(0, 0), 0, rl.Color.red);
                }
                player_sprite.drawEx(rl.Vector2{ .x = debug_player_rect.x, .y = debug_player_rect.y }, 0, player_scale, rl.Color.white);
            }

            {
                // UI can go here
            }
        }
    }
}

test {
    _ = @import("physics_2d.zig");
}

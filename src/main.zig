const std = @import("std");
const rl = @import("raylib");

const components = @import("components.zig");
const physics = @import("physics_2d.zig");

pub fn main() anyerror!void {
    // Initialize window
    const window_width, const window_height = window_init: {
        // init window and gl
        rl.initWindow(0, 0, "raylib [texture] example - sprite anim");

        const width = rl.getScreenWidth();
        const height = rl.getScreenHeight();
        break :window_init .{ width, height };
    };
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    // NOTE: Textures MUST be loaded after Window initialization (OpenGL context is required)
    const scarfy: rl.Texture = rl.Texture.init("resources/textures/scarfy.png"); // Texture loading
    defer scarfy.unload(); // Texture unloading

    var frame_rec = rl.Rectangle.init(
        0,
        0,
        @as(f32, @floatFromInt(@divFloor(scarfy.width, 6))),
        @as(f32, @floatFromInt(scarfy.height)),
    );

    var movable_debug_rect = rl.Rectangle.init(
        0,
        0,
        @as(f32, @floatFromInt(@divFloor(scarfy.width, 6))),
        @as(f32, @floatFromInt(scarfy.height)),
    );
    var movable_debug_rect_move_dir: f32 = 1;

    var movable_debug_circle_x: i32 = @intFromFloat(movable_debug_rect.x + 500);
    var movable_debug_circle_y: i32 = @intFromFloat(movable_debug_rect.y + 500);
    const movable_debug_circle_rad = @max(movable_debug_rect.width, movable_debug_rect.height) / 2;
    var movable_debug_circle_dir: i32 = -1;

    var movable_debug_circle_2_x: i32 = @intFromFloat(movable_debug_rect.x + 200);
    var movable_debug_circle_2_y: i32 = @intFromFloat(movable_debug_rect.y + 200);
    const movable_debug_circle_2_rad = @max(movable_debug_rect.width, movable_debug_rect.height) / 2;
    var movable_debug_circle_2_dir: i32 = 1;

    const static_debug_rect = rl.Rectangle.init(
        movable_debug_rect.x + 500,
        movable_debug_rect.y,
        movable_debug_rect.width,
        movable_debug_rect.height,
    );

    var camera = rl.Camera2D{
        .offset = rl.Vector2.init(
            @as(f32, @floatFromInt(window_width)) * @as(f32, 0.5),
            @as(f32, @floatFromInt(window_height)) * @as(f32, 0.5),
        ),
        .target = rl.Vector2.init(
            0,
            0,
        ),
        .rotation = 0,
        .zoom = 1,
    };

    var current_frame: u8 = 0;

    var framesCounter: u8 = 0;
    var framesSpeed: u8 = 8; // Number of spritesheet frames shown by second

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        framesCounter += 1;

        {
            const rectangle_collider_a = components.RectangleCollider{
                .width = movable_debug_rect.width,
                .height = movable_debug_rect.height,
            };
            const rectangle_pos_a = components.Position{
                .vec = .{ movable_debug_rect.x, movable_debug_rect.y, 0, 0 },
            };

            const rectangle_collider_b = components.RectangleCollider{
                .width = static_debug_rect.width,
                .height = static_debug_rect.height,
            };
            const rectangle_pos_b = components.Position{
                .vec = .{ static_debug_rect.x, static_debug_rect.y, 0, 0 },
            };

            {
                const maybe_collision = physics.Intersection.rectAndRectResolve(
                    rectangle_collider_b,
                    rectangle_pos_b,
                    rectangle_collider_a,
                    rectangle_pos_a,
                );
                if (maybe_collision) |collision| {
                    movable_debug_rect.x += collision[0];
                    movable_debug_rect.y += collision[1];
                    movable_debug_rect_move_dir *= -1;
                }
                movable_debug_rect.x += movable_debug_rect_move_dir;
                camera.target = rl.Vector2.init(movable_debug_rect.x, movable_debug_rect.y);
            }

            const circle_collider = components.CircleCollider{
                .radius = movable_debug_circle_rad,
            };
            const circle_pos = components.Position{
                .vec = .{ @floatFromInt(movable_debug_circle_x), @floatFromInt(movable_debug_circle_y), 0, 0 },
            };

            {
                const maybe_collision = physics.Intersection.circleAndRectResolve(
                    circle_collider,
                    circle_pos,
                    rectangle_collider_b,
                    rectangle_pos_b,
                );
                if (maybe_collision) |collision| {
                    movable_debug_circle_x += @intFromFloat(collision[0]);
                    movable_debug_circle_y += @intFromFloat(collision[1]);
                    movable_debug_circle_dir *= -1;
                }
                movable_debug_circle_y += movable_debug_circle_dir;
            }

            {
                const circle_2_collider = components.CircleCollider{
                    .radius = movable_debug_circle_2_rad,
                };
                const circle_2_pos = components.Position{
                    .vec = .{ @floatFromInt(movable_debug_circle_2_x), @floatFromInt(movable_debug_circle_2_y), 0, 0 },
                };
                const maybe_collision = physics.Intersection.circleAndCircleResolve(
                    circle_collider,
                    circle_pos,
                    circle_2_collider,
                    circle_2_pos,
                );
                if (maybe_collision) |collision| {
                    movable_debug_circle_2_x += @intFromFloat(collision[0]);
                    movable_debug_circle_2_y += @intFromFloat(collision[1]);
                    movable_debug_circle_2_dir *= -1;
                }
                movable_debug_circle_2_x += movable_debug_circle_2_dir;
            }
        }

        if (framesCounter >= (60 / framesSpeed)) {
            framesCounter = 0;
            current_frame += 1;

            if (current_frame > 5) current_frame = 0;

            frame_rec.x = @as(f32, @floatFromInt(current_frame)) * @as(f32, @floatFromInt(@divFloor(scarfy.width, 6)));
        }

        // Control frames speed
        if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
            framesSpeed += 1;
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
            framesSpeed -= 1;
        }

        const max_frame_speed = 15;
        const min_frame_speed = 1;
        if (framesSpeed > max_frame_speed) {
            framesSpeed = max_frame_speed;
        } else if (framesSpeed < min_frame_speed) {
            framesSpeed = min_frame_speed;
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

                scarfy.drawRec(frame_rec, rl.Vector2.init(0, 0), rl.Color.white); // Draw part of the texture
                rl.drawRectanglePro(movable_debug_rect, rl.Vector2.init(0, 0), 0, rl.Color.red);
                rl.drawCircle(movable_debug_circle_x, movable_debug_circle_y, movable_debug_circle_rad, rl.Color.green);
                rl.drawCircle(movable_debug_circle_2_x, movable_debug_circle_2_y, movable_debug_circle_2_rad, rl.Color.yellow);
                rl.drawRectanglePro(static_debug_rect, rl.Vector2.init(0, 0), 0, rl.Color.blue);
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

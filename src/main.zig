const std = @import("std");
const rl = @import("raylib");

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
    defer rl.unloadTexture(scarfy); // Texture unloading

    var frame_rec = rl.Rectangle.init(
        0,
        0,
        @as(f32, @floatFromInt(@divFloor(scarfy.width, 6))),
        @as(f32, @floatFromInt(scarfy.height)),
    );

    const position = rl.Vector2.init(
        @as(f32, @floatFromInt(window_width)) * @as(f32, 0.5) - (frame_rec.width * 0.5),
        @as(f32, @floatFromInt(window_height)) * @as(f32, 0.5) - (frame_rec.height * 0.5),
    );
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

        // Draw
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);
            //   void DrawRectanglePro(Rectangle rec, Vector2 origin, float rotation, Color color);

            scarfy.drawRec(frame_rec, position, rl.Color.white); // Draw part of the texture
        }
    }
}

test {
    _ = @import("2d_physics.zig");
}

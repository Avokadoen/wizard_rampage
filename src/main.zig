const std = @import("std");
const rl = @import("raylib");
const zm = @import("zmath");
const ecez = @import("ecez");

const input = @import("input.zig");
const systems = @import("systems.zig");
const components = @import("components.zig");
const physics = @import("physics_2d.zig");
const TextureRepo = @import("TextureRepo.zig");

const Storage = ecez.CreateStorage(components.all);

const UpdateSystems = systems.CreateUpdateSystems(Storage);

const Scheduler = ecez.CreateScheduler(
    Storage,
    .{
        ecez.Event("game_update", .{
            UpdateSystems.MovableToImmovableRecToRecCollisionResolve,
        }, .{}),
        ecez.Event(
            "game_draw",
            .{
                systems.DrawSystems.Rectangle,
                ecez.DependOn(systems.DrawSystems.StaticTexture, .{systems.DrawSystems.Rectangle}),
            },
            systems.DrawSystems.Context,
        ),
    },
);

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

    const texture_repo = TextureRepo.init();
    defer texture_repo.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var storage = try Storage.init(allocator);
    defer storage.deinit();

    var scheduler = try Scheduler.init(allocator, .{});
    defer scheduler.deinit();

    const room_center = zm.f32x4(
        window_width * @as(f32, 0.5),
        window_width * @as(f32, 0.5),
        0,
        0,
    );

    const player_entity = try create_player_blk: {
        const Player = struct {
            pos: components.Position,
            scale: components.Scale,
            vel: components.Velocity,
            col: components.RectangleCollider,
            // tag: components.DrawRectangleTag,
            texture: components.StaticTexture,
            // Anim,
        };

        const scale: f32 = 0.4;
        const width = @as(f32, @floatFromInt(200)) * scale;
        const height = @as(f32, @floatFromInt(200)) * scale;

        break :create_player_blk storage.createEntity(Player{
            .pos = components.Position{ .vec = zm.f32x4(
                room_center[0] - width,
                room_center[1] - height,
                0,
                0,
            ) },
            .scale = components.Scale{ .value = scale },
            .vel = components.Velocity{ .vec = zm.f32x4s(0) },
            .col = components.RectangleCollider{
                .width = width,
                .height = height,
            },
            // .tag = components.DrawRectangleTag{},
            .texture = components.StaticTexture{
                .index = @intFromEnum(TextureRepo.which.Cloak0001),
            },
        });
    };

    // Create level boundaries (TODO: should only need a single rectangle and do reverse hit detection)
    {
        const room_boundary_thickness = 100;
        const LevelBoundary = struct {
            pos: components.Position,
            collider: components.RectangleCollider,
            tag: components.DrawRectangleTag,
        };

        // North
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                0,
                window_height - room_boundary_thickness,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = window_width,
                .height = room_boundary_thickness,
            },
            .tag = components.DrawRectangleTag{},
        });
        // West
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4s(0) },
            .collider = components.RectangleCollider{
                .width = room_boundary_thickness,
                .height = window_height,
            },
            .tag = components.DrawRectangleTag{},
        });
        // South
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4s(0) },
            .collider = components.RectangleCollider{
                .width = window_width,
                .height = room_boundary_thickness,
            },
            .tag = components.DrawRectangleTag{},
        });
        // East
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                window_width - room_boundary_thickness,
                0,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = room_boundary_thickness,
                .height = window_height,
            },
            .tag = components.DrawRectangleTag{},
        });
    }

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
                const player_pos_ptr = try storage.getComponent(player_entity, *components.Position);
                inline for (input.key_down_actions) |input_action| {
                    if (rl.isKeyDown(input_action.key)) {
                        input_action.callback(player_pos_ptr, delta_time);
                    }
                }
            }

            // system update dispatch
            scheduler.dispatchEvent(&storage, .game_update, .{});
            scheduler.waitEvent(.game_update);
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

                scheduler.dispatchEvent(&storage, .game_draw, systems.DrawSystems.Context{ .texture_repo = &texture_repo.textures });
                scheduler.waitEvent(.game_draw);
                // player_sprite.drawEx(rl.Vector2{ .x = debug_player_rect.x, .y = debug_player_rect.y }, 0, player_scale, rl.Color.white);
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

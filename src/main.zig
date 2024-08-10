const std = @import("std");
const rl = @import("raylib");
const zm = @import("zmath");
const ecez = @import("ecez");

const input = @import("input.zig");
const systems = @import("systems.zig");
const components = @import("components.zig");
const physics = @import("physics_2d.zig");
const TextureRepo = @import("TextureRepo.zig");

const arena_height = 3000;
const arena_width = 3000;

const Storage = ecez.CreateStorage(components.all);

const UpdateSystems = systems.CreateUpdateSystems(Storage);
const DrawSystems = systems.CreateDrawSystems(Storage);

const Scheduler = ecez.CreateScheduler(
    Storage,
    .{
        ecez.Event("game_update", .{
            UpdateSystems.FireRate,
            UpdateSystems.LifeTime,
            UpdateSystems.MovableToImmovableRecToRecCollisionResolve,
            ecez.DependOn(UpdateSystems.UpdateVelocity, .{UpdateSystems.MovableToImmovableRecToRecCollisionResolve}),
            ecez.DependOn(UpdateSystems.InherentFromParent, .{UpdateSystems.UpdateVelocity}),
            // run in parallel
            ecez.DependOn(UpdateSystems.UpdateCamera, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.OrientTexture, .{UpdateSystems.InherentFromParent}),
            // end run in parallel
            // flush in game loop
        }, UpdateSystems.Context),
        ecez.Event(
            "game_draw",
            .{
                DrawSystems.Rectangle,
                ecez.DependOn(DrawSystems.StaticTexture, .{DrawSystems.Rectangle}),
                ecez.DependOn(DrawSystems.Circle, .{DrawSystems.StaticTexture}),
            },
            DrawSystems.Context,
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

    const player_entity = create_player_blk: {
        const Player = struct {
            pos: components.Position,
            scale: components.Scale,
            vel: components.Velocity,
            col: components.RectangleCollider,
            // tag: components.DrawRectangleTag,
            rec_tag: components.DrawRectangleTag,
            texture: components.Texture,
            orientation_texture: components.OrientationTexture,
            fire_rate: components.FireRate,
            player_tag: components.PlayerTag,
        };

        const scale: f32 = 0.4;
        const width = @as(f32, @floatFromInt(200)) * scale;
        const height = @as(f32, @floatFromInt(200)) * scale;

        const player = try storage.createEntity(Player{
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
            .texture = components.Texture{
                .index = @intFromEnum(TextureRepo.which.Cloak0001),
            },
            .orientation_texture = components.OrientationTexture{
                .start_texture_index = @intFromEnum(TextureRepo.which.Cloak0001),
            },
            .rec_tag = components.DrawRectangleTag{},
            .fire_rate = components.FireRate{
                .base_fire_rate = 60,
                .cooldown_fire_rate = 0,
            },
            .player_tag = components.PlayerTag{},
        });

        const PlayerParts = struct {
            pos: components.Position,
            scale: components.Scale,
            vel: components.Velocity,
            texture: components.Texture,
            orientation_texture: components.OrientationTexture,
            child_of: components.ChildOf,
        };
        // hat
        _ = try storage.createEntity(PlayerParts{
            .pos = components.Position{ .vec = zm.f32x4s(0) },
            .scale = components.Scale{ .value = 1 },
            .vel = components.Velocity{ .vec = zm.f32x4s(0) },
            .texture = components.Texture{
                .index = @intFromEnum(TextureRepo.which.Hat0001),
            },
            .orientation_texture = components.OrientationTexture{
                .start_texture_index = @intFromEnum(TextureRepo.which.Hat0001),
            },
            .child_of = components.ChildOf{
                .parent = player,
                .offset_x = 0,
                .offset_y = 0,
            },
        });

        break :create_player_blk player;
    };

    // Create camera
    const camera_entity = try create_camera_blk: {
        const Camera = struct {
            pos: components.Position,
            scale: components.Scale,
            camera: components.Camera,
            // Anim,
        };

        break :create_camera_blk storage.createEntity(Camera{
            .pos = components.Position{ .vec = zm.f32x4s(0) },
            .scale = components.Scale{ .value = 1 },
            .camera = components.Camera{
                .width = window_width,
                .height = window_height,
            },
        });
    };

    // Create level boundaries
    {
        const room_boundary_thickness = 100;
        const LevelBoundary = struct {
            pos: components.Position,
            collider: components.RectangleCollider,
            tag: components.DrawRectangleTag,
        };

        // North with door
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                0,
                0,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = arena_width / 3,
                .height = room_boundary_thickness,
            },
            .tag = components.DrawRectangleTag{},
        });
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                (arena_width / 3) * 2,
                0,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = arena_width / 3,
                .height = room_boundary_thickness,
            },
            .tag = components.DrawRectangleTag{},
        });
        // South
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                0,
                arena_height - room_boundary_thickness,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = arena_width,
                .height = room_boundary_thickness,
            },
            .tag = components.DrawRectangleTag{},
        });
        // West
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4s(0) },
            .collider = components.RectangleCollider{
                .width = room_boundary_thickness,
                .height = arena_height,
            },
            .tag = components.DrawRectangleTag{},
        });
        // East
        _ = try storage.createEntity(LevelBoundary{
            .pos = components.Position{ .vec = zm.f32x4(
                arena_width - room_boundary_thickness,
                0,
                0,
                0,
            ) },
            .collider = components.RectangleCollider{
                .width = room_boundary_thickness,
                .height = arena_height,
            },
            .tag = components.DrawRectangleTag{},
        });
    }

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //const delta_time: f32 = 1 / 60;
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        {
            // Input handling
            {
                const player_pos_ptr = try storage.getComponent(player_entity, *components.Position);
                const player_vec_ptr = try storage.getComponent(player_entity, *components.Velocity);
                const player_fire_rate = try storage.getComponent(player_entity, *components.FireRate);
                inline for (input.key_down_actions) |input_action| {
                    if (rl.isKeyDown(input_action.key)) {
                        input_action.callback(player_pos_ptr, player_vec_ptr, player_fire_rate, &storage);
                    }
                }
            }

            // system update dispatch
            const update_context = UpdateSystems.Context{
                .storage = storage,
            };
            scheduler.dispatchEvent(&storage, .game_update, update_context);
            scheduler.waitEvent(.game_update);

            try storage.flushStorageQueue(); // flush any edits which occured in dispatch game_update
        }

        {
            // Start draw
            rl.beginDrawing();
            defer rl.endDrawing();
            {
                // Start gameplay drawing
                const camera = create_rl_camera_blk: {
                    const camera_pos = try storage.getComponent(camera_entity, components.Position);
                    const camera_zoom = try storage.getComponent(camera_entity, components.Scale);

                    break :create_rl_camera_blk rl.Camera2D{
                        .offset = rl.Vector2{
                            .x = 0,
                            .y = 0,
                        },
                        .target = rl.Vector2{
                            .x = camera_pos.vec[0],
                            .y = camera_pos.vec[1],
                        },
                        .rotation = 0,
                        .zoom = camera_zoom.value,
                    };
                };

                camera.begin();
                defer camera.end();

                rl.clearBackground(rl.Color.ray_white);

                const draw_context = DrawSystems.Context{
                    .texture_repo = &texture_repo.textures,
                };
                scheduler.dispatchEvent(&storage, .game_draw, draw_context);
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

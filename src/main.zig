const std = @import("std");
const rl = @import("raylib");
const zm = @import("zmath");
const ecez = @import("ecez");

const input = @import("input.zig");
const systems = @import("systems.zig");
const components = @import("components.zig");
const physics = @import("physics_2d.zig");
const GameTextureRepo = @import("GameTextureRepo.zig");
const MainTextureRepo = @import("MainTextureRepo.zig");
const GameSoundRepo = @import("GameSoundRepo.zig");

const tracy = @import("ztracy");

const arena_height = 3000;
const arena_width = 3000;

const Storage = ecez.CreateStorage(components.all);

const UpdateSystems = systems.CreateUpdateSystems(Storage);

const Scheduler = ecez.CreateScheduler(
    .{
        ecez.Event("game_update", .{
            UpdateSystems.targetPlayerOrFlee,
            UpdateSystems.tickAttackRate,
            UpdateSystems.lifeTime,
            UpdateSystems.updateVelocityBasedMoveDir,
            UpdateSystems.updatePositionBasedOnVelocity,
            UpdateSystems.updateVelocityBasedOnDrag,
            UpdateSystems.rotateAfterVelocity,
            UpdateSystems.movableToImmovableRecToRecCollisionResolve,
            UpdateSystems.movableToMovableRecToRecCollisionResolve,
            UpdateSystems.inherentParentVelocity,
            UpdateSystems.inherentParentPosition,
            UpdateSystems.inherentParentScale,
            UpdateSystems.inherentInactiveFromParent,
            UpdateSystems.inherentActiveFromParent,
            UpdateSystems.projectileHitKillable,
            UpdateSystems.hostileMeleePlayer,
            UpdateSystems.registerDead,
            UpdateSystems.updateCamera,
            UpdateSystems.orientTexture,
            UpdateSystems.animateTexture,
            UpdateSystems.orientationBasedDrawOrder,
        }),
    },
);

const Input = input.CreateInput(Storage);

// Some hard-coded values for now! :D
const player_scale: f32 = 0.4;
const player_hit_box_width = @as(f32, @floatFromInt(65)) * player_scale;
const player_hit_box_height = @as(f32, @floatFromInt(70)) * player_scale;
const player_part_offset_x = -player_hit_box_width * 1.4;
const player_part_offset_y = -player_hit_box_height * 1.6;

const max_farmers: u16 = 400;
const farmer_spawn_timer: u64 = 10;
const farmers_to_kill_before_wife_spawns = 100;
const frames_after_wife_kill_to_victory_state = 60 * 10;

pub fn main() anyerror!void {
    if (@import("builtin").mode == .Debug) {
        inline for (comptime Scheduler.dumpDependencyChain(.game_update), 0..) |dep, system_index| {
            std.debug.print("{d}: {any}\n", .{ system_index, dep });
        }
    }

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

    const music = rl.loadMusicStream("resources/music/Gameplay_Loop.wav");
    defer rl.unloadMusicStream(music);
    rl.playMusicStream(music);
    rl.setMusicVolume(music, 0.25);

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    const LoopState = enum {
        main_menu,
        game,
        victory_screen,
    };
    var current_state = LoopState.main_menu;

    outer_loop: while (true) {
        switch (current_state) {
            .main_menu => {
                const load_assets_zone = tracy.ZoneN(@src(), "main menu load assets and init");

                var main_menu_animation = components.AnimTexture{
                    .start_frame = 0,
                    .current_frame = 0,
                    .frame_count = 0,
                    .frames_per_frame = 8,
                    .frames_drawn_current_frame = 0,
                };
                const main_menu_image = load_anim_blk: {
                    var frame_count: i32 = undefined;
                    const image_anim = rl.loadImageAnim(
                        "resources/textures/main_menu/main_menu_background.gif",
                        &frame_count,
                    );
                    main_menu_animation.frame_count = @intCast(frame_count);
                    break :load_anim_blk image_anim;
                };
                defer rl.unloadImage(main_menu_image);

                const main_menu_texture = rl.loadTextureFromImage(main_menu_image);
                defer rl.unloadTexture(main_menu_texture);

                const main_menu_texture_repo = MainTextureRepo.init();
                defer main_menu_texture_repo.deinit();

                load_assets_zone.End();

                while (true) {
                    tracy.FrameMark();

                    // Start music
                    rl.updateMusicStream(music);
                    const time_played = rl.getMusicTimePlayed(music) / rl.getMusicTimeLength(music);
                    if (time_played > 1.0) rl.seekMusicStream(music, 27);
                    // Start draw
                    rl.beginDrawing();
                    defer rl.endDrawing();

                    const rect_render_target = rl.Rectangle{
                        .x = 0,
                        .y = 0,
                        .height = window_height,
                        .width = window_width,
                    };
                    const center = rl.Vector2{ .x = 0, .y = 0 };

                    // Draw background animation
                    {
                        {
                            const rect_texture = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(main_menu_texture.height),
                                .width = @floatFromInt(main_menu_texture.width),
                            };

                            rl.drawTexturePro(main_menu_texture, rect_texture, rect_render_target, center, 0, rl.Color.white);
                        }

                        {
                            const next_frame_data_offset = main_menu_image.width * main_menu_image.height * 4 * main_menu_animation.current_frame;
                            const bytes = @as([*]const u8, @ptrCast(main_menu_image.data));
                            rl.updateTexture(main_menu_texture, bytes[@intCast(next_frame_data_offset)..]);
                        }

                        if (main_menu_animation.frames_drawn_current_frame >= main_menu_animation.frames_per_frame) {
                            main_menu_animation.current_frame = @mod((main_menu_animation.current_frame + 1), main_menu_animation.frame_count);
                            main_menu_animation.frames_drawn_current_frame = 0;
                        } else {
                            main_menu_animation.frames_drawn_current_frame += 1;
                        }
                    }

                    // Draw buttons
                    const buttons = enum {
                        none,
                        start,
                        options,
                        exit,
                    };

                    const button_hovered = button_draw_blk: {
                        var hovered = buttons.none;

                        const normalized_mouse_pos = get_mouse_pos_blk: {
                            const mouse_pos = rl.getMousePosition();

                            break :get_mouse_pos_blk rl.Vector2{
                                .x = mouse_pos.x / window_width,
                                .y = mouse_pos.y / window_height,
                            };
                        };

                        // common for all buttons
                        const normalized_button_x_min = 280.0 / 640.0;
                        const normalized_button_x_max = 410.0 / 640.0;

                        // Start
                        {
                            const normalized_start_y_min = 184.0 / 360.0;
                            const normalized_start_y_max = 232.0 / 360.0;

                            const start_texture_enum = check_cursor_intersect_blk: {
                                const button_bounds = rl.Rectangle{
                                    .x = normalized_button_x_min,
                                    .y = normalized_start_y_min,
                                    .width = normalized_button_x_max - normalized_button_x_min,
                                    .height = normalized_start_y_max - normalized_start_y_min,
                                };
                                if (rl.checkCollisionPointRec(normalized_mouse_pos, button_bounds)) {
                                    hovered = .start;

                                    break :check_cursor_intersect_blk MainTextureRepo.which_button.Start_Active;
                                }

                                break :check_cursor_intersect_blk MainTextureRepo.which_button.Start_Idle;
                            };

                            const start_btn_text = main_menu_texture_repo.button[@intFromEnum(start_texture_enum)];
                            const start_btn_rect = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(start_btn_text.height),
                                .width = @floatFromInt(start_btn_text.width),
                            };

                            start_btn_text.drawPro(start_btn_rect, rect_render_target, center, 0, rl.Color.white);
                        }

                        // Options
                        {
                            const normalized_options_y_min = 239.0 / 360.0;
                            const normalized_options_y_max = 286.0 / 360.0;

                            const options_texture_enum = check_cursor_intersect_blk: {
                                const button_bounds = rl.Rectangle{
                                    .x = normalized_button_x_min,
                                    .y = normalized_options_y_min,
                                    .width = normalized_button_x_max - normalized_button_x_min,
                                    .height = normalized_options_y_max - normalized_options_y_min,
                                };
                                if (rl.checkCollisionPointRec(normalized_mouse_pos, button_bounds)) {
                                    hovered = .options;

                                    break :check_cursor_intersect_blk MainTextureRepo.which_button.Options_Active;
                                }

                                break :check_cursor_intersect_blk MainTextureRepo.which_button.Options_Idle;
                            };

                            const start_btn_text = main_menu_texture_repo.button[@intFromEnum(options_texture_enum)];
                            const start_btn_rect = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(start_btn_text.height),
                                .width = @floatFromInt(start_btn_text.width),
                            };

                            start_btn_text.drawPro(start_btn_rect, rect_render_target, center, 0, rl.Color.white);
                        }

                        // Exit
                        {
                            const normalized_exit_y_min = 293.0 / 360.0;
                            const normalized_exit_y_max = 342.0 / 360.0;

                            const exit_texture_enum = check_cursor_intersect_blk: {
                                const button_bounds = rl.Rectangle{
                                    .x = normalized_button_x_min,
                                    .y = normalized_exit_y_min,
                                    .width = normalized_button_x_max - normalized_button_x_min,
                                    .height = normalized_exit_y_max - normalized_exit_y_min,
                                };
                                if (rl.checkCollisionPointRec(normalized_mouse_pos, button_bounds)) {
                                    hovered = .exit;

                                    break :check_cursor_intersect_blk MainTextureRepo.which_button.Exit_Active;
                                }

                                break :check_cursor_intersect_blk MainTextureRepo.which_button.Exit_Idle;
                            };

                            const start_btn_text = main_menu_texture_repo.button[@intFromEnum(exit_texture_enum)];
                            const start_btn_rect = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(start_btn_text.height),
                                .width = @floatFromInt(start_btn_text.width),
                            };

                            start_btn_text.drawPro(start_btn_rect, rect_render_target, center, 0, rl.Color.white);
                        }

                        break :button_draw_blk hovered;
                    };

                    // Update
                    {
                        if (rl.isMouseButtonPressed(.mouse_button_left)) {
                            switch (button_hovered) {
                                .none => {},
                                .start => {
                                    current_state = .game;
                                    continue :outer_loop;
                                },
                                .options => {
                                    std.debug.print("lol\n\n", .{});
                                },
                                .exit => {
                                    break :outer_loop;
                                },
                            }
                        }
                    }
                }
            },
            .game => {
                const micro_ts = std.time.microTimestamp();
                var prng = std.rand.DefaultPrng.init(@as(*const u64, @ptrCast(&micro_ts)).*);
                const random = prng.random();

                const load_assets_zone = tracy.ZoneN(@src(), "game load assets and init");

                const texture_repo = GameTextureRepo.init();
                defer texture_repo.deinit();

                const sound_repo = GameSoundRepo.init();
                defer sound_repo.deinit();

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

                // Create camera
                const camera_entity = try create_camera_blk: {
                    const Camera = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        camera: components.Camera,
                    };

                    break :create_camera_blk storage.createEntity(Camera{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = 2,
                            .y = 2,
                        },
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
                        scale: components.Scale,
                        collider: components.RectangleCollider,
                        texture: components.Texture,
                    };

                    const horizontal_fence = texture_repo.country[@intFromEnum(GameTextureRepo.which_country_side.Fence_Horizontal)];
                    const hor_fence_height: u32 = @intCast(horizontal_fence.height);
                    const hor_fence_width: u32 = @intCast(horizontal_fence.width);
                    var i: u32 = 0;
                    while (i < arena_width) : (i += hor_fence_width) {
                        // South
                        _ = try storage.createEntity(LevelBoundary{
                            .pos = components.Position{ .vec = zm.f32x4(
                                @floatFromInt(i),
                                arena_height - room_boundary_thickness,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1,
                                .y = 1,
                            },
                            .collider = components.RectangleCollider{
                                .width = @floatFromInt(hor_fence_width),
                                .height = @floatFromInt(hor_fence_height),
                            },
                            .texture = components.Texture{
                                .draw_order = .o1,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Fence_Horizontal),
                            },
                        });
                        // North
                        _ = try storage.createEntity(LevelBoundary{
                            .pos = components.Position{ .vec = zm.f32x4(
                                @floatFromInt(i),
                                0,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1,
                                .y = 1,
                            },
                            .collider = components.RectangleCollider{
                                .width = @floatFromInt(hor_fence_width),
                                .height = @floatFromInt(hor_fence_height),
                            },
                            .texture = components.Texture{
                                .draw_order = .o1,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Fence_Horizontal),
                            },
                        });
                    }
                    const vertical_fence = texture_repo.country[@intFromEnum(GameTextureRepo.which_country_side.Fence_Vertical)];
                    const vert_fence_height: u32 = @intCast(vertical_fence.height);
                    const vert_fence_width: u32 = @intCast(vertical_fence.width);
                    i = 0;
                    while (i < arena_width - vert_fence_height) : (i += vert_fence_height) {
                        // West
                        _ = try storage.createEntity(LevelBoundary{
                            .pos = components.Position{ .vec = zm.f32x4(
                                0,
                                @floatFromInt(i),
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1,
                                .y = 1,
                            },
                            .collider = components.RectangleCollider{
                                .width = @floatFromInt(vert_fence_width),
                                .height = @floatFromInt(vert_fence_height),
                            },
                            .texture = components.Texture{
                                .draw_order = .o1,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Fence_Vertical),
                            },
                        });
                        // East
                        _ = try storage.createEntity(LevelBoundary{
                            .pos = components.Position{ .vec = zm.f32x4(
                                arena_width,
                                @floatFromInt(i),
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1,
                                .y = 1,
                            },
                            .collider = components.RectangleCollider{
                                .width = @floatFromInt(vert_fence_width),
                                .height = @floatFromInt(vert_fence_height),
                            },
                            .texture = components.Texture{
                                .draw_order = .o1,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Fence_Vertical),
                            },
                        });
                    }
                }

                {
                    const GroundClutter = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        texture: components.Texture,
                    };
                    for (0..150) |_| {
                        const pos_x = -arena_width * 0.5 + random.float(f32) * arena_width * 1.5;
                        const pos_y = -arena_height * 0.5 + random.float(f32) * arena_height * 1.5;
                        _ = try storage.createEntity(GroundClutter{
                            .pos = components.Position{ .vec = zm.f32x4(
                                pos_x,
                                pos_y,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 4 + random.float(f32) * 2,
                                .y = 4 + random.float(f32) * 2,
                            },
                            .texture = components.Texture{
                                .draw_order = .o0,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Dirt),
                            },
                        });
                    }
                    for (0..200) |_| {
                        const pos_x = -arena_width * 0.5 + random.float(f32) * arena_width * 1.5;
                        const pos_y = -arena_height * 0.5 + random.float(f32) * arena_height * 1.5;

                        _ = try storage.createEntity(GroundClutter{
                            .pos = components.Position{ .vec = zm.f32x4(
                                pos_x,
                                pos_y,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1 + random.float(f32),
                                .y = 1 + random.float(f32),
                            },
                            .texture = components.Texture{
                                .draw_order = .o0,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Grass),
                            },
                        });
                    }
                    for (0..150) |_| {
                        const pos_x = random.float(f32) * arena_width * 1.5;
                        const pos_y = random.float(f32) * arena_height * 1.5;
                        const texture = if (random.boolean()) @intFromEnum(GameTextureRepo.which_decor.Daisies) else @intFromEnum(GameTextureRepo.which_decor.Rocks);
                        _ = try storage.createEntity(GroundClutter{
                            .pos = components.Position{ .vec = zm.f32x4(
                                pos_x,
                                pos_y,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 0.1 + random.float(f32),
                                .y = 0.1 + random.float(f32),
                            },
                            .texture = components.Texture{
                                .draw_order = .o0,
                                .type = @intFromEnum(GameTextureRepo.texture_type.decor),
                                .index = texture,
                            },
                        });
                    }
                }

                const player_entity = create_player_blk: {
                    const Player = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        vel: components.Velocity,
                        drag: components.Drag,
                        mv_speed: components.MoveSpeed,
                        move_dir: components.DesiredMovedDir,
                        col: components.RectangleCollider,
                        rec_tag: components.DrawRectangleTag,
                        player_tag: components.PlayerTag,
                        health: components.Health,
                        vocals: components.Vocals,
                    };

                    const player = try storage.createEntity(Player{
                        .pos = components.Position{ .vec = zm.f32x4(
                            room_center[0] - player_hit_box_width,
                            room_center[1] - player_hit_box_height,
                            0,
                            0,
                        ) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .drag = components.Drag{ .value = 0.8 },
                        .mv_speed = components.MoveSpeed{
                            // TODO: this will make players with smaller res move faster.
                            .max = 500,
                            .accelerate = 100,
                        },
                        .move_dir = components.DesiredMovedDir{
                            .vec = zm.f32x4s(0),
                        },
                        .col = components.RectangleCollider{
                            .width = player_hit_box_width,
                            .height = player_hit_box_height,
                        },
                        .rec_tag = components.DrawRectangleTag{},
                        .player_tag = components.PlayerTag{},
                        .health = components.Health{
                            .max = 100,
                            .value = 100,
                        },
                        .vocals = components.Vocals{
                            .on_death_start = @intFromEnum(GameSoundRepo.which_effects.Kill),
                            .on_death_end = @intFromEnum(GameSoundRepo.which_effects.Kill),
                            .on_dmg_start = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_01),
                            .on_dmg_end = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_03),
                        },
                    });

                    const PlayerParts = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        vel: components.Velocity,
                        texture: components.Texture,
                        orientation_texture: components.OrientationTexture,
                        child_of: components.ChildOf,
                    };
                    // Cloak
                    _ = try storage.createEntity(PlayerParts{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Cloak0001),
                            .draw_order = .o0,
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Cloak0001),
                        },
                        .child_of = components.ChildOf{
                            .parent = player,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });
                    // Head
                    _ = try storage.createEntity(PlayerParts{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Head0001),
                            .draw_order = .o1,
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Head0001),
                        },
                        .child_of = components.ChildOf{
                            .parent = player,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });
                    // Hat
                    _ = try storage.createEntity(PlayerParts{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Hat0001),
                            .draw_order = .o2,
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Hat0001),
                        },
                        .child_of = components.ChildOf{
                            .parent = player,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });

                    const Hand = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        vel: components.Velocity,
                        texture: components.Texture,
                        orientation_based_draw_order: components.OrientationBasedDrawOrder,
                        orientation_texture: components.OrientationTexture,
                        child_of: components.ChildOf,
                    };
                    // Left hand
                    _ = try storage.createEntity(Hand{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Hand_L0001),
                            .draw_order = .o3,
                        },
                        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
                            .draw_orders = [8]components.Texture.DrawOrder{
                                .o1, // up
                                .o3, // up_left
                                .o3, // left
                                .o3, // left_down
                                .o1, // down
                                .o0, // down_right
                                .o0, // right
                                .o1, // up_right
                            },
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Hand_L0001),
                        },
                        .child_of = components.ChildOf{
                            .parent = player,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });
                    // Right hand
                    _ = try storage.createEntity(Hand{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Hand_R0001),
                            .draw_order = .o3,
                        },
                        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
                            .draw_orders = [8]components.Texture.DrawOrder{
                                .o2, // up
                                .o1, // up_left
                                .o0, // left
                                .o1, // left_down
                                .o2, // down
                                .o3, // down_right
                                .o3, // right
                                .o3, // up_right
                            },
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Hand_R0001),
                        },
                        .child_of = components.ChildOf{
                            .parent = player,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });

                    break :create_player_blk player;
                };

                const player_staff_entity = create_player_staff_blk: {
                    const Staff = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        vel: components.Velocity,
                        texture: components.Texture,
                        orientation_based_draw_order: components.OrientationBasedDrawOrder,
                        orientation_texture: components.OrientationTexture,
                        fire_rate: components.AttackRate,
                        child_of: components.ChildOf,
                        staff: components.Staff,
                    };

                    var staff = components.Staff{
                        .slot_capacity = 8,
                        .used_slots = 4,
                        .slot_cursor = 0,
                        .slots = undefined,
                    };

                    staff.slots[0] = components.Staff.Slot{ .projectile = .{
                        .type = .bolt,
                        .attrs = .{
                            .dmg = 15,
                            .weight = 300,
                        },
                    } };
                    staff.slots[1] = components.Staff.Slot{ .modifier = .dmg_amp };
                    staff.slots[2] = components.Staff.Slot{ .modifier = .piercing };
                    staff.slots[3] = components.Staff.Slot{ .projectile = .{
                        .type = .red_gem,
                        .attrs = .{
                            .dmg = 30,
                            .weight = 3000,
                        },
                    } };

                    break :create_player_staff_blk try storage.createEntity(Staff{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                        },
                        .texture = components.Texture{
                            .type = @intFromEnum(GameTextureRepo.texture_type.player),
                            .index = @intFromEnum(GameTextureRepo.which_player.Staff0001),
                            .draw_order = .o1,
                        },
                        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
                            .draw_orders = [8]components.Texture.DrawOrder{
                                .o1, // up
                                .o0, // up_left
                                .o0, // left
                                .o0, // left_down
                                .o1, // down
                                .o1, // down_right
                                .o2, // right
                                .o2, // up_right
                            },
                        },
                        .orientation_texture = components.OrientationTexture{
                            .start_texture_index = @intFromEnum(GameTextureRepo.which_player.Staff0001),
                        },
                        .fire_rate = components.AttackRate{
                            .cooldown = 10,
                            .active_cooldown = 0,
                        },
                        .child_of = components.ChildOf{
                            .parent = player_entity,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                        .staff = staff,
                    });
                };

                // NOTE 2: Defining null for vertex shader forces usage of internal default vertex shader
                const shader_cauldron = rl.loadShader(null, "resources/shaders/glsl330/cauldron_hp.fs");
                defer rl.unloadShader(shader_cauldron);

                const shader_health_info_location = rl.getShaderLocation(shader_cauldron, "healthRatio");
                const shader_blood_texture_location = rl.getShaderLocation(shader_cauldron, "cauldronBlood");

                load_assets_zone.End();

                var in_inventory = false;

                var nr_farmers: u16 = 0;
                var spawn_cooldown: u64 = 0;

                var the_wife_spawned: bool = false;
                var farmer_kill_count: u64 = 0;
                var the_wife_kill_count: u64 = 0;
                var frames_since_wife_kill: u64 = 0;

                // TODO: pause
                while (!rl.windowShouldClose()) {
                    tracy.FrameMark();

                    const mouse_pos = rl.getMousePosition();

                    if (frames_since_wife_kill >= frames_after_wife_kill_to_victory_state) {
                        current_state = .victory_screen;
                        continue :outer_loop;
                    }
                    if (the_wife_kill_count >= 1) {
                        frames_since_wife_kill += 1;
                    }

                    // Play music
                    rl.updateMusicStream(music);
                    const time_played = rl.getMusicTimePlayed(music) / rl.getMusicTimeLength(music);
                    if (time_played > 1.0) rl.seekMusicStream(music, 27);

                    if (rl.isKeyPressed(rl.KeyboardKey.key_tab)) {
                        in_inventory = !in_inventory;
                    }
                    if (!in_inventory) {
                        spawn_cooldown += 1;

                        if ((max_farmers > nr_farmers) and spawn_cooldown >= farmer_spawn_timer) {
                            const farmer_pos = randomPointOnCircle(arena_height / 3, rl.Vector2{ .x = arena_height / 2, .y = arena_width / 2 }, random);
                            _ = try createFarmer(&storage, zm.f32x4(farmer_pos.x, farmer_pos.y, 0, 0), player_scale);
                            nr_farmers += 1;
                            spawn_cooldown = 0;
                        }

                        if (farmer_kill_count >= farmers_to_kill_before_wife_spawns and the_wife_spawned == false) {
                            the_wife_spawned = true;
                            const farmer_pos = randomPointOnCircle(arena_height / 3, rl.Vector2{ .x = arena_height / 2, .y = arena_width / 2 }, random);
                            _ = try createTheFarmersWife(&storage, zm.f32x4(farmer_pos.x, farmer_pos.y, 0, 0), player_scale);
                        }

                        // Update
                        {
                            // Input handling
                            {
                                inline for (Input.key_down_actions) |input_action| {
                                    if (rl.isKeyDown(input_action.key)) {
                                        input_action.callback(&storage, player_entity, player_staff_entity);
                                    }
                                }
                            }

                            // system update dispatch
                            const update_context = UpdateSystems.Context{
                                .sound_repo = &sound_repo.effects,
                                .rng = random,
                                .farmer_kill_count = &farmer_kill_count,
                                .the_wife_kill_count = &the_wife_kill_count,
                                .cursor_position = mouse_pos,
                                .camera_entity = camera_entity,
                                .player_entity = player_entity,
                            };
                            scheduler.dispatchEvent(&storage, .game_update, update_context);
                            scheduler.waitEvent(.game_update);

                            // Spawn blood splatter
                            try spawnBloodSplatter(&storage, sound_repo, random);
                        }
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
                                    .zoom = camera_zoom.x,
                                };
                            };

                            camera.begin();
                            defer camera.end();

                            rl.clearBackground(rl.Color.dark_brown);

                            {
                                const zone = tracy.ZoneN(@src(), "Texture draw");
                                defer zone.End();

                                const simple_texture_repo = &[_][]const rl.Texture{
                                    &texture_repo.player,
                                    &texture_repo.projectile,
                                    &texture_repo.farmer,
                                    &texture_repo.blood_splatter,
                                    &texture_repo.country,
                                    &texture_repo.inventory,
                                    &texture_repo.decor,
                                    &texture_repo.wife,
                                };

                                const TextureDrawQuery = Storage.Query(struct {
                                    entity: ecez.Entity,
                                    pos: components.Position,
                                    texture: components.Texture,
                                }, .{components.InactiveTag});

                                inline for (@typeInfo(components.Texture.DrawOrder).Enum.fields) |order| {
                                    var texture_iter = TextureDrawQuery.submit(&storage);

                                    while (texture_iter.next()) |texture| {
                                        staticTextureDraw(@enumFromInt(order.value), texture.entity, texture.pos, texture.texture, simple_texture_repo, storage);
                                    }
                                }
                            }

                            if (@import("builtin").mode == .Debug and false) {
                                {
                                    const zone = tracy.ZoneN(@src(), "Debug draw rectangle");
                                    defer zone.End();

                                    const RectangleDrawQuery = Storage.Query(struct {
                                        pos: components.Position,
                                        col: components.RectangleCollider,
                                        _: components.DrawRectangleTag,
                                    }, .{components.InactiveTag});
                                    var rect_iter = RectangleDrawQuery.submit(&storage);
                                    while (rect_iter.next()) |rect| {
                                        const draw_rectangle = rl.Rectangle{
                                            .x = rect.pos.vec[0],
                                            .y = rect.pos.vec[1],
                                            .width = rect.col.width,
                                            .height = rect.col.height,
                                        };

                                        rl.drawRectanglePro(draw_rectangle, rl.Vector2.init(0, 0), 0, rl.Color.red);
                                    }
                                }

                                {
                                    const zone = tracy.ZoneN(@src(), "Debug draw circle");
                                    defer zone.End();

                                    const CircleDrawQuery = Storage.Query(struct {
                                        pos: components.Position,
                                        col: components.CircleCollider,
                                        _: components.DrawCircleTag,
                                    }, .{components.InactiveTag});
                                    var circle_iter = CircleDrawQuery.submit(&storage);

                                    while (circle_iter.next()) |circle| {
                                        const offset = zm.f32x4(@floatCast(circle.col.x), @floatCast(circle.col.y), 0, 0);

                                        rl.drawCircle(
                                            @intFromFloat(circle.pos.vec[0] + @as(f32, @floatCast(offset[0]))),
                                            @intFromFloat(circle.pos.vec[1] + @as(f32, @floatCast(offset[1]))),
                                            circle.col.radius,
                                            rl.Color.blue,
                                        );
                                    }
                                }
                            }
                        }

                        // UI Drawing
                        {
                            const GrabbedItem = struct {
                                pos: components.Position,
                                old_slot: components.OldSlot,
                                inv_item: components.InventoryItem,
                                attach_to_cursor: components.AttachToCursor,
                            };

                            const GrabbedItemQuery = Storage.Query(struct {
                                entity: ecez.Entity,
                                pos: *components.Position,
                                old_slot: components.OldSlot,
                                inv_item: components.InventoryItem,
                                attach_to_cursor: components.AttachToCursor,
                            }, .{components.InactiveTag});

                            const UnusedGrabbedItemQuery = Storage.Query(struct {
                                entity: ecez.Entity,
                                pos: *components.Position,
                                _: components.InactiveTag,
                                old_slot: *components.OldSlot,
                                inv_item: *components.InventoryItem,
                                attach_to_cursor: *components.AttachToCursor,
                            }, .{});

                            const InInventoryItem = struct {
                                pos: components.Position,
                                inv_item: components.InventoryItem,
                            };

                            const InInvenventoryQuery = Storage.Query(struct {
                                entity: ecez.Entity,
                                pos: components.Position,
                                inv_item: components.InventoryItem,
                            }, .{ components.AttachToCursor, components.OldSlot, components.InactiveTag });

                            var staff = storage.getComponent(player_staff_entity, *components.Staff) catch unreachable;
                            const index_slot = @intFromEnum(GameTextureRepo.which_inventory.Slot);
                            const texture_slot = texture_repo.inventory[index_slot];

                            const index_slot_cursor = @intFromEnum(GameTextureRepo.which_inventory.Slot_Cursor);
                            const texture_slot_cursor = texture_repo.inventory[index_slot_cursor];

                            const index_red_gem = @intFromEnum(GameTextureRepo.which_inventory.Red_Gem);
                            const texture_red_gem = texture_repo.inventory[index_red_gem];

                            const index_yellow_gem = @intFromEnum(GameTextureRepo.which_inventory.Yellow_Gem);
                            const texture_yellow_gem = texture_repo.inventory[index_yellow_gem];

                            const index_dmg_amp_mod = @intFromEnum(GameTextureRepo.which_inventory.Damage_Amp_Modifier);
                            const texture_dmg_amp_mod = texture_repo.inventory[index_dmg_amp_mod];

                            const index_piercing_modifier = @intFromEnum(GameTextureRepo.which_inventory.Piercing_Modifier);
                            const texture_piercing_modifier = texture_repo.inventory[index_piercing_modifier];

                            const index_bag = @intFromEnum(GameTextureRepo.which_inventory.Gem_Bag);
                            const texture_bag = texture_repo.inventory[index_bag];

                            const next_projectile = input.nextStaffProjectileIndex(staff.*) orelse 255;

                            const inventory_rect = rl.Rectangle{
                                .x = (window_width / 2) - window_height / 4,
                                .y = window_height / 3,
                                .height = window_height / 2,
                                .width = window_height / 2,
                            };
                            const item_rect = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .width = @floatFromInt(texture_slot.width),
                                .height = @floatFromInt(texture_slot.height),
                            };

                            if (in_inventory) {
                                const rect_source = rl.Rectangle{
                                    .x = 0,
                                    .y = 0,
                                    .height = @floatFromInt(texture_bag.height),
                                    .width = @floatFromInt(texture_bag.width),
                                };
                                rl.drawTexturePro(
                                    texture_bag,
                                    rect_source,
                                    inventory_rect,
                                    rl.Vector2{ .x = 0, .y = 0 },
                                    0.0,
                                    rl.Color.white,
                                );

                                var inventory_item_iterator = InInvenventoryQuery.submit(&storage);
                                while (inventory_item_iterator.next()) |item| {
                                    const texture = switch (item.inv_item.item) {
                                        .projectile => |proj| switch (proj.type) {
                                            .bolt => texture_yellow_gem,
                                            .red_gem => texture_red_gem,
                                        },
                                        .modifier => |mod| switch (mod) {
                                            .piercing => texture_piercing_modifier,
                                            .dmg_amp => texture_dmg_amp_mod,
                                        },
                                    };

                                    const pos = rl.Vector2{
                                        .x = item.pos.vec[0],
                                        .y = item.pos.vec[1],
                                    };
                                    rl.drawTextureRec(texture, item_rect, pos, rl.Color.white);

                                    var grabbed_query = GrabbedItemQuery.submit(&storage);
                                    const no_grabbed_item = grabbed_query.next() == null;

                                    if (no_grabbed_item) {
                                        const is_hovered = rl.checkCollisionPointRec(mouse_pos, rl.Rectangle{
                                            .x = pos.x,
                                            .y = pos.y,
                                            .height = @floatFromInt(texture_slot.height),
                                            .width = @floatFromInt(texture_slot.width),
                                        });

                                        if (is_hovered and rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
                                            const offset_x = -item_rect.width * 0.5;
                                            try storage.setComponents(item.entity, .{
                                                components.AttachToCursor{
                                                    .offset_x = offset_x,
                                                    .offset_y = 0,
                                                },
                                                components.OldSlot{ .type = .{
                                                    .inventory_pos = item.pos,
                                                } },
                                            });
                                        }
                                    }
                                }
                            }

                            const gem_width = 75.0;
                            const gem_start_pos = (window_width / 2) - ((@as(f32, @floatFromInt(staff.slot_capacity)) * gem_width) / 2) + (@as(f32, @floatFromInt(texture_slot.width)) / 2);

                            // Draw staff as gem background when in inventory
                            if (in_inventory) {
                                const staff_texture_index = @intFromEnum(GameTextureRepo.which_inventory.Gem_Slot_Staff_Background);
                                const staff_texture = texture_repo.inventory[staff_texture_index];

                                const rotated_height = gem_width * @as(f32, @floatFromInt(staff.slot_capacity)) * 2.0; // width after rotation
                                const height_change_ratio = rotated_height / @as(f32, @floatFromInt(staff_texture.height));

                                const pos = rl.Vector2{
                                    .x = (window_width / 2) - rotated_height * 0.5,
                                    .y = window_height - window_height * 0.1 + (@as(f32, @floatFromInt(staff_texture.width)) * height_change_ratio) * 0.5 + gem_width * 0.5,
                                };

                                rl.drawTextureEx(
                                    staff_texture,
                                    pos,
                                    270,
                                    height_change_ratio,
                                    rl.Color.white,
                                );
                            }

                            // Draw bottom ui with staff gem slots
                            for (0..staff.slot_capacity) |i| {
                                const pos = rl.Vector2{
                                    .x = gem_start_pos + @as(f32, @floatFromInt(i)) * gem_width,
                                    .y = window_height - window_height * 0.1,
                                };

                                var storable_item = false;
                                const grabbable_item: ?components.InventoryItem.Item = check_may_grab_blk: {
                                    const is_hovered = rl.checkCollisionPointRec(mouse_pos, rl.Rectangle{
                                        .x = pos.x,
                                        .y = pos.y,
                                        .height = @floatFromInt(texture_slot.height),
                                        .width = @floatFromInt(texture_slot.width),
                                    });

                                    if (false == is_hovered) {
                                        break :check_may_grab_blk null;
                                    }

                                    const grabbable = switch (staff.slots[i]) {
                                        .none => null,
                                        .projectile => |proj| components.InventoryItem.Item{
                                            .projectile = proj,
                                        },
                                        .modifier => |mod| components.InventoryItem.Item{
                                            .modifier = mod,
                                        },
                                    };

                                    const grab_offset_x = -item_rect.width * 0.5;

                                    var grabbed_item_iter = GrabbedItemQuery.submit(&storage);
                                    const grabbed_item = grabbed_item_iter.next();
                                    if (rl.isMouseButtonReleased(.mouse_button_left)) {
                                        if (grabbed_item) |grabbed| {
                                            const add_to_staff_slot_count = swap_with_existing_slot_item_blk: {
                                                // If we are hovering a item in the slot
                                                if (grabbable) |grabbable_item| {
                                                    // Swap depending on item type we are swapping
                                                    switch (grabbed.old_slot.type) {
                                                        .staff_index => |index| {
                                                            switch (grabbable_item) {
                                                                .projectile => |proj| staff.slots[index] = .{ .projectile = proj },
                                                                .modifier => |mod| staff.slots[index] = .{ .modifier = mod },
                                                            }

                                                            break :swap_with_existing_slot_item_blk false;
                                                        },
                                                        .inventory_pos => |inv_pos| {
                                                            // TODO: query unused before create
                                                            _ = try storage.createEntity(InInventoryItem{
                                                                .pos = inv_pos,
                                                                .inv_item = components.InventoryItem{
                                                                    .item = grabbable_item,
                                                                },
                                                            });

                                                            break :swap_with_existing_slot_item_blk true;
                                                        },
                                                    }
                                                }

                                                break :swap_with_existing_slot_item_blk true;
                                            };

                                            switch (grabbed.inv_item.item) {
                                                .projectile => |proj| staff.slots[i] = .{ .projectile = proj },
                                                .modifier => |mod| staff.slots[i] = .{ .modifier = mod },
                                            }

                                            if (add_to_staff_slot_count) {
                                                staff.used_slots = @mod(staff.used_slots + 1, staff.slot_capacity);
                                            }

                                            try storage.setComponents(grabbed.entity, .{components.InactiveTag{}});

                                            break :check_may_grab_blk null;
                                        }
                                    }

                                    if (false == in_inventory or null != grabbed_item) {
                                        storable_item = null != grabbed_item;
                                        break :check_may_grab_blk null;
                                    }

                                    if (grabbable) |grab_item| {
                                        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
                                            staff.slot_cursor = 0;
                                            staff.slots[i] = .none;
                                            staff.used_slots -= 1;

                                            var unused_grabbed_item_iter = UnusedGrabbedItemQuery.submit(&storage);
                                            if (unused_grabbed_item_iter.next()) |unused_grabbed_item| {
                                                unused_grabbed_item.old_slot.* = components.OldSlot{
                                                    .type = .{ .staff_index = @intCast(i) },
                                                };
                                                unused_grabbed_item.inv_item.item = grab_item;
                                                unused_grabbed_item.attach_to_cursor.offset_x = grab_offset_x;

                                                storage.unsetComponents(unused_grabbed_item.entity, .{components.InactiveTag});
                                            } else {
                                                _ = try storage.createEntity(GrabbedItem{
                                                    .pos = components.Position{
                                                        .vec = zm.f32x4s(0), // set later
                                                    },
                                                    .old_slot = components.OldSlot{
                                                        .type = .{ .staff_index = @intCast(i) },
                                                    },
                                                    .inv_item = components.InventoryItem{
                                                        .item = grab_item,
                                                    },
                                                    .attach_to_cursor = components.AttachToCursor{
                                                        .offset_x = grab_offset_x,
                                                        .offset_y = 0,
                                                    },
                                                });
                                            }
                                        }
                                    }

                                    break :check_may_grab_blk grabbable;
                                };

                                const slot_texture = slot_texture_blk: {
                                    if (i == next_projectile) {
                                        break :slot_texture_blk texture_slot_cursor;
                                    } else {
                                        break :slot_texture_blk texture_slot;
                                    }
                                };
                                rl.drawTextureRec(
                                    slot_texture,
                                    item_rect,
                                    pos,
                                    if (grabbable_item != null or storable_item) rl.Color.red else rl.Color.white,
                                );

                                const gem_texture = switch (staff.slots[i]) {
                                    .none => null,
                                    .projectile => |proj| switch (proj.type) {
                                        .bolt => texture_yellow_gem,
                                        .red_gem => texture_red_gem,
                                    },
                                    .modifier => |mod| switch (mod) {
                                        .piercing => texture_piercing_modifier,
                                        .dmg_amp => texture_dmg_amp_mod,
                                    },
                                };
                                if (gem_texture) |texture| {
                                    rl.drawTextureRec(
                                        texture,
                                        item_rect,
                                        pos,
                                        rl.Color.white,
                                    );
                                }
                            }

                            var attached_iter = GrabbedItemQuery.submit(&storage);
                            if (attached_iter.next()) |grabbed| {
                                if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left) and in_inventory) {
                                    const is_inventory_hovered = rl.checkCollisionPointRec(mouse_pos, inventory_rect);
                                    if (is_inventory_hovered) {
                                        grabbed.pos.vec = zm.f32x4(
                                            mouse_pos.x + grabbed.attach_to_cursor.offset_x,
                                            mouse_pos.y + grabbed.attach_to_cursor.offset_y,
                                            0,
                                            0,
                                        );

                                        storage.unsetComponents(grabbed.entity, .{
                                            components.OldSlot,
                                            components.AttachToCursor,
                                        });
                                    } else {
                                        switch (grabbed.old_slot.type) {
                                            .staff_index => |index| {
                                                switch (grabbed.inv_item.item) {
                                                    .projectile => |proj| staff.slots[index].projectile = proj,
                                                    .modifier => |mod| staff.slots[index].modifier = mod,
                                                }
                                                staff.slot_cursor = 0;
                                                staff.used_slots += 1;
                                                try storage.setComponents(grabbed.entity, .{components.InactiveTag{}});
                                            },
                                            .inventory_pos => |inv_pos| {
                                                grabbed.pos.* = inv_pos;
                                                storage.unsetComponents(grabbed.entity, .{
                                                    components.OldSlot,
                                                    components.AttachToCursor,
                                                });
                                            },
                                        }
                                    }
                                } else {
                                    const pos = rl.Vector2{
                                        .x = mouse_pos.x + grabbed.attach_to_cursor.offset_x,
                                        .y = mouse_pos.y + grabbed.attach_to_cursor.offset_y,
                                    };

                                    const gem_texture = switch (grabbed.inv_item.item) {
                                        .projectile => |proj| switch (proj.type) {
                                            .bolt => texture_yellow_gem,
                                            .red_gem => texture_red_gem,
                                        },
                                        .modifier => |mod| switch (mod) {
                                            .piercing => texture_piercing_modifier,
                                            .dmg_amp => texture_dmg_amp_mod,
                                        },
                                    };
                                    rl.drawTextureRec(gem_texture, item_rect, pos, rl.Color.white);
                                }
                            }

                            // Draw cauldron (health indicator)
                            {
                                const cauldron_texture_index = @intFromEnum(GameTextureRepo.which_cauldron.HP_Cauldron);
                                const cauldron_texture = texture_repo.cauldron[cauldron_texture_index];
                                const cauldron_rect = rl.Rectangle{
                                    .x = 0,
                                    .y = 0,
                                    .width = @floatFromInt(cauldron_texture.width),
                                    .height = @floatFromInt(cauldron_texture.height),
                                };
                                const cauldron_dest = rl.Rectangle{
                                    .x = window_width * 0.1,
                                    .y = window_height * 0.8,
                                    .width = window_width * 0.08,
                                    .height = window_width * 0.08,
                                };

                                rl.drawTexturePro(
                                    cauldron_texture,
                                    cauldron_rect,
                                    cauldron_dest,
                                    rl.Vector2.zero(),
                                    0,
                                    rl.Color.white,
                                );

                                {
                                    rl.beginShaderMode(shader_cauldron);
                                    defer rl.endShaderMode();

                                    // set cauldron texture once
                                    const blood_texture_index = @intFromEnum(GameTextureRepo.which_cauldron.HP_Blood);
                                    const blood_texture = texture_repo.cauldron[blood_texture_index];

                                    rl.setShaderValueTexture(shader_cauldron, shader_blood_texture_location, blood_texture);
                                    {
                                        const player_health = try storage.getComponent(player_entity, components.Health);
                                        const health_ratio = @as(f32, @floatFromInt(player_health.value)) / @as(f32, @floatFromInt(player_health.max));
                                        rl.setShaderValue(
                                            shader_cauldron,
                                            shader_health_info_location,
                                            @ptrCast(&health_ratio),
                                            rl.ShaderUniformDataType.shader_uniform_float,
                                        );
                                    }

                                    const mask_texture_index = @intFromEnum(GameTextureRepo.which_cauldron.HP_Mask);
                                    const mask_texture = texture_repo.cauldron[mask_texture_index];

                                    rl.drawTexturePro(
                                        mask_texture,
                                        cauldron_rect,
                                        cauldron_dest,
                                        rl.Vector2.zero(),
                                        0,
                                        rl.Color.white,
                                    );
                                }
                            }

                            // Draw tooltip for hovered gems
                            if (in_inventory) draw_tooltip_blk: {
                                const drawTooltip = struct {
                                    pub inline fn draw(tooltip_texture: rl.Texture, source_rect: rl.Rectangle, mouse: rl.Vector2, pos: rl.Vector2, txt: [*:0]const u8) bool {
                                        const is_hovered = rl.checkCollisionPointRec(mouse, rl.Rectangle{
                                            .x = pos.x,
                                            .y = pos.y,
                                            .width = @floatFromInt(tooltip_texture.width),
                                            .height = @floatFromInt(tooltip_texture.height),
                                        });

                                        if (is_hovered) {
                                            const tooltip_pos = rl.Vector2{
                                                .x = pos.x + @as(f32, @floatFromInt(tooltip_texture.width)),
                                                .y = pos.y - @as(f32, @floatFromInt(tooltip_texture.height)),
                                            };

                                            const dest_rect = rl.Rectangle{
                                                .x = tooltip_pos.x,
                                                .y = tooltip_pos.y - source_rect.height * 3.0 * 0.5,
                                                .width = source_rect.width * 4.0,
                                                .height = source_rect.height * 2.0,
                                            };

                                            rl.drawTexturePro(
                                                tooltip_texture,
                                                source_rect,
                                                dest_rect,
                                                rl.Vector2.zero(),
                                                0,
                                                rl.Color.red,
                                            );
                                            rl.drawText(
                                                txt,
                                                @intFromFloat(dest_rect.x + 12 * 3),
                                                @intFromFloat(dest_rect.y + 10 * 3),
                                                18,
                                                rl.Color.ray_white,
                                            );
                                        }

                                        return is_hovered;
                                    }
                                }.draw;

                                // Check first if cursor overlap staff gems
                                for (0..staff.slot_capacity) |i| {
                                    if (staff.slots[i] == .none) continue;

                                    const pos = rl.Vector2{
                                        .x = gem_start_pos + @as(f32, @floatFromInt(i)) * gem_width,
                                        .y = window_height - window_height * 0.1,
                                    };

                                    var buf: [256]u8 = undefined;
                                    const txt = switch (staff.slots[i]) {
                                        .projectile => |proj| try std.fmt.bufPrintZ(&buf, "{s}\nDamage: {d}\nKnockback: {d}", .{ @tagName(proj.type), proj.attrs.dmg, proj.attrs.weight }),
                                        .modifier => |mod| try std.fmt.bufPrintZ(&buf, "{s}", .{@tagName(mod)}),
                                        .none => unreachable,
                                    };

                                    if (drawTooltip(texture_slot, item_rect, mouse_pos, pos, txt)) {
                                        break :draw_tooltip_blk;
                                    }
                                }

                                var inventory_iter = InInvenventoryQuery.submit(&storage);
                                while (inventory_iter.next()) |inv_item| {
                                    const pos = rl.Vector2{
                                        .x = inv_item.pos.vec[0],
                                        .y = inv_item.pos.vec[1],
                                    };

                                    var buf: [256]u8 = undefined;
                                    const txt = switch (inv_item.inv_item.item) {
                                        .projectile => |proj| try std.fmt.bufPrintZ(&buf, "{s}\nDamage: {d}\nKnockback: {d}", .{ @tagName(proj.type), proj.attrs.dmg, proj.attrs.weight }),
                                        .modifier => |mod| try std.fmt.bufPrintZ(&buf, "{s}", .{@tagName(mod)}),
                                    };

                                    if (drawTooltip(texture_slot, item_rect, mouse_pos, pos, txt)) {
                                        break :draw_tooltip_blk;
                                    }
                                }
                            }
                        }
                    }
                }
                break;
            },
            .victory_screen => {
                const load_assets_zone = tracy.ZoneN(@src(), "main menu load assets and init");
                const image = rl.loadImage("resources/textures/victory_screen/Victory_Screen.png");
                defer rl.unloadImage(image);
                const victory_texture = rl.loadTextureFromImage(image);
                defer rl.unloadTexture(victory_texture);

                load_assets_zone.End();
                const main_menu_texture_repo = MainTextureRepo.init();
                defer main_menu_texture_repo.deinit();
                while (true) {
                    tracy.FrameMark();

                    // Start music
                    rl.updateMusicStream(music);
                    const time_played = rl.getMusicTimePlayed(music) / rl.getMusicTimeLength(music);
                    if (time_played > 1.0) rl.seekMusicStream(music, 27);
                    // Start draw
                    rl.beginDrawing();
                    defer rl.endDrawing();

                    const rect_render_target = rl.Rectangle{
                        .x = 0,
                        .y = 0,
                        .height = window_height,
                        .width = window_width,
                    };
                    const center = rl.Vector2{ .x = 0, .y = 0 };

                    // Draw background
                    {
                        {
                            const rect_texture = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(victory_texture.height),
                                .width = @floatFromInt(victory_texture.width),
                            };

                            rl.drawTexturePro(victory_texture, rect_texture, rect_render_target, center, 0, rl.Color.white);
                        }
                    }
                    // Draw buttons
                    const buttons = enum {
                        none,
                        exit,
                    };
                    const button_hovered = button_draw_blk: {
                        var hovered = buttons.none;

                        const normalized_mouse_pos = get_mouse_pos_blk: {
                            const mouse_pos = rl.getMousePosition();

                            break :get_mouse_pos_blk rl.Vector2{
                                .x = mouse_pos.x / window_width,
                                .y = mouse_pos.y / window_height,
                            };
                        };

                        // common for all buttons
                        const normalized_button_x_min = 280.0 / 640.0;
                        const normalized_button_x_max = 410.0 / 640.0;

                        // Exit
                        {
                            const normalized_exit_y_min = 293.0 / 360.0;
                            const normalized_exit_y_max = 342.0 / 360.0;

                            const exit_texture_enum = check_cursor_intersect_blk: {
                                const button_bounds = rl.Rectangle{
                                    .x = normalized_button_x_min,
                                    .y = normalized_exit_y_min,
                                    .width = normalized_button_x_max - normalized_button_x_min,
                                    .height = normalized_exit_y_max - normalized_exit_y_min,
                                };
                                if (rl.checkCollisionPointRec(normalized_mouse_pos, button_bounds)) {
                                    hovered = .exit;

                                    break :check_cursor_intersect_blk MainTextureRepo.which_button.Exit_Active;
                                }

                                break :check_cursor_intersect_blk MainTextureRepo.which_button.Exit_Idle;
                            };

                            const start_btn_text = main_menu_texture_repo.button[@intFromEnum(exit_texture_enum)];
                            const start_btn_rect = rl.Rectangle{
                                .x = 0,
                                .y = 0,
                                .height = @floatFromInt(start_btn_text.height),
                                .width = @floatFromInt(start_btn_text.width),
                            };

                            start_btn_text.drawPro(start_btn_rect, rect_render_target, center, 0, rl.Color.white);
                        }

                        break :button_draw_blk hovered;
                    };

                    // Update
                    {
                        if (rl.isMouseButtonPressed(.mouse_button_left)) {
                            switch (button_hovered) {
                                .none => {},
                                .exit => {
                                    break :outer_loop;
                                },
                            }
                        }
                    }
                }
            },
        }
    }
}

// TODO: Body parts can be generic for player, farmer and wife
fn createFarmer(storage: *Storage, pos: zm.Vec, scale: f32) error{OutOfMemory}!ecez.Entity {
    const zone = tracy.ZoneN(@src(), @src().fn_name);
    defer zone.End();

    const Farmer = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        drag: components.Drag,
        mv_speed: components.MoveSpeed,
        move_dir: components.DesiredMovedDir,
        col: components.RectangleCollider,
        rec_tag: components.DrawRectangleTag,
        attack_rate: components.AttackRate,
        hostile_tag: components.HostileTag,
        farmer_tag: components.FarmerTag,
        melee: components.Melee,
        health: components.Health,
        vocals: components.Vocals,
    };

    const farmer = try storage.createEntity(Farmer{
        .pos = components.Position{ .vec = pos },
        .scale = components.Scale{ .x = scale, .y = scale },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .drag = components.Drag{ .value = 0.7 },
        .mv_speed = components.MoveSpeed{
            .max = 240,
            .accelerate = 40,
        },
        .move_dir = components.DesiredMovedDir{
            .vec = zm.f32x4s(0),
        },
        .col = components.RectangleCollider{
            .width = player_hit_box_width,
            .height = player_hit_box_height,
        },
        .rec_tag = components.DrawRectangleTag{},
        .attack_rate = components.AttackRate{
            .active_cooldown = 0,
            .cooldown = 60 * 3,
        },
        .hostile_tag = components.HostileTag{},
        .farmer_tag = components.FarmerTag{},
        .melee = components.Melee{
            .dmg = 5,
            .range = 50,
        },
        .health = components.Health{
            .max = 50,
            .value = 50,
        },
        .vocals = components.Vocals{
            .on_death_start = @intFromEnum(GameSoundRepo.which_effects.Kill),
            .on_death_end = @intFromEnum(GameSoundRepo.which_effects.Kill),
            .on_dmg_start = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_01),
            .on_dmg_end = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_03),
        },
    });

    const FarmerParts = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        texture: components.Texture,
        orientation_texture: components.OrientationTexture,
        child_of: components.ChildOf,
    };
    // Cloak
    _ = try storage.createEntity(FarmerParts{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.farmer),
            .index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Body0001),
            .draw_order = .o0,
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Body0001),
        },
        .child_of = components.ChildOf{
            .parent = farmer,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });
    // Head
    _ = try storage.createEntity(FarmerParts{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.farmer),
            .index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Head0001),
            .draw_order = .o1,
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Head0001),
        },
        .child_of = components.ChildOf{
            .parent = farmer,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });
    // Hat
    _ = try storage.createEntity(FarmerParts{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.farmer),
            .index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hat0001),
            .draw_order = .o2,
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hat0001),
        },
        .child_of = components.ChildOf{
            .parent = farmer,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });

    const Hand = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        texture: components.Texture,
        orientation_based_draw_order: components.OrientationBasedDrawOrder,
        orientation_texture: components.OrientationTexture,
        child_of: components.ChildOf,
    };
    // Left hand
    _ = try storage.createEntity(Hand{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.farmer),
            .index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hand_L0001),
            .draw_order = .o3,
        },
        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
            .draw_orders = [8]components.Texture.DrawOrder{
                .o1, // up
                .o3, // up_left
                .o3, // left
                .o3, // left_down
                .o1, // down
                .o0, // down_right
                .o0, // right
                .o1, // up_right
            },
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hand_L0001),
        },
        .child_of = components.ChildOf{
            .parent = farmer,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });
    // Right hand
    _ = try storage.createEntity(Hand{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.farmer),
            .index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hand_R0001),
            .draw_order = .o3,
        },
        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
            .draw_orders = [8]components.Texture.DrawOrder{
                .o2, // up
                .o1, // up_left
                .o0, // left
                .o1, // left_down
                .o2, // down
                .o3, // down_right
                .o3, // right
                .o3, // up_right
            },
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_farmer.Farmer_Hand_R0001),
        },
        .child_of = components.ChildOf{
            .parent = farmer,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });

    return farmer;
}

// TODO: Body parts can be generic for player, farmer and wife
fn createTheFarmersWife(storage: *Storage, pos: zm.Vec, scale: f32) error{OutOfMemory}!ecez.Entity {
    const zone = tracy.ZoneN(@src(), @src().fn_name);
    defer zone.End();

    const Wife = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        drag: components.Drag,
        mv_speed: components.MoveSpeed,
        move_dir: components.DesiredMovedDir,
        col: components.RectangleCollider,
        rec_tag: components.DrawRectangleTag,
        attack_rate: components.AttackRate,
        hostile_tag: components.HostileTag,
        wife_tag: components.FarmersWifeTag,
        melee: components.Melee,
        health: components.Health,
        vocals: components.Vocals,
    };

    const the_wife = try storage.createEntity(Wife{
        .pos = components.Position{ .vec = pos },
        .scale = components.Scale{ .x = scale, .y = scale },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .drag = components.Drag{
            .value = 0.7,
        },
        .mv_speed = components.MoveSpeed{
            .max = 300,
            .accelerate = 45,
        },
        .move_dir = components.DesiredMovedDir{
            .vec = zm.f32x4s(0),
        },
        .col = components.RectangleCollider{
            .width = player_hit_box_width * 1.5,
            .height = player_hit_box_height * 1.5,
        },
        .rec_tag = components.DrawRectangleTag{},
        .attack_rate = components.AttackRate{
            .active_cooldown = 0,
            .cooldown = 60 * 3,
        },
        .hostile_tag = components.HostileTag{},
        .wife_tag = components.FarmersWifeTag{},
        .health = components.Health{
            .max = 500,
            .value = 500,
        },
        .melee = components.Melee{
            .dmg = 10,
            .range = 80,
        },
        .vocals = components.Vocals{
            .on_death_start = @intFromEnum(GameSoundRepo.which_effects.Kill),
            .on_death_end = @intFromEnum(GameSoundRepo.which_effects.Kill),
            .on_dmg_start = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_01),
            .on_dmg_end = @intFromEnum(GameSoundRepo.which_effects.Player_Damage_03),
        },
    });

    const WifeParts = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        texture: components.Texture,
        orientation_texture: components.OrientationTexture,
        child_of: components.ChildOf,
    };
    // Chest
    _ = try storage.createEntity(WifeParts{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.wife),
            .index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Body0001),
            .draw_order = .o0,
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Body0001),
        },
        .child_of = components.ChildOf{
            .parent = the_wife,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });
    // Head
    _ = try storage.createEntity(WifeParts{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.wife),
            .index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Head0001),
            .draw_order = .o1,
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Head0001),
        },
        .child_of = components.ChildOf{
            .parent = the_wife,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });

    const Hand = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        texture: components.Texture,
        orientation_based_draw_order: components.OrientationBasedDrawOrder,
        orientation_texture: components.OrientationTexture,
        child_of: components.ChildOf,
    };
    // Left hand
    _ = try storage.createEntity(Hand{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.wife),
            .index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Hand_L0001),
            .draw_order = .o3,
        },
        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
            .draw_orders = [8]components.Texture.DrawOrder{
                .o1, // up
                .o3, // up_left
                .o3, // left
                .o3, // left_down
                .o1, // down
                .o0, // down_right
                .o0, // right
                .o1, // up_right
            },
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Hand_L0001),
        },
        .child_of = components.ChildOf{
            .parent = the_wife,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });
    // Right hand
    _ = try storage.createEntity(Hand{
        .pos = components.Position{ .vec = zm.f32x4s(0) },
        .scale = components.Scale{ .x = 1, .y = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
        },
        .texture = components.Texture{
            .type = @intFromEnum(GameTextureRepo.texture_type.wife),
            .index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Hand_R0001),
            .draw_order = .o3,
        },
        .orientation_based_draw_order = components.OrientationBasedDrawOrder{
            .draw_orders = [8]components.Texture.DrawOrder{
                .o2, // up
                .o1, // up_left
                .o0, // left
                .o1, // left_down
                .o2, // down
                .o3, // down_right
                .o3, // right
                .o3, // up_right
            },
        },
        .orientation_texture = components.OrientationTexture{
            .start_texture_index = @intFromEnum(GameTextureRepo.which_wife.Wife_Idle_Hand_R0001),
        },
        .child_of = components.ChildOf{
            .parent = the_wife,
            .offset_x = player_part_offset_x,
            .offset_y = player_part_offset_y,
        },
    });

    return the_wife;
}

pub fn spawnBloodSplatter(
    storage: *Storage,
    sound_repo: GameSoundRepo,
    rng: std.Random,
) !void {
    const zone = tracy.ZoneN(@src(), @src().fn_name);
    defer zone.End();

    const GoreSplatter = struct {
        pos: components.Position,
        rot: components.Rotation,
        scale: components.Scale,
        texture: components.Texture,
        anim: components.AnimTexture,
        lifetime: components.LifeTime,
        blood_gore_tag: components.BloodGoreGroundTag,
    };
    const InactiveGoreSplatterQuery = Storage.Query(struct {
        entity: ecez.Entity,
        pos: *components.Position,
        rot: *components.Rotation,
        scale: *components.Scale,
        texture: *components.Texture,
        anim: *components.AnimTexture,
        lifetime: *components.LifeTime,
        inactive_tag: components.InactiveTag,
        blood_gore_tag: components.BloodGoreGroundTag,
    }, .{});
    var inactive_gore_iter = InactiveGoreSplatterQuery.submit(storage);

    const BloodSplatter = struct {
        pos: components.Position,
        scale: components.Scale,
        texture: components.Texture,
        lifetime: components.LifeTime,
        blood_splatter_tag: components.BloodSplatterGroundTag,
    };
    const InactiveBloodSplatterQuery = Storage.Query(struct {
        entity: ecez.Entity,
        pos: *components.Position,
        scale: *components.Scale,
        texture: *components.Texture,
        lifetime: *components.LifeTime,
        inactive_tag: components.InactiveTag,
        blood_splatter_tag: components.BloodSplatterGroundTag,
    }, .{});
    var inactive_blood_iter = InactiveBloodSplatterQuery.submit(storage);

    const DiedThisFrameQuery = Storage.Query(struct {
        entity: ecez.Entity,
        pos: components.Position,
        died: components.DiedThisFrameTag,
    }, .{});
    var died_this_frame_iter = DiedThisFrameQuery.submit(storage);

    const CameraQuery = Storage.Query(
        struct {
            pos: components.Position,
            scale: components.Scale,
            cam: components.Camera,
        },
        // exclude type
        .{components.InactiveTag},
    );
    var camera_iter = CameraQuery.submit(storage);
    const camera = camera_iter.next().?;

    while (died_this_frame_iter.next()) |dead_this_frame| {
        const scale = storage.getComponent(dead_this_frame.entity, components.Scale) catch components.Scale{ .x = 1, .y = 1 };
        const splatter_offset = zm.f32x4(-100 * scale.x, -100 * scale.y, 0, 0);

        const position = components.Position{
            .vec = dead_this_frame.pos.vec + splatter_offset,
        };

        const blood_splatterlifetime: f32 = 6;
        if (inactive_blood_iter.next()) |inactive_blood_splatter| {
            storage.unsetComponents(inactive_blood_splatter.entity, .{components.InactiveTag});
            inactive_blood_splatter.pos.* = position;
            inactive_blood_splatter.scale.* = scale;
            inactive_blood_splatter.lifetime.* = components.LifeTime{ .value = blood_splatterlifetime };
        } else {
            _ = try storage.createEntity(BloodSplatter{
                .pos = position,
                .scale = scale,
                .texture = components.Texture{
                    .type = @intFromEnum(GameTextureRepo.texture_type.blood_splatter),
                    .index = @intFromEnum(GameTextureRepo.which_bloodsplat.Blood_Splat),
                    .draw_order = .o0,
                },
                .blood_splatter_tag = .{},
                .lifetime = components.LifeTime{ .value = blood_splatterlifetime },
            });
        }

        const anim = components.AnimTexture{
            .start_frame = @intFromEnum(GameTextureRepo.which_bloodsplat.Blood_Splat0001),
            .current_frame = 0,
            .frame_count = 8,
            .frames_per_frame = 4,
            .frames_drawn_current_frame = 0,
        };
        const lifetime_comp = components.LifeTime{
            .value = @as(f32, @floatFromInt(anim.frame_count)) * @as(f32, @floatFromInt(anim.frames_per_frame)) / 60.0,
        };

        const gore_scale = components.Scale{ .x = scale.x * 2, .y = scale.y * 2 }; // gore should be larger than blood
        const gore_pos = components.Position{
            .vec = position.vec + zm.f32x4(-50, -40, 0, 0),
        };
        if (inactive_gore_iter.next()) |inactive_gore| {
            storage.unsetComponents(inactive_gore.entity, .{components.InactiveTag});
            inactive_gore.pos.* = gore_pos;
            inactive_gore.scale.* = gore_scale;
            // inactive_gore.anim.* = anim;
            inactive_gore.lifetime.* = lifetime_comp;
        } else {
            const splatter_index = rng.intRangeAtMost(u8, @intFromEnum(GameSoundRepo.which_effects.Splatter_01), @intFromEnum(GameSoundRepo.which_effects.Splatter_03));
            const splatter_sound = sound_repo.effects[splatter_index];

            const pan = ((gore_pos.vec - camera.pos.vec)[0] * camera.scale.x) / camera.cam.width;
            rl.setSoundPan(splatter_sound, pan);
            rl.playSound(splatter_sound);

            _ = try storage.createEntity(GoreSplatter{
                .pos = gore_pos,
                .rot = components.Rotation{ .value = 0 },
                .scale = gore_scale,
                .texture = components.Texture{
                    .type = @intFromEnum(GameTextureRepo.texture_type.blood_splatter),
                    .index = @intFromEnum(GameTextureRepo.which_bloodsplat.Blood_Splat0001),
                    .draw_order = .o1,
                },
                .anim = anim,
                .lifetime = lifetime_comp,
                .blood_gore_tag = .{},
            });
        }

        storage.unsetComponents(dead_this_frame.entity, .{components.DiedThisFrameTag});
    }
}

pub fn staticTextureDraw(
    comptime order: components.Texture.DrawOrder,
    entity: ecez.Entity,
    pos: components.Position,
    static_texture: components.Texture,
    texture_repo: []const []const rl.Texture,
    storage: Storage,
) void {
    const zone = tracy.ZoneN(@src(), @src().fn_name ++ " " ++ @tagName(order));
    defer zone.End();

    if (static_texture.draw_order != order) return;

    const rotation = storage.getComponent(entity, components.Rotation) catch components.Rotation{ .value = 0 };
    const scale = storage.getComponent(entity, components.Scale) catch components.Scale{ .x = 1, .y = 1 };
    const texture = texture_repo[static_texture.type][static_texture.index];

    const rect_texture = rl.Rectangle{
        .x = 0,
        .y = 0,
        .height = @floatFromInt(texture.height),
        .width = @floatFromInt(texture.width),
    };
    const rect_render_target = rl.Rectangle{
        .x = pos.vec[0],
        .y = pos.vec[1],
        .height = @as(f32, @floatFromInt(texture.height)) * scale.x,
        .width = @as(f32, @floatFromInt(texture.width)) * scale.y,
    };
    const center = rl.Vector2{ .x = 0, .y = 0 };

    rl.drawTexturePro(texture, rect_texture, rect_render_target, center, rotation.value, rl.Color.white);
}

fn randomPointOnCircle(radius: usize, pos: rl.Vector2, rand: std.Random) rl.Vector2 {
    const rand_value = rand.float(f32);
    const angle: f32 = rand_value * std.math.tau;
    const x = @as(f32, @floatFromInt(radius)) * @cos(angle);
    const y = @as(f32, @floatFromInt(radius)) * @sin(angle);

    return rl.Vector2{ .x = x + pos.x, .y = y + pos.y };
}

test {
    _ = @import("physics_2d.zig");
}

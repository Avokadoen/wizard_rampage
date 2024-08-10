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
            UpdateSystems.UpdateVelocity,
            ecez.DependOn(UpdateSystems.MovableToImmovableRecToRecCollisionResolve, .{UpdateSystems.UpdateVelocity}),
            ecez.DependOn(UpdateSystems.MovableToMovableRecToRecCollisionResolve, .{UpdateSystems.MovableToImmovableRecToRecCollisionResolve}),
            ecez.DependOn(UpdateSystems.InherentFromParent, .{UpdateSystems.MovableToMovableRecToRecCollisionResolve}),
            ecez.DependOn(UpdateSystems.ProjectileHitKillable, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.RegisterDead, .{UpdateSystems.ProjectileHitKillable}),
            ecez.DependOn(UpdateSystems.TargetPlayer, .{UpdateSystems.RegisterDead}),
            // run in parallel
            ecez.DependOn(UpdateSystems.UpdateCamera, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.OrientTexture, .{UpdateSystems.InherentFromParent}),
            // end run in parallel
            ecez.DependOn(UpdateSystems.OrientationBasedDrawOrder, .{UpdateSystems.OrientTexture}),
            // flush in game loop
        }, UpdateSystems.Context),
        ecez.Event(
            "game_draw",
            .{
                // !! ALL SYSTEMS MUST BE DEPEND ON PREVIOUS FOR DRAW !!
                DrawSystems.Rectangle,
                ecez.DependOn(DrawSystems.StaticTextureOrder0, .{DrawSystems.Rectangle}),
                ecez.DependOn(DrawSystems.StaticTextureOrder1, .{DrawSystems.StaticTextureOrder0}),
                ecez.DependOn(DrawSystems.StaticTextureOrder2, .{DrawSystems.StaticTextureOrder1}),
                ecez.DependOn(DrawSystems.StaticTextureOrder3, .{DrawSystems.StaticTextureOrder2}),
                ecez.DependOn(DrawSystems.Circle, .{DrawSystems.StaticTextureOrder3}),
            },
            DrawSystems.Context,
        ),
    },
);

// Some hard-coded values for now! :D
const player_scale: f32 = 0.4;
const player_hit_box_width = @as(f32, @floatFromInt(65)) * player_scale;
const player_hit_box_height = @as(f32, @floatFromInt(70)) * player_scale;
const player_part_offset_x = -player_hit_box_width * 1.4;
const player_part_offset_y = -player_hit_box_height * 1.6;

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

    const music = rl.loadMusicStream("resources/music/Gameplay_Loop.wav");
    defer rl.unloadMusicStream(music);
    rl.playMusicStream(music);
    rl.setMusicVolume(music, 0.25);

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    const LoopState = enum {
        main_menu,
        game,
    };
    var current_state = LoopState.game;

    outer_loop: while (true) {
        switch (current_state) {
            .main_menu => {
                var main_menu_animation = components.AnimTexture{
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

                while (true) {
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

                            const start_btn_text = main_menu_texture_repo.button_textures[@intFromEnum(start_texture_enum)];
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

                            const start_btn_text = main_menu_texture_repo.button_textures[@intFromEnum(options_texture_enum)];
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

                            const start_btn_text = main_menu_texture_repo.button_textures[@intFromEnum(exit_texture_enum)];
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
                //rl.updateMusicStream(music);
                //const time_played_test = rl.getMusicTimePlayed(music) / rl.getMusicTimeLength(music);
                //if (time_played_test > 1.0) rl.seekMusicStream(music, 27);
                const texture_repo = GameTextureRepo.init();
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
                        rec_tag: components.DrawRectangleTag,
                        player_tag: components.PlayerTag,
                        health: components.Health,
                    };

                    const player = try storage.createEntity(Player{
                        .pos = components.Position{ .vec = zm.f32x4(
                            room_center[0] - player_hit_box_width,
                            room_center[1] - player_hit_box_height,
                            0,
                            0,
                        ) },
                        .scale = components.Scale{ .value = player_scale },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 0.8,
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
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 1,
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
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 1,
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
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 0.94,
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
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 1,
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
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 1,
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
                        fire_rate: components.FireRate,
                        child_of: components.ChildOf,
                    };
                    break :create_player_staff_blk try storage.createEntity(Staff{
                        .pos = components.Position{ .vec = zm.f32x4s(0) },
                        .scale = components.Scale{ .value = 1 },
                        .vel = components.Velocity{
                            .vec = zm.f32x4s(0),
                            .drag = 1,
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
                        .fire_rate = components.FireRate{
                            .base_fire_rate = 60,
                            .cooldown_fire_rate = 0,
                        },
                        .child_of = components.ChildOf{
                            .parent = player_entity,
                            .offset_x = player_part_offset_x,
                            .offset_y = player_part_offset_y,
                        },
                    });
                };

                // Create camera
                const camera_entity = try create_camera_blk: {
                    const Camera = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        camera: components.Camera,
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

                const farmer = try createFarmer(&storage, zm.f32x4(0, 0, 0, 0), player_scale);
                _ = farmer; // autofix

                // TODO: pause
                while (!rl.windowShouldClose()) {
                    // Play music
                    rl.updateMusicStream(music);
                    const time_played = rl.getMusicTimePlayed(music) / rl.getMusicTimeLength(music);
                    if (time_played > 1.0) rl.seekMusicStream(music, 27);
                    // Update
                    {
                        // Input handling
                        {
                            const player_pos_ptr = try storage.getComponent(player_entity, *components.Position);
                            const player_vec_ptr = try storage.getComponent(player_entity, *components.Velocity);
                            const player_fire_rate = try storage.getComponent(player_staff_entity, *components.FireRate);
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
                                .texture_repo = [_][]const rl.Texture{
                                    &texture_repo.player_textures,
                                    &texture_repo.projectile_textures,
                                    &texture_repo.farmer_textures,
                                },
                                .storage = storage,
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
                break;
            },
        }
    }
}

// TODO: Body parts can be generic for player, farmer and wife
fn createFarmer(storage: *Storage, pos: zm.Vec, scale: f32) error{OutOfMemory}!ecez.Entity {
    const Farmer = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        col: components.RectangleCollider,
        rec_tag: components.DrawRectangleTag,
        hostile_tag: components.HostileTag,
        health: components.Health,
    };

    const farmer = try storage.createEntity(Farmer{
        .pos = components.Position{ .vec = pos },
        .scale = components.Scale{ .value = scale },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 0.7,
        },
        .col = components.RectangleCollider{
            .width = player_hit_box_width,
            .height = player_hit_box_height,
        },
        .rec_tag = components.DrawRectangleTag{},
        .hostile_tag = components.HostileTag{},
        .health = components.Health{
            .max = 50,
            .value = 50,
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
        .scale = components.Scale{ .value = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 1,
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
        .scale = components.Scale{ .value = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 1,
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
        .scale = components.Scale{ .value = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 0.94,
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
        .scale = components.Scale{ .value = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 1,
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
        .scale = components.Scale{ .value = 1 },
        .vel = components.Velocity{
            .vec = zm.f32x4s(0),
            .drag = 1,
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

test {
    _ = @import("physics_2d.zig");
}

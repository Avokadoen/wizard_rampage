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
const DrawSystems = systems.CreateDrawSystems(Storage);

const Scheduler = ecez.CreateScheduler(
    Storage,
    .{
        ecez.Event("game_update", .{
            UpdateSystems.FireRate,
            UpdateSystems.LifeTime,
            UpdateSystems.UpdateVelocity,
            ecez.DependOn(UpdateSystems.RotateAfterVelocity, .{UpdateSystems.UpdateVelocity}),
            ecez.DependOn(UpdateSystems.MovableToImmovableRecToRecCollisionResolve, .{UpdateSystems.RotateAfterVelocity}),
            ecez.DependOn(UpdateSystems.MovableToMovableRecToRecCollisionResolve, .{UpdateSystems.MovableToImmovableRecToRecCollisionResolve}),
            ecez.DependOn(UpdateSystems.InherentFromParent, .{UpdateSystems.MovableToMovableRecToRecCollisionResolve}),
            ecez.DependOn(UpdateSystems.ProjectileHitKillable, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.RegisterDead, .{UpdateSystems.ProjectileHitKillable}),
            ecez.DependOn(UpdateSystems.TargetPlayer, .{UpdateSystems.RegisterDead}),
            // run in parallel
            ecez.DependOn(UpdateSystems.UpdateCamera, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.OrientTexture, .{UpdateSystems.InherentFromParent}),
            ecez.DependOn(UpdateSystems.AnimateTexture, .{UpdateSystems.InherentFromParent}),
            // end run in parallel
            ecez.DependOn(UpdateSystems.OrientationBasedDrawOrder, .{UpdateSystems.OrientTexture}),
            // flush in game loop
        }, UpdateSystems.Context),
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

                //create grass and dirt
                const random_point_on_circle = struct {
                    fn randomPointOnCircle(radius: usize, pos: rl.Vector2, rand: std.Random) rl.Vector2 {
                        const rand_value = rand.float(f32);
                        const angle: f32 = rand_value * std.math.tau;
                        const x = @as(f32, @floatFromInt(radius)) * @cos(angle);
                        const y = @as(f32, @floatFromInt(radius)) * @sin(angle);

                        return rl.Vector2{ .x = x + pos.x, .y = y + pos.y };
                    }
                }.randomPointOnCircle;

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

                const player_entity = create_player_blk: {
                    const Player = struct {
                        pos: components.Position,
                        scale: components.Scale,
                        vel: components.Velocity,
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
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
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
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
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
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
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
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
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
                        .scale = components.Scale{
                            .x = player_scale,
                            .y = player_scale,
                        },
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
                        .scale = components.Scale{
                            .x = 1,
                            .y = 1,
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
                        // // South
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
                                .draw_order = .o2,
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
                                .draw_order = .o2,
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
                                .draw_order = .o2,
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
                                .draw_order = .o2,
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
                    const center = rl.Vector2{
                        .x = window_height / 2,
                        .y = window_width / 2,
                    };
                    for (0..@intFromFloat(window_width / 3)) |i| {
                        const pos_dirt = random_point_on_circle(i * 3, center, random);
                        _ = try storage.createEntity(GroundClutter{
                            .pos = components.Position{ .vec = zm.f32x4(
                                pos_dirt.x,
                                pos_dirt.y,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 5,
                                .y = 5,
                            },
                            .texture = components.Texture{
                                .draw_order = .o0,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Dirt),
                            },
                        });
                    }
                    for (0..@intFromFloat(window_width / 2)) |i| {
                        const pos_grass = random_point_on_circle(i * 2, center, random);

                        _ = try storage.createEntity(GroundClutter{
                            .pos = components.Position{ .vec = zm.f32x4(
                                pos_grass.x,
                                pos_grass.y,
                                0,
                                0,
                            ) },
                            .scale = components.Scale{
                                .x = 1,
                                .y = 1,
                            },
                            .texture = components.Texture{
                                .draw_order = .o0,
                                .type = @intFromEnum(GameTextureRepo.texture_type.country),
                                .index = @intFromEnum(GameTextureRepo.which_country_side.Grass),
                            },
                        });
                    }
                }

                load_assets_zone.End();
                const max_farmers: u16 = 1000;
                var nr_farmers: u16 = 0;
                const spawn_timer: u64 = 10;
                var spawn_cooldown: u64 = 0;
                // TODO: pause
                while (!rl.windowShouldClose()) {
                    spawn_cooldown += 1;

                    if ((max_farmers > nr_farmers) and spawn_cooldown >= spawn_timer) {
                        const farmer_pos = random_point_on_circle(arena_height / 3, rl.Vector2{ .x = arena_height / 2, .y = arena_width / 2 }, random);
                        _ = try createFarmer(&storage, zm.f32x4(farmer_pos.x, farmer_pos.y, 0, 0), player_scale);
                        nr_farmers += 1;
                        spawn_cooldown = 0;
                    }
                    tracy.FrameMark();

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
                            .sound_repo = &sound_repo.effects,
                            .rng = random,
                        };
                        scheduler.dispatchEvent(&storage, .game_update, update_context);
                        scheduler.waitEvent(.game_update);

                        try storage.flushStorageQueue(); // flush any edits which occured in dispatch game_update

                        // Spawn blood splatter
                        try spawnBloodSplatter(allocator, &storage, sound_repo, random);
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

                            rl.clearBackground(rl.Color.ray_white);

                            {
                                const zone = tracy.ZoneN(@src(), "Texture draw");
                                defer zone.End();

                                const simple_texture_repo = &[_][]const rl.Texture{
                                    &texture_repo.player,
                                    &texture_repo.projectile,
                                    &texture_repo.farmer,
                                    &texture_repo.blood_splatter,
                                    &texture_repo.country,
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

                            if (@import("builtin").mode == .Debug) {
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
    const zone = tracy.ZoneN(@src(), @src().fn_name);
    defer zone.End();

    const Farmer = struct {
        pos: components.Position,
        scale: components.Scale,
        vel: components.Velocity,
        col: components.RectangleCollider,
        rec_tag: components.DrawRectangleTag,
        hostile_tag: components.HostileTag,
        health: components.Health,
        vocals: components.Vocals,
    };

    const farmer = try storage.createEntity(Farmer{
        .pos = components.Position{ .vec = pos },
        .scale = components.Scale{ .x = scale, .y = scale },
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
        .scale = components.Scale{ .x = 1, .y = 1 },
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
        .scale = components.Scale{ .x = 1, .y = 1 },
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
        .scale = components.Scale{ .x = 1, .y = 1 },
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
        .scale = components.Scale{ .x = 1, .y = 1 },
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

pub fn spawnBloodSplatter(
    allocator: std.mem.Allocator,
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

    // WORKAROUND:
    // If we dont defer creation of blood splatter and gore, then we do UB in ecez.
    // This can be somewhat improved with https://github.com/Avokadoen/ecez/issues/184
    // and potentially with https://github.com/Avokadoen/ecez/issues/183
    var deferred_blood_splatter_entities = std.ArrayList(BloodSplatter).init(allocator);
    defer deferred_blood_splatter_entities.deinit();
    var deferred_gore_splatter_entities = std.ArrayList(GoreSplatter).init(allocator);
    defer deferred_gore_splatter_entities.deinit();

    while (died_this_frame_iter.next()) |dead_this_frame| {
        const scale = storage.getComponent(dead_this_frame.entity, components.Scale) catch components.Scale{ .x = 1, .y = 1 };
        const splatter_offset = zm.f32x4(-100 * scale.x, -100 * scale.y, 0, 0);

        const position = components.Position{
            .vec = dead_this_frame.pos.vec + splatter_offset,
        };

        const blood_splatterlifetime: f32 = 6;
        if (inactive_blood_iter.next()) |inactive_blood_splatter| {
            try storage.queueRemoveComponent(inactive_blood_splatter.entity, components.InactiveTag);
            inactive_blood_splatter.pos.* = position;
            inactive_blood_splatter.scale.* = scale;
            inactive_blood_splatter.lifetime.* = components.LifeTime{ .value = blood_splatterlifetime };
        } else {
            try deferred_blood_splatter_entities.append(BloodSplatter{
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
            try storage.queueRemoveComponent(inactive_gore.entity, components.InactiveTag);
            inactive_gore.pos.* = gore_pos;
            inactive_gore.scale.* = gore_scale;
            // inactive_gore.anim.* = anim;
            inactive_gore.lifetime.* = lifetime_comp;
        } else {
            const splatter_index = rng.intRangeAtMost(u8, @intFromEnum(GameSoundRepo.which_effects.Splatter_01), @intFromEnum(GameSoundRepo.which_effects.Splatter_03));
            rl.playSound(sound_repo.effects[splatter_index]);

            try deferred_gore_splatter_entities.append(GoreSplatter{
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

        try storage.queueRemoveComponent(dead_this_frame.entity, components.DiedThisFrameTag);
    }

    try storage.flushStorageQueue();

    // NOTE: splatter has no guaretee to be of same length (lifetime is not the same between)
    for (deferred_blood_splatter_entities.items) |blood_splatter| {
        _ = try storage.createEntity(blood_splatter);
    }
    for (deferred_gore_splatter_entities.items) |gore_splatter| {
        _ = try storage.createEntity(gore_splatter);
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

test {
    _ = @import("physics_2d.zig");
}

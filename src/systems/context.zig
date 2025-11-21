const std = @import("std");
const rl = @import("raylib");
const ecez = @import("ecez");
const quad_tree = @import("../quad_tree.zig");

pub fn ContextType(comptime Storage: type) type {
    return struct {
        const Context = @This();

        pub const delta_time: f32 = 1.0 / 60.0;

        sound_repo: []const rl.Sound,
        rng: std.Random,
        // TODO: make atomic
        farmer_kill_count: *u64,
        the_wife_kill_count: *u64,
        player_is_dead: *bool,
        cursor_position: rl.Vector2,
        camera_entity: ecez.Entity,
        player_entity: ecez.Entity,
        collision_as: *const quad_tree.CreateQuadTree(Storage),
    };
}

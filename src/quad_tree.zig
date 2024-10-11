const std = @import("std");
const Allocator = std.mem.Allocator;

const ecez = @import("ecez");
const rl = @import("raylib");
const tracy = @import("ztracy");

const components = @import("components.zig");
const physics_2d = @import("physics_2d.zig");

pub const null_index = std.math.maxInt(u16);
pub const Node = struct {
    parent_index: u16,
    child_node_indices: [4]u16 = [_]u16{null_index} ** 4,
};
pub const LeafNode = struct {
    parent_index: u16,

    circle_movable_entities: std.ArrayListUnmanaged(ecez.Entity) = .{},
    rect_movable_entities: std.ArrayListUnmanaged(ecez.Entity) = .{},
    immovable_entities: std.ArrayListUnmanaged(ecez.Entity) = .{},

    pub fn isActive(self: LeafNode) bool {
        return self.parent_index != null_index;
    }
};

// TODO: force use arena allocator
pub fn CreateQuadTree(comptime Storage: type) type {
    return struct {
        const QuadTree = @This();

        const tree_depth = 6;

        outer_bounds: rl.Vector2,

        node_storage: std.ArrayListUnmanaged(Node),
        leaf_node_storage: std.ArrayListUnmanaged(LeafNode),

        // unused node indices
        vacant_node_index_storage: std.ArrayListUnmanaged(u16) = .{},
        // unused leaf node indices
        vacant_leaf_node_index_storage: std.ArrayListUnmanaged(u16) = .{},

        pub fn init(
            allocator: Allocator,
            outer_bounds: rl.Vector2,
            initial_node_capacity: u32,
            initial_leaf_node_capacity: u32,
        ) error{OutOfMemory}!QuadTree {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            var node_storage = try std.ArrayListUnmanaged(Node).initCapacity(
                allocator,
                initial_node_capacity,
            );
            try node_storage.append(allocator, Node{ .parent_index = 0 });
            errdefer node_storage.deinit(allocator);

            const leaf_node_storage = try std.ArrayListUnmanaged(LeafNode).initCapacity(
                allocator,
                initial_leaf_node_capacity,
            );
            errdefer leaf_node_storage.deinit(allocator);

            return QuadTree{
                .outer_bounds = outer_bounds,
                .node_storage = node_storage,
                .leaf_node_storage = leaf_node_storage,
            };
        }

        pub fn deinit(self: *QuadTree, allocator: Allocator) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            for (self.leaf_node_storage.items) |*leaf| {
                leaf.circle_movable_entities.deinit(allocator);
                leaf.rect_movable_entities.deinit(allocator);
                leaf.immovable_entities.deinit(allocator);
            }

            self.node_storage.deinit(allocator);
            self.leaf_node_storage.deinit(allocator);
            self.vacant_node_index_storage.deinit(allocator);
            self.vacant_leaf_node_index_storage.deinit(allocator);
        }

        // Assuming positions are bottom left
        pub fn insertImmovableEntities(self: *QuadTree, allocator: Allocator, storage: *Storage) error{OutOfMemory}!void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const ImmovableRectangleQuery = Storage.Query(struct {
                entity: ecez.Entity,
                pos: components.Position,
                col: components.RectangleCollider,
            }, .{
                components.InactiveTag,
                components.Velocity,
            });
            try self.genericInsert(allocator, storage, ImmovableRectangleQuery, EntityType.immovable);
        }

        pub fn updateMovableEntities(self: *QuadTree, allocator: Allocator, storage: *Storage) error{OutOfMemory}!void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            { // remove movable entities from leaf nodes
                for (self.leaf_node_storage.items) |*leaf| {
                    leaf.circle_movable_entities.clearRetainingCapacity();
                    leaf.rect_movable_entities.clearRetainingCapacity();
                }
            }

            const MovableRectangleQuery = Storage.Query(struct {
                entity: ecez.Entity,
                pos: components.Position,
                col: components.RectangleCollider,
                _: components.Velocity,
            }, .{
                components.InactiveTag,
            });
            try self.genericInsert(allocator, storage, MovableRectangleQuery, EntityType.rect_movable);

            const MovableCircleQuery = Storage.Query(struct {
                entity: ecez.Entity,
                pos: components.Position,
                col: components.CircleCollider,
                _: components.Velocity,
            }, .{
                components.InactiveTag,
            });
            try self.genericInsert(allocator, storage, MovableCircleQuery, EntityType.circle_movable);

            { // wipe any empty nodes
                wipe_leaf_loop: for (self.leaf_node_storage.items, 0..) |*leaf, leaf_index_usize| {
                    const leaf_index: u16 = @intCast(leaf_index_usize);

                    // Vacant leaf node, dont touch.
                    if (null_index == leaf.parent_index) {
                        continue :wipe_leaf_loop;
                    }

                    const entity_count = leaf.immovable_entities.items.len + leaf.circle_movable_entities.items.len + leaf.rect_movable_entities.items.len;
                    if (0 != entity_count) {
                        // leaf node has other childre, dont wipe!
                        continue :wipe_leaf_loop;
                    }

                    // Remove leaf node from parent node
                    var parent_index: u16 = leaf.parent_index;
                    for (&self.node_storage.items[parent_index].child_node_indices) |*child_index| {
                        if (child_index.* == leaf_index) {
                            child_index.* = null_index;
                        }
                    }

                    // Tag leaf node as vacant
                    leaf.parent_index = null_index;
                    try self.vacant_leaf_node_index_storage.append(allocator, leaf_index);

                    // Remove empty nodes in the chain
                    for (0..tree_depth - 1) |_| {

                        // Count parent children
                        var child_count: u8 = 0;
                        for (self.node_storage.items[parent_index].child_node_indices) |child_index| {
                            if (child_index != null_index) {
                                child_count += 1;
                            }
                        }

                        // Parent has other children, dont "delete"
                        if (child_count != 0) {
                            continue :wipe_leaf_loop;
                        }

                        // Never register root node as vacant
                        if (parent_index != 0) {
                            try self.vacant_node_index_storage.append(allocator, parent_index);
                        }

                        // Re-assign parent, remove current from parent children list
                        const current_index = parent_index;
                        parent_index = self.node_storage.items[parent_index].parent_index;
                        for (&self.node_storage.items[parent_index].child_node_indices) |*child_index| {
                            if (child_index.* == current_index) {
                                child_index.* = null_index;
                            }
                        }
                    }
                }
            }
        }

        pub fn getLeafPos(self: QuadTree, world_pos: rl.Vector2) rl.Vector2 {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            std.debug.assert(world_pos.x >= 0 and world_pos.x < self.outer_bounds.x);
            std.debug.assert(world_pos.y >= 0 and world_pos.y < self.outer_bounds.y);

            var local_pos = world_pos.divide(self.outer_bounds);
            for (0..tree_depth) |_| {
                const cell_coord = local_pos.scale(2);
                std.debug.assert(cell_coord.x < 2);
                std.debug.assert(cell_coord.y < 2);

                local_pos = rl.Vector2{
                    .x = cell_coord.x - @trunc(cell_coord.x),
                    .y = cell_coord.y - @trunc(cell_coord.y),
                };
            }

            return local_pos;
        }

        pub const EntityType = enum(u2) {
            circle_movable,
            rect_movable,
            immovable,
        };
        pub fn appendEntity(self: *QuadTree, allocator: Allocator, pos: rl.Vector2, entity: ecez.Entity, comptime entity_type: EntityType) error{OutOfMemory}!void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            // TODO: current impl is pretty bad precision wise. We should compare arg pos with cell pos instead of mutating a sing pos var
            std.debug.assert(pos.x >= 0 and pos.x < self.outer_bounds.x);
            std.debug.assert(pos.y >= 0 and pos.y < self.outer_bounds.y);

            var local_pos = pos.divide(self.outer_bounds);
            var current_node_index: u16 = 0;

            for (0..tree_depth - 1) |_| {
                const next_node_index = calc_next_index_blk: {
                    // Get fraction part of grid_coord
                    const cell_coord = local_pos.scale(2);
                    std.debug.assert(cell_coord.x < 2);
                    std.debug.assert(cell_coord.y < 2);

                    const child_index: usize = @intFromFloat(@floor(cell_coord.x) + @floor(cell_coord.y) * 2);

                    var next_index = self.node_storage.items[current_node_index].child_node_indices[child_index];

                    // If node does not exist, create node
                    if (null_index == next_index) {
                        // if vacant slot available, use that instead of creating new node
                        if (self.vacant_node_index_storage.popOrNull()) |vacant_node_index| {
                            next_index = vacant_node_index;
                            self.node_storage.items[next_index] = Node{
                                .parent_index = current_node_index,
                            };
                        } else {
                            // No vacant slot, create new node
                            next_index = @intCast(self.node_storage.items.len);
                            try self.node_storage.append(allocator, Node{
                                .parent_index = current_node_index,
                            });
                        }

                        self.node_storage.items[current_node_index].child_node_indices[child_index] = next_index;
                    }

                    local_pos = rl.Vector2{
                        .x = cell_coord.x - @trunc(cell_coord.x),
                        .y = cell_coord.y - @trunc(cell_coord.y),
                    };

                    break :calc_next_index_blk next_index;
                };

                current_node_index = next_node_index;
            }

            const cell_coord = local_pos.scale(2);
            const child_index: usize = @intFromFloat(@floor(cell_coord.x) + @floor(cell_coord.y) * 2);
            var next_index = self.node_storage.items[current_node_index].child_node_indices[child_index];

            // If leaf node does not exist, create leaf node
            if (null_index == next_index) {
                if (self.vacant_leaf_node_index_storage.popOrNull()) |vacant_node_index| {
                    next_index = vacant_node_index;
                    self.leaf_node_storage.items[next_index].parent_index = current_node_index;
                    self.leaf_node_storage.items[next_index].circle_movable_entities.clearRetainingCapacity();
                    self.leaf_node_storage.items[next_index].rect_movable_entities.clearRetainingCapacity();
                    self.leaf_node_storage.items[next_index].immovable_entities.clearRetainingCapacity();
                } else {
                    next_index = @intCast(self.leaf_node_storage.items.len);
                    try self.leaf_node_storage.append(allocator, LeafNode{
                        .parent_index = current_node_index,
                    });
                }

                self.node_storage.items[current_node_index].child_node_indices[child_index] = next_index;
            }

            var leaf_node = &self.leaf_node_storage.items[next_index];
            switch (entity_type) {
                .circle_movable => try leaf_node.circle_movable_entities.append(allocator, entity),
                .rect_movable => try leaf_node.rect_movable_entities.append(allocator, entity),
                .immovable => try leaf_node.immovable_entities.append(allocator, entity),
            }
        }

        pub fn debugDrawTree(self: QuadTree, node: Node, node_pos: rl.Vector2, depth: u32) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const child_node_size = self.nodeSize(depth + 1);

            const depth_color_map = init_color_map_blk: {
                var map = [_]rl.Color{
                    rl.Color.yellow,
                    rl.Color.violet,
                    rl.Color.pink,
                    rl.Color.orange,
                    rl.Color.lime,
                    rl.Color.gold,
                    rl.Color.dark_blue,
                    rl.Color.purple,
                };
                for (&map) |*color| {
                    color.a = 255 / tree_depth;
                }

                break :init_color_map_blk map;
            };
            const color_index = @rem(depth, depth_color_map.len);

            const is_parent_node = depth < tree_depth - 1;
            for (node.child_node_indices, 0..) |child_node_index, child_index| {
                if (null_index != child_node_index) {
                    const child_offset = rl.Vector2{
                        .x = @as(f32, @floatFromInt(@rem(child_index, 2))) * child_node_size.x,
                        .y = @as(f32, @floatFromInt(@divFloor(child_index, 2))) * child_node_size.y,
                    };
                    const child_pos = node_pos.add(child_offset);

                    const draw_rectangle = rl.Rectangle{
                        .x = child_pos.x,
                        .y = child_pos.y,
                        .width = child_node_size.x,
                        .height = child_node_size.y,
                    };
                    rl.drawRectanglePro(draw_rectangle, rl.Vector2.init(0, 0), 0, depth_color_map[color_index]);

                    if (is_parent_node) {
                        debugDrawTree(self, self.node_storage.items[child_node_index], child_pos, depth + 1);
                    }
                }
            }
        }

        fn genericInsert(self: *QuadTree, allocator: Allocator, storage: *Storage, comptime Query: type, comptime entity_type: EntityType) error{OutOfMemory}!void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            const leaf_size = self.nodeSize(tree_depth);

            var query = Query.submit(storage);
            while (query.next()) |entity| {
                // Start by finding pos point

                const pos, const x_span, const y_span = calc_span_blk: {
                    switch (@TypeOf(entity.col)) {
                        components.RectangleCollider => {
                            const leaf_cell_pos = self.getLeafPos(entity.pos.vec);
                            const x_span_float = @floor((leaf_cell_pos.x * leaf_size.x + entity.col.dim.x) / leaf_size.x);
                            const y_span_float = @floor((leaf_cell_pos.y * leaf_size.y + entity.col.dim.y) / leaf_size.y);
                            break :calc_span_blk .{
                                entity.pos.vec,
                                @as(usize, @intFromFloat(x_span_float)),
                                @as(usize, @intFromFloat(y_span_float)),
                            };
                        },
                        components.CircleCollider => {
                            const center_pos = entity.pos.vec.add(rl.Vector2{
                                .x = @floatCast(entity.col.x),
                                .y = @floatCast(entity.col.y),
                            });
                            const corner_pos = center_pos.subtract(rl.Vector2{
                                .x = entity.col.radius,
                                .y = entity.col.radius,
                            });
                            const leaf_cell_pos = self.getLeafPos(corner_pos);

                            // TODO: this includes edge cells that might not actually contain the circle colliders
                            const x_span_float = @floor((leaf_cell_pos.x * leaf_size.x + entity.col.radius * 2) / leaf_size.x);
                            const y_span_float = @floor((leaf_cell_pos.y * leaf_size.y + entity.col.radius * 2) / leaf_size.y);
                            break :calc_span_blk .{
                                corner_pos,
                                @as(usize, @intFromFloat(x_span_float)),
                                @as(usize, @intFromFloat(y_span_float)),
                            };
                        },
                        else => |T| @compileError("Unknown collider type " ++ @typeName(T)),
                    }
                };

                for (0..y_span + 1) |y_offset| {
                    for (0..x_span + 1) |x_offset| {
                        const append_pos = pos.add(rl.Vector2{
                            .x = @as(f32, @floatFromInt(x_offset)) * leaf_size.x,
                            .y = @as(f32, @floatFromInt(y_offset)) * leaf_size.y,
                        });
                        try self.appendEntity(allocator, append_pos, entity.entity, entity_type);
                    }
                }
            }
        }

        inline fn nodeSize(self: QuadTree, depth: u32) rl.Vector2 {
            return self.outer_bounds.divide(rl.Vector2{
                .x = @floatFromInt(@as(u32, 1) << @as(u5, @intCast(depth))),
                .y = @floatFromInt(@as(u32, 1) << @as(u5, @intCast(depth))),
            });
        }
    };
}

const std = @import("std");

const zm = @import("zmath");

const components = @import("components.zig");

pub fn cubeToPoints(cube: components.CubeShape, pos: components.Position) [8]zm.Vec {
    const x = pos.vec[0];
    const y = pos.vec[1];
    const z = pos.vec[2];
    const pos_w: f32 = x + (cube.width * 0.5);
    const pos_h: f32 = y + (cube.height * 0.5);
    const pos_d: f32 = z + (cube.width * 0.5);

    const neg_w: f32 = x - (cube.width * 0.5);
    const neg_h: f32 = y - (cube.height * 0.5);
    const neg_d: f32 = z - (cube.width * 0.5);

    return [8]zm.Vec{
        .{ neg_w, neg_h, pos_d, 0 },
        .{ pos_w, neg_h, pos_d, 0 },
        .{ pos_w, pos_h, pos_d, 0 },
        .{ neg_w, pos_h, pos_d, 0 },
        .{ neg_w, pos_h, neg_d, 0 },
        .{ neg_w, neg_h, neg_d, 0 },
        .{ pos_w, neg_h, neg_d, 0 },
        .{ pos_w, pos_h, neg_d, 0 },
    };
}

pub fn sameDirection(a: zm.Vec, b: zm.Vec) bool {
    return zm.dot4(a, b)[0] > 0;
}

// Sources:
//  - https://en.wikipedia.org/wiki/Gilbert%E2%80%93Johnson%E2%80%93Keerthi_distance_algorithm
//  - https://www.youtube.com/watch?v=MDusDn8oTSE
//
/// Namespace for GJK algorithm functions
pub const GJK = struct {
    // Source: https://www.youtube.com/watch?v=0XQ2FSz3EK8
    pub const EPA = struct {
        pub fn intersect(polytope: std.ArrayList(zm.Vec), point_set_a: []const zm.Vec, point_set_b: []const zm.Vec) void {
            const infinity = std.math.inf(f32);

            var min_index: u32 = 0;
            var min_distance = infinity;
            var min_normal = zm.f32x4(0, 0, 0, 0);

            while (infinity == min_distance) {
                for (0..polytope.items.len) |index_a| {
                    const index_b = (index_a + 1) % polytope.len;

                    const vertex_a = polytope.items.vertex[index_a];
                    const vertex_b = polytope.items.vertex[index_b];

                    const b_to_a = vertex_b - vertex_a;

                    const normal = zm.normalize2(zm.f32x4(b_to_a.y, -b_to_a.x, 0, 0));
                    const distance = zm.dot3(normal, vertex_a)[0];

                    if (distance < 0) {
                        distance = @abs(distance);
                        normal *= @splat(@as(f32, -1.0));
                    }

                    if (distance < min_distance) {
                        min_distance = distance;
                        min_normal = normal;
                        min_index = index_b;
                    }
                }

                const support_a_b = support(point_set_a, point_set_b, min_normal);
                const support_distance = zm.dot3(min_distance, support_a_b)[0];

                if (@abs(support_distance - min_distance) > 0.001) {
                    min_distance = infinity;
                    try polytope.insert(min_index, support_a_b);
                }
            }
        }
    };

    /// GJK implementation
    pub fn intersect(point_set_a: []const zm.Vec, point_set_b: []const zm.Vec, direction: zm.Vec) bool {
        // find the inital support point in any direction
        var support_point = support(point_set_a, point_set_b, direction);

        var simplex = Simplex{};
        simplex.pushFront(support_point);

        var new_direction = -support_point;
        while (true) {
            support_point = support(point_set_a, point_set_b, new_direction);
            if (zm.dot3(support_point, new_direction)[0] <= 0) {
                return false;
            }

            simplex.pushFront(support_point);

            const contains_origin = simplex.nearest(&new_direction);
            if (contains_origin) {
                return true;
            }
        }
    }

    const Simplex = struct {
        points: [4]zm.Vec = undefined,
        len: u8 = 0,

        pub fn setTo(self: *Simplex, points: []const zm.Vec) void {
            std.debug.assert(points.len <= 4);

            @memcpy(self.points[0..points.len], points);
            self.len = @intCast(points.len);
        }

        pub fn pushFront(self: *Simplex, point: zm.Vec) void {
            const p1 = self.points[0];
            const p2 = self.points[1];
            const p3 = self.points[2];
            self.points = .{
                point,
                p1,
                p2,
                p3,
            };
            self.len = @min(self.len + 1, self.points.len);
        }

        fn nearest(simplex: *Simplex, direction: *zm.Vec) bool {
            return switch (simplex.len) {
                2 => simplex.line(direction),
                3 => simplex.triangle(direction),
                4 => simplex.tetrahedron(direction),
                else => unreachable,
            };
        }

        pub fn asSlice(self: Simplex) []const zm.Vec {
            return self.points[0..self.len];
        }

        fn line(self: *Simplex, direction: *zm.Vec) bool {
            std.debug.assert(self.len >= 2);

            const a = self.points[0];
            const b = self.points[1];

            const b_a = b - a;
            const inv_a = -a;

            if (sameDirection(b_a, inv_a)) {
                direction.* = zm.cross3(zm.cross3(b_a, inv_a), b_a);
            } else {
                self.setTo(&[_]zm.Vec{a});
                direction.* = inv_a;
            }

            return false;
        }

        fn triangle(self: *Simplex, direction: *zm.Vec) bool {
            std.debug.assert(self.len >= 3);

            const a = self.points[0];
            const b = self.points[1];
            const c = self.points[2];

            const b_a = b - a;
            const c_a = c - a;
            const inv_a = -a;

            const abc_cross = zm.cross3(b_a, c_a);

            if (sameDirection(zm.cross3(abc_cross, c_a), inv_a)) {
                if (sameDirection(c_a, inv_a)) {
                    self.setTo(&[_]zm.Vec{ a, c });
                    direction.* = zm.cross3(zm.cross3(c_a, inv_a), c_a);
                } else {
                    self.setTo(&[_]zm.Vec{ a, b });
                    return self.line(direction);
                }
            } else {
                if (sameDirection(zm.cross3(b_a, abc_cross), inv_a)) {
                    self.setTo(&[_]zm.Vec{ a, b });
                    return self.line(direction);
                } else {
                    if (sameDirection(abc_cross, inv_a)) {
                        direction.* = abc_cross;
                    } else {
                        self.setTo(&[_]zm.Vec{ a, c, b });
                        direction.* = -abc_cross;
                    }
                }
            }

            return false;
        }

        fn tetrahedron(self: *Simplex, direction: *zm.Vec) bool {
            std.debug.assert(self.len >= 3);

            const a = self.points[0];
            const b = self.points[1];
            const c = self.points[2];
            const d = self.points[3];

            const b_a = b - a;
            const c_a = c - a;
            const d_a = d - a;
            const inv_a = -a;

            const abc_cross = zm.cross3(b_a, c_a);
            const acd_cross = zm.cross3(c_a, d_a);
            const adb_cross = zm.cross3(d_a, b_a);

            if (sameDirection(abc_cross, inv_a)) {
                self.setTo(&[_]zm.Vec{ a, b, c });
                return self.triangle(direction);
            }

            if (sameDirection(acd_cross, inv_a)) {
                self.setTo(&[_]zm.Vec{ a, c, d });
                return self.triangle(direction);
            }

            if (sameDirection(adb_cross, inv_a)) {
                self.setTo(&[_]zm.Vec{ a, d, b });
                return self.triangle(direction);
            }

            return true;
        }
    };

    fn findFurthestPoint(points: []const zm.Vec, direction: zm.Vec) zm.Vec {
        var max_point = points[0];
        var max_distance = zm.dot3(points[0], direction);
        for (points[1..]) |point| {
            const distance = zm.dot3(point, direction);
            if (distance[0] > max_distance[0]) {
                max_point = point;
                max_distance = distance;
            }
        }

        return max_point;
    }

    fn support(point_set_a: []const zm.Vec, point_set_b: []const zm.Vec, direction: zm.Vec) zm.Vec {
        return findFurthestPoint(point_set_a, direction) - findFurthestPoint(point_set_b, -direction);
    }
};

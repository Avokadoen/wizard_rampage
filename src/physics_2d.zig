const std = @import("std");
const rl = @import("raylib");

const components = @import("components.zig");

pub const Intersection = struct {
    // FP correction, nudge any resolve by some factor to ensure collision is resolved
    const nudge = rl.Vector2.init(1.1, 1.1);

    pub fn rectAndRect(
        a: components.RectangleCollider,
        a_pos: components.Position,
        b: components.RectangleCollider,
        b_pos: components.Position,
    ) bool {
        const a_lower, const a_higher = find_a_low_high_blk: {
            const lower = a_pos.vec;
            const higher = a_pos.vec.add(a.dim);
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const lower = b_pos.vec;
            const higher = b_pos.vec.add(b.dim);
            break :find_b_low_high_blk .{ lower, higher };
        };

        const min_higher = a_higher.min(b_higher);
        const max_lower = a_lower.max(b_lower);

        return min_higher.x >= max_lower.x and min_higher.y >= max_lower.y;
    }

    pub fn rectAndRectResolve(
        a: components.RectangleCollider,
        a_pos: components.Position,
        b: components.RectangleCollider,
        b_pos: components.Position,
    ) ?rl.Vector2 {
        const a_lower, const a_higher = find_a_low_high_blk: {
            const lower = a_pos.vec;
            const higher = a_pos.vec.add(a.dim);
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const lower = b_pos.vec;
            const higher = b_pos.vec.add(b.dim);
            break :find_b_low_high_blk .{ lower, higher };
        };

        const min_higher = a_higher.min(b_higher);
        const max_lower = a_lower.max(b_lower);

        const is_intersection_rectangle = min_higher.x > max_lower.x and min_higher.y > max_lower.y;
        if (is_intersection_rectangle) {
            const resolve_vector = max_lower.subtract(min_higher).multiply(nudge);
            const abs_resolve = rl.Vector2.init(@abs(resolve_vector.x), @abs(resolve_vector.y));

            if (abs_resolve.x < abs_resolve.y) {
                return rl.Vector2.init(if (a_pos.vec.x < b_pos.vec.x) resolve_vector.x else -resolve_vector.x, 0);
            } else {
                return rl.Vector2.init(0, if (a_pos.vec.y < b_pos.vec.y) resolve_vector.y else -resolve_vector.y);
            }
        } else return null;
    }

    // source: https://stackoverflow.com/a/1879223/11768869
    pub fn circleAndRect(
        circle: components.CircleCollider,
        circle_pos: components.Position,
        rect: components.RectangleCollider,
        rect_pos: components.Position,
    ) bool {
        const lower = rect_pos.vec;
        const higher = rect_pos.vec.add(rect.dim);

        const closest = circle_pos.vec.clamp(lower, higher);
        const distance = circle_pos.vec.subtract(closest);

        return distance.length() < circle.radius;
    }

    pub fn circleAndRectResolve(
        circle: components.CircleCollider,
        circle_pos: components.Position,
        rect: components.RectangleCollider,
        rect_pos: components.Position,
    ) ?rl.Vector2 {
        const lower = rect_pos.vec;
        const higher = rect_pos.vec.add(rect.dim);

        const closest = circle_pos.vec.clamp(lower, higher);
        const distance = circle_pos.vec.subtract(closest);
        const distance_length = distance.length();

        // if circle point is inside rectangle, missing handling as distance vector will be (0,0)
        std.debug.assert(distance_length != 0);

        if (distance_length >= circle.radius) {
            return null;
        }

        const resolve_dist = (circle.radius - distance_length) * nudge.x;
        const resolve_vec = rl.Vector2.init(resolve_dist, resolve_dist);
        return distance.normalize().multiply(resolve_vec);
    }

    pub fn circleAndCircle(
        a: components.CircleCollider,
        a_pos: components.Position,
        b: components.CircleCollider,
        b_pos: components.Position,
    ) bool {
        const distance = b_pos.vec.subtract(a_pos.vec).length();
        return distance < (b.radius + a.radius);
    }

    pub fn circleAndCircleResolve(
        a: components.CircleCollider,
        a_pos: components.Position,
        b: components.CircleCollider,
        b_pos: components.Position,
    ) ?rl.Vector2 {
        const from_a_to_b = b_pos.vec.subtract(a_pos.vec);
        const distance = from_a_to_b.length();

        if (distance < b.radius + a.radius) {
            const resolve_dist = (b.radius + a.radius - distance) * nudge.x;
            const resolve_vec = rl.Vector2.init(resolve_dist, resolve_dist);
            return from_a_to_b.normalize().multiply(resolve_vec);
        } else return null;
    }
};

test "rectAndRectResolve detect simple case" {
    const a = components.RectangleCollider{ .dim = rl.Vector2{
        .x = 2,
        .y = 2,
    } };
    const a_pos = components.Position{
        .vec = rl.Vector2.init(-1, 0),
    };

    const b = components.RectangleCollider{ .dim = rl.Vector2{
        .x = 2,
        .y = 2,
    } };
    const b_pos = components.Position{
        .vec = rl.Vector2.init(0.95, -1),
    };

    try std.testing.expect(Intersection.rectAndRect(a, a_pos, b, b_pos));

    const intersection = try (Intersection.rectAndRectResolve(a, a_pos, b, b_pos) orelse error.MissingIntersection);
    try std.testing.expect(intersection.x <= -0.05);
    try std.testing.expect(intersection.x > -0.06);
    try std.testing.expectEqual(intersection.y, 0);
}

test "circleAndRect detect simple case" {
    const circle = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const circle_pos = components.Position{
        .vec = rl.Vector2.init(2.25, 0),
    };

    const rect = components.RectangleCollider{ .dim = rl.Vector2{
        .x = 2,
        .y = 2,
    } };
    const rect_pos = components.Position{
        .vec = rl.Vector2.init(0, 0),
    };

    try std.testing.expect(Intersection.circleAndRect(circle, circle_pos, rect, rect_pos));

    const intersection = try (Intersection.circleAndRectResolve(circle, circle_pos, rect, rect_pos) orelse error.MissingIntersection);
    try std.testing.expect(intersection.x >= 0.825);
    try std.testing.expect(intersection.x < 0.9);
    try std.testing.expectEqual(intersection.y, 0);
}

test "circleAndCircleResolve detect simple case" {
    const a = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const a_pos = components.Position{
        .vec = rl.Vector2.init(1, 0),
    };

    const b = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const b_pos = components.Position{
        .vec = rl.Vector2.init(2, 0),
    };

    try std.testing.expect(Intersection.circleAndCircle(a, a_pos, b, b_pos));

    const intersection = try (Intersection.circleAndCircleResolve(a, a_pos, b, b_pos) orelse error.MissingIntersection);
    _ = intersection; // autofix
    // try std.testing.expect(intersection.x <= -1);
    // try std.testing.expect(intersection.x > -1.2);
    // try std.testing.expectEqual(intersection.y, 0);
}

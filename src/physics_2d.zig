const std = @import("std");

const zm = @import("zmath");

const components = @import("components.zig");

pub const Intersection = struct {
    // FP correction, nudge any resolve by some factor to ensure collision is resolved
    const nudge = @as(zm.Vec, @splat(1.1));

    pub fn rectAndRect(
        a: components.RectangleCollider,
        a_pos: components.Position,
        b: components.RectangleCollider,
        b_pos: components.Position,
    ) bool {
        const a_lower, const a_higher = find_a_low_high_blk: {
            const origin_dist = zm.f32x4(a.width, a.height, 0, 0);
            const lower = a_pos.vec;
            const higher = a_pos.vec + origin_dist;
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const origin_dist = zm.f32x4(b.width, b.height, 0, 0);
            const lower = b_pos.vec;
            const higher = b_pos.vec + origin_dist;
            break :find_b_low_high_blk .{ lower, higher };
        };

        const min_higher = @min(a_higher, b_higher);
        const max_lower = @max(a_lower, b_lower);

        return min_higher[0] >= max_lower[0] and min_higher[1] >= max_lower[1];
    }

    pub fn rectAndRectResolve(
        a: components.RectangleCollider,
        a_pos: components.Position,
        b: components.RectangleCollider,
        b_pos: components.Position,
    ) ?zm.Vec {
        const a_lower, const a_higher = find_a_low_high_blk: {
            const origin_dist = zm.f32x4(a.width, a.height, 0, 0);
            const lower = a_pos.vec;
            const higher = a_pos.vec + origin_dist;
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const origin_dist = zm.f32x4(b.width, b.height, 0, 0);
            const lower = b_pos.vec;
            const higher = b_pos.vec + origin_dist;
            break :find_b_low_high_blk .{ lower, higher };
        };

        const min_higher = @min(a_higher, b_higher);
        const max_lower = @max(a_lower, b_lower);

        const is_intersection_rectangle = min_higher[0] > max_lower[0] and min_higher[1] > max_lower[1];
        if (is_intersection_rectangle) {
            const resolve_vector = (max_lower - min_higher) * nudge;
            const abs_resolve = @abs(resolve_vector);

            if (abs_resolve[0] < abs_resolve[1]) {
                return zm.f32x4(if (a_pos.vec[0] < b_pos.vec[0]) resolve_vector[0] else -resolve_vector[0], 0, 0, 0);
            } else {
                return zm.f32x4(0, if (a_pos.vec[1] < b_pos.vec[1]) resolve_vector[1] else -resolve_vector[1], 0, 0);
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
        const origin_dist = zm.f32x4(rect.width, rect.height, 0, 0);
        const lower = rect_pos.vec;
        const higher = rect_pos.vec + origin_dist;

        const closest = zm.clamp(circle_pos.vec, lower, higher);
        const distance = circle_pos.vec - closest;

        return zm.length2(distance)[0] < circle.radius;
    }

    pub fn circleAndRectResolve(
        circle: components.CircleCollider,
        circle_pos: components.Position,
        rect: components.RectangleCollider,
        rect_pos: components.Position,
    ) ?zm.Vec {
        const origin_dist = zm.f32x4(rect.width, rect.height, 0, 0);
        const lower = rect_pos.vec;
        const higher = rect_pos.vec + origin_dist;

        const closest = zm.clamp(circle_pos.vec, lower, higher);
        const distance = circle_pos.vec - closest;
        const distance_length = zm.length2(distance)[0];

        // if circle point is inside rectangle, missing handling as distance vector will be (0,0)
        std.debug.assert(distance_length != 0);

        if (distance_length < circle.radius) {
            return (zm.normalize3(distance) * @as(zm.Vec, @splat(circle.radius - distance_length))) * nudge;
        } else return null;
    }

    pub fn circleAndCircle(
        a: components.CircleCollider,
        a_pos: components.Position,
        b: components.CircleCollider,
        b_pos: components.Position,
    ) bool {
        const distance = zm.length2(b_pos.vec - a_pos.vec)[0];
        return distance < (b.radius + a.radius);
    }

    pub fn circleAndCircleResolve(
        a: components.CircleCollider,
        a_pos: components.Position,
        b: components.CircleCollider,
        b_pos: components.Position,
    ) ?zm.Vec {
        const from_a_to_b = b_pos.vec - a_pos.vec;
        const distance = zm.length2(from_a_to_b)[0];

        if (distance < b.radius + a.radius) {
            return zm.normalize3(from_a_to_b) * @as(zm.Vec, @splat(b.radius + a.radius - distance)) * nudge;
        } else return null;
    }
};

test "rectAndRectResolve detect simple case" {
    const a = components.RectangleCollider{
        .width = 2,
        .height = 2,
    };
    const a_pos = components.Position{
        .vec = zm.f32x4(-1, 0, 0, 0),
    };

    const b = components.RectangleCollider{
        .width = 2,
        .height = 2,
    };
    const b_pos = components.Position{
        .vec = zm.f32x4(0.95, -1, 0, 0),
    };

    try std.testing.expect(Intersection.rectAndRect(a, a_pos, b, b_pos));

    const intersection = try (Intersection.rectAndRectResolve(a, a_pos, b, b_pos) orelse error.MissingIntersection);
    try std.testing.expect(intersection[0] <= -0.05);
    try std.testing.expect(intersection[0] > -0.06);
    try std.testing.expectEqual(intersection[1], 0);
}

test "circleAndRect detect simple case" {
    const circle = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const circle_pos = components.Position{
        .vec = zm.f32x4(2.25, 0, 0, 0),
    };

    const rect = components.RectangleCollider{
        .width = 2,
        .height = 2,
    };
    const rect_pos = components.Position{
        .vec = zm.f32x4(0, 0, 0, 0),
    };

    try std.testing.expect(Intersection.circleAndRect(circle, circle_pos, rect, rect_pos));

    const intersection = try (Intersection.circleAndRectResolve(circle, circle_pos, rect, rect_pos) orelse error.MissingIntersection);
    try std.testing.expect(intersection[0] >= 0.825);
    try std.testing.expect(intersection[0] < 0.9);
    try std.testing.expectEqual(intersection[1], 0);
}

test "circleAndCircleResolve detect simple case" {
    const a = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const a_pos = components.Position{
        .vec = zm.f32x4(1, 0, 0, 0),
    };

    const b = components.CircleCollider{
        .x = 0,
        .y = 0,
        .radius = 1,
    };
    const b_pos = components.Position{
        .vec = zm.f32x4(2, 0, 0, 0),
    };

    try std.testing.expect(Intersection.circleAndCircle(a, a_pos, b, b_pos));

    const intersection = try (Intersection.circleAndCircleResolve(a, a_pos, b, b_pos) orelse error.MissingIntersection);
    _ = intersection; // autofix
    // try std.testing.expect(intersection[0] <= -1);
    // try std.testing.expect(intersection[0] > -1.2);
    // try std.testing.expectEqual(intersection[1], 0);
}

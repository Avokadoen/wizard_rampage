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
            const origin_dist = zm.f32x4((a.width * 0.5), (a.height * 0.5), 0, 0);
            const lower = a_pos.vec - origin_dist;
            const higher = a_pos.vec + origin_dist;
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const origin_dist = zm.f32x4((b.width * 0.5), (b.height * 0.5), 0, 0);
            const lower = b_pos.vec - origin_dist;
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
            const origin_dist = zm.f32x4((a.width * 0.5), (a.height * 0.5), 0, 0);
            const lower = a_pos.vec - origin_dist;
            const higher = a_pos.vec + origin_dist;
            break :find_a_low_high_blk .{ lower, higher };
        };

        const b_lower, const b_higher = find_b_low_high_blk: {
            const origin_dist = zm.f32x4((b.width * 0.5), (b.height * 0.5), 0, 0);
            const lower = b_pos.vec - origin_dist;
            const higher = b_pos.vec + origin_dist;
            break :find_b_low_high_blk .{ lower, higher };
        };

        const min_higher = @min(a_higher, b_higher);
        const max_lower = @max(a_lower, b_lower);

        const is_intersection_rectangle = min_higher[0] >= max_lower[0] and min_higher[1] >= max_lower[1];
        if (is_intersection_rectangle) {
            const resolve_vector = (min_higher - max_lower) * nudge;
            const abs_resolve = @abs(resolve_vector);

            if (abs_resolve[0] < abs_resolve[1]) {
                const x_value = if (a_lower[0] < b_lower[0]) resolve_vector[0] else -resolve_vector[0];
                return zm.f32x4(x_value, 0, 0, 0);
            } else {
                const y_value = if (a_lower[1] < b_lower[1]) resolve_vector[1] else -resolve_vector[1];
                return zm.f32x4(0, y_value, 0, 0);
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
        const origin_dist = zm.f32x4((rect.width * 0.5), (rect.height * 0.5), 0, 0);
        const lower = rect_pos.vec - origin_dist;
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
        const origin_dist = zm.f32x4((rect.width * 0.5), (rect.height * 0.5), 0, 0);
        const lower = rect_pos.vec - origin_dist;
        const higher = rect_pos.vec + origin_dist;

        const closest = zm.clamp(circle_pos.vec, lower, higher);
        const distance = circle_pos.vec - closest;

        const distance_length = zm.length2(distance)[0];
        if (distance_length < circle.radius) {
            return distance * @as(zm.Vec, @splat(circle.radius - distance_length)) * nudge;
        } else return null;
    }

    pub fn circleAndCircle(a: components.CircleCollider, a_pos: components.Position, b: components.CircleCollider, b_pos: components.Position) bool {
        const distance = zm.length2(a_pos.vec - b_pos.vec)[0];
        return distance <= (a.radius + b.radius);
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
    try std.testing.expect(intersection[0] >= 0.05);
    try std.testing.expect(intersection[0] < 0.06);
    try std.testing.expectEqual(intersection[1], 0);
}

test "circleAndRect detect simple case" {
    const circle = components.CircleCollider{
        .radius = 1,
    };
    const circle_pos = components.Position{
        .vec = zm.f32x4(1.95, 0, 0, 0),
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
    try std.testing.expect(intersection[0] >= 0.05);
    try std.testing.expect(intersection[0] < 0.06);
    try std.testing.expectEqual(intersection[1], 0);
}

test "circleAndCircle detect simple case" {
    const a = components.CircleCollider{
        .radius = 1,
    };
    const a_pos = components.Position{
        .vec = zm.f32x4(1, 0, 0, 0),
    };

    const b = components.CircleCollider{
        .radius = 1,
    };
    const b_pos = components.Position{
        .vec = zm.f32x4(2.1, 0, 0, 0),
    };

    try std.testing.expect(Intersection.circleAndCircle(a, a_pos, b, b_pos));
}

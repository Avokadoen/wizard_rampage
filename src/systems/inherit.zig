const ecez = @import("ecez");
const rl = @import("raylib");
const tracy = @import("ztracy");

const components = @import("../components.zig");
const physics = @import("../physics/components.zig");

pub fn Create(Storage: type) type {
    return struct {
        const ParentVelSubset = Storage.Subset(&[_]type{
            physics.Velocity,
        });
        const InheritVelQuery = ecez.Query(
            struct {
                vel: *physics.Velocity,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn velocity(
            inherent_vel: *InheritVelQuery,
            subset: *ParentVelSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_vel.next()) |item| {
                const parent_vel = subset.getComponent(item.child_of.parent, physics.Velocity) orelse continue;
                item.vel.* = parent_vel;
            }
        }

        const ParentPosSubset = Storage.Subset(&[_]type{
            physics.Position,
        });
        const InheritPosQuery = ecez.Query(
            struct {
                pos: *physics.Position,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn position(
            inherent_pos: *InheritPosQuery,
            subset: *ParentPosSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_pos.next()) |item| {
                const parent_pos = subset.getComponent(item.child_of.parent, physics.Position) orelse continue;
                item.pos.vec = parent_pos.vec.add(item.child_of.offset);
            }
        }

        const ParentScaleSubset = Storage.Subset(&[_]type{
            physics.Scale,
        });
        const InheritScaleQuery = ecez.Query(
            struct {
                scale: *physics.Scale,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn scale(
            inherent_scale: *InheritScaleQuery,
            subset: *ParentScaleSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_scale.next()) |item| {
                const parent_scale = subset.getComponent(item.child_of.parent, physics.Scale) orelse continue;
                item.scale.vec = parent_scale.vec;
            }
        }

        const InheritInactiveFromParentSubset = Storage.Subset(&[_]type{
            *components.InactiveTag,
        });
        const InheritInactiveQuery = ecez.Query(
            struct {
                entity: ecez.Entity,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn inactive(
            inherent_inactive: *InheritInactiveQuery,
            subset: *InheritInactiveFromParentSubset,
        ) error{OutOfMemory}!void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_inactive.next()) |item| {
                if (subset.hasComponents(item.child_of.parent, .{components.InactiveTag})) {
                    try subset.setComponents(item.entity, .{components.InactiveTag{}});
                }
            }
        }

        const InheritActiveFromParentSubset = Storage.Subset(&[_]type{
            *components.InactiveTag,
        });
        const InheritActiveQuery = ecez.Query(
            struct {
                entity: ecez.Entity,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
            .{},
        );
        pub fn active(
            inherent_active: *InheritActiveQuery,
            subset: *InheritActiveFromParentSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_active.next()) |item| {
                if (subset.hasComponents(item.child_of.parent, .{components.InactiveTag}) == false) {
                    subset.unsetComponents(item.entity, .{components.InactiveTag});
                }
            }
        }
    };
}

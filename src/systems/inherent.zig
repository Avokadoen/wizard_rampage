const ecez = @import("ecez");
const rl = @import("raylib");
const tracy = @import("ztracy");

const components = @import("../components.zig");

pub fn Create(Storage: type) type {
    return struct {
        const ParentVelSubset = Storage.Subset(.{
            components.Velocity,
        });
        const InherentVelQuery = ecez.Query(
            struct {
                vel: *components.Velocity,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn velocity(
            inherent_vel: *InherentVelQuery,
            subset: *ParentVelSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_vel.next()) |item| {
                const parent_vel = subset.getComponent(item.child_of.parent, components.Velocity) orelse continue;
                item.vel.* = parent_vel;
            }
        }

        const ParentPosSubset = Storage.Subset(.{
            components.Position,
        });
        const InherentPosQuery = ecez.Query(
            struct {
                pos: *components.Position,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn position(
            inherent_pos: *InherentPosQuery,
            subset: *ParentPosSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_pos.next()) |item| {
                const parent_pos = subset.getComponent(item.child_of.parent, components.Position) orelse continue;
                item.pos.vec = parent_pos.vec.add(item.child_of.offset);
            }
        }

        const ParentScaleSubset = Storage.Subset(.{
            components.Scale,
        });
        const InherentScaleQuery = ecez.Query(
            struct {
                scale: *components.Scale,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn scale(
            inherent_scale: *InherentScaleQuery,
            subset: *ParentScaleSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_scale.next()) |item| {
                const parent_scale = subset.getComponent(item.child_of.parent, components.Scale) orelse continue;
                item.scale.vec = parent_scale.vec;
            }
        }

        const InherentInactiveFromParentSubset = Storage.Subset(.{
            *components.InactiveTag,
        });
        const InherentInactiveQuery = ecez.Query(
            struct {
                entity: ecez.Entity,
                child_of: components.ChildOf,
            },
            .{},
            .{components.InactiveTag},
        );
        pub fn inactive(
            inherent_inactive: *InherentInactiveQuery,
            subset: *InherentInactiveFromParentSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_inactive.next()) |item| {
                if (subset.hasComponents(item.child_of.parent, .{components.InactiveTag})) {
                    subset.setComponents(item.entity, .{components.InactiveTag{}}) catch @panic("inherentInactiveFromParent: oom");
                }
            }
        }

        const InherentActiveFromParentSubset = Storage.Subset(.{
            *components.InactiveTag,
        });
        const InherentActiveQuery = ecez.Query(
            struct {
                entity: ecez.Entity,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
            .{},
        );
        pub fn active(
            inherent_active: *InherentActiveQuery,
            subset: *InherentActiveFromParentSubset,
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

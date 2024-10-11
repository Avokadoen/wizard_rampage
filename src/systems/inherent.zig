const tracy = @import("ztracy");
const ecez = @import("ecez");
const rl = @import("raylib");

const components = @import("../components.zig");

pub fn Create(Storage: type) type {
    return struct {
        const ParentVelSubset = Storage.Subset(.{
            components.Velocity,
        });
        const InherentVelQuery = Storage.Query(
            struct {
                vel: *components.Velocity,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn velocity(
            inherent_vel: *InherentVelQuery,
            subset: *ParentVelSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_vel.next()) |item| {
                const parent_vel = subset.getComponent(item.child_of.parent, components.Velocity) catch continue;
                item.vel.* = parent_vel;
            }
        }

        const ParentPosSubset = Storage.Subset(.{
            components.Position,
        });
        const InherentPosQuery = Storage.Query(
            struct {
                pos: *components.Position,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn position(
            inherent_pos: *InherentPosQuery,
            subset: *ParentPosSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_pos.next()) |item| {
                const parent_pos = subset.getComponent(item.child_of.parent, components.Position) catch continue;
                item.pos.vec = parent_pos.vec.add(item.child_of.offset);
            }
        }

        const ParentScaleSubset = Storage.Subset(.{
            components.Scale,
        });
        const InherentScaleQuery = Storage.Query(
            struct {
                scale: *components.Scale,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn scale(
            inherent_scale: *InherentScaleQuery,
            subset: *ParentScaleSubset,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_scale.next()) |item| {
                const parent_scale = subset.getComponent(item.child_of.parent, components.Scale) catch continue;
                item.scale.vec = parent_scale.vec;
            }
        }

        const InherentInactiveFromParentSubset = Storage.Subset(.{
            *components.InactiveTag,
        });
        const InherentInactiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
        }, .{components.InactiveTag});
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
        const InherentActiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
            _: components.InactiveTag,
        }, .{});
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

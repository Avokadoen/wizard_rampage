const tracy = @import("ztracy");
const ecez = @import("ecez");
const zm = @import("zmath");

const components = @import("../components.zig");

pub fn Create(Storage: type) type {
    return struct {
        const ParentVelView = Storage.Subset(.{components.Velocity}, .read_only);
        const InherentVelQuery = Storage.Query(
            struct {
                vel: *components.Velocity,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn velocity(
            inherent_vel: *InherentVelQuery,
            parent_vel_view: *ParentVelView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_vel.next()) |item| {
                const parent_vel = parent_vel_view.getComponent(item.child_of.parent, components.Velocity) catch return;
                item.vel.* = parent_vel;
            }
        }

        const ParentPosView = Storage.Subset(.{components.Position}, .read_only);
        const InherentPosQuery = Storage.Query(
            struct {
                pos: *components.Position,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn position(
            inherent_pos: *InherentPosQuery,
            parent_pos_view: *ParentPosView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_pos.next()) |item| {
                const parent_pos = parent_pos_view.getComponent(item.child_of.parent, components.Position) catch return;
                const offset = zm.f32x4(item.child_of.offset_x, item.child_of.offset_y, 0, 0);
                item.pos.vec = parent_pos.vec + offset;
            }
        }

        const ParentScaleView = Storage.Subset(.{components.Scale}, .read_only);
        const InherentScaleQuery = Storage.Query(
            struct {
                scale: *components.Scale,
                child_of: components.ChildOf,
            },
            .{components.InactiveTag},
        );
        pub fn scale(
            inherent_scale: *InherentScaleQuery,
            parent_scale_view: *ParentScaleView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_scale.next()) |item| {
                const parent_scale = parent_scale_view.getComponent(item.child_of.parent, components.Scale) catch return;
                item.scale.* = parent_scale;
            }
        }

        const InherentInactiveFromParentWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const InherentInactiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
        }, .{components.InactiveTag});
        pub fn inactive(
            inherent_inactive: *InherentInactiveQuery,
            write_view: *InherentInactiveFromParentWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_inactive.next()) |item| {
                const parent_tag = write_view.getComponent(item.child_of.parent, components.InactiveTag) catch continue;
                write_view.setComponents(item.entity, .{parent_tag}) catch @panic("inherentInactiveFromParent: oom");
            }
        }

        const InherentActiveFromParentWriteView = Storage.Subset(
            .{components.InactiveTag},
            .read_and_write,
        );
        const InherentActiveQuery = Storage.Query(struct {
            entity: ecez.Entity,
            child_of: components.ChildOf,
            _: components.InactiveTag,
        }, .{});
        pub fn active(
            inherent_active: *InherentActiveQuery,
            write_view: *InherentActiveFromParentWriteView,
        ) void {
            const zone = tracy.ZoneN(@src(), @src().fn_name);
            defer zone.End();

            while (inherent_active.next()) |item| {
                _ = write_view.getComponent(item.child_of.parent, components.InactiveTag) catch {
                    write_view.unsetComponents(item.entity, .{components.InactiveTag});
                };
            }
        }
    };
}

const std = @import("std");

pub const Options = struct {
    linux_display_backend: LinuxDisplayBackend = .X11,
    enable_ztracy: bool,
    enable_fibers: bool,
    on_demand: bool,
};

pub const LinuxDisplayBackend = enum {
    X11,
    Wayland,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = Options{
        .linux_display_backend = b.option(LinuxDisplayBackend, "linux_display_backend", "Linux display backend to use") orelse .X11,
        .enable_ztracy = b.option(
            bool,
            "enable_ztracy",
            "Enable Tracy profile markers",
        ) orelse false,
        .enable_fibers = b.option(
            bool,
            "enable_fibers",
            "Enable Tracy fiber support",
        ) orelse false,
        .on_demand = b.option(
            bool,
            "on_demand",
            "Build tracy with TRACY_ON_DEMAND",
        ) orelse false,
    };

    const wizard_rampage_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "wizard_rampage",
        .root_module = wizard_rampage_mod,
    });

    const exe_unit_tests = b.addTest(.{
        .name = "wizard_rampage_tests",
        .root_module = wizard_rampage_mod,
    });

    // Create binary for tests to make it debuggable in vscode
    b.installArtifact(exe_unit_tests);
    // Create main binary
    b.installArtifact(exe);

    // Raylib
    {
        const raylib_dep = b.dependency("raylib_zig", .{
            .target = target,
            .optimize = optimize,
            .linux_display_backend = options.linux_display_backend,
        });

        const raylib = raylib_dep.module("raylib"); // main raylib module
        const raygui = raylib_dep.module("raygui"); // raygui module
        const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);

        exe_unit_tests.linkLibrary(raylib_artifact);
        exe_unit_tests.root_module.addImport("raylib", raylib);
        exe_unit_tests.root_module.addImport("raygui", raygui);
    }

    // link ecez and ztracy
    {
        const ecez = b.dependency("ecez", .{
            .enable_ztracy = options.enable_ztracy,
            .enable_ecez_dev_markers = options.enable_ztracy,
            .enable_fibers = options.enable_fibers,
            .on_demand = options.on_demand,
        });
        const ecez_module = ecez.module("ecez");

        exe.root_module.addImport("ecez", ecez_module);
        exe_unit_tests.root_module.addImport("ecez", ecez_module);

        const ztracy_dep = ecez.builder.dependency("ztracy", .{
            .enable_ztracy = options.enable_ztracy,
            .enable_fibers = options.enable_fibers,
            .on_demand = options.on_demand,
        });
        const ztracy_module = ztracy_dep.module("root"); // ecez_module.import_table.get("ztracy").?;

        exe.root_module.addImport("ztracy", ztracy_module);
        exe_unit_tests.root_module.addImport("ztracy", ztracy_module);

        exe.linkLibrary(ztracy_dep.artifact("tracy"));
    }

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

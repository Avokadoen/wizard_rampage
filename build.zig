const std = @import("std");

pub const Options = struct {
    linux_display_backend: LinuxDisplayBackend = .X11,
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
    };

    const exe = b.addExecutable(.{
        .name = "gamejam",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_unit_tests = b.addTest(.{
        .name = "gamejam_tests",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create binary for tests to make it debuggable in vscode
    b.installArtifact(exe_unit_tests);
    // Create main binary
    b.installArtifact(exe);

    // Raylib
    {
        const raylib_dep = b.dependency("raylib-zig", .{
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
    }

    // link zmath
    {
        const zmath = b.dependency("zmath", .{});
        exe.root_module.addImport("zmath", zmath.module("root"));
        exe_unit_tests.root_module.addImport("zmath", zmath.module("root"));
    }

    // link ecez and ztracy
    {
        // let user enable/disable tracy
        const enable_tracy = b.option(bool, "enable-tracy", "Enable Tracy profiler") orelse false;

        // link ecez
        {
            const ecez = b.dependency("ecez", .{ .enable_tracy = false });
            exe.root_module.addImport("ecez", ecez.module("ecez"));
            exe_unit_tests.root_module.addImport("ecez", ecez.module("ecez"));

            const ztracy_dep = b.dependency("ztracy", .{
                .enable_ztracy = enable_tracy,
            });

            exe.root_module.addImport("ztracy", ztracy_dep.module("root"));
            exe_unit_tests.root_module.addImport("ztracy", ztracy_dep.module("root"));

            if (enable_tracy)
                exe.linkLibrary(ztracy_dep.artifact("tracy"));
        }
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

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zttp",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    {
        const check_lib = b.addStaticLibrary(.{
            .name = "zttp",
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });

        const check_exe = b.addExecutable(.{
            .name = "zttp",
            .root_source_file = b.path("examples/simple_server.zig"),
            .target = target,
            .optimize = optimize,
        });

        check_exe.root_module.addImport("zttp", &check_lib.root_module);

        const check_step = b.step("check", "Check that the program compiles");
        check_step.dependOn(&check_lib.step);
        check_step.dependOn(&check_exe.step);
    }

    const exe = b.addExecutable(.{
        .name = "zttp",
        .root_source_file = b.path("examples/simple_server.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zttp", &lib.root_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

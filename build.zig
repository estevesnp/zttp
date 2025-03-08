const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("zttp", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const root_test = b.addTest(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        const run_root_test = b.addRunArtifact(root_test);

        const check_step = b.step("check", "Check application compiles");
        check_step.dependOn(&run_root_test.step);
    }

    const example_exe = b.addExecutable(.{
        .name = "zttp",
        .root_source_file = b.path("examples/simple_server.zig"),
        .target = target,
        .optimize = optimize,
    });

    example_exe.root_module.addImport("zttp", module);

    b.installArtifact(example_exe);

    const run_example_exe = b.addRunArtifact(example_exe);

    run_example_exe.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_example_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run an example");
    run_step.dependOn(&run_example_exe.step);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bdwgc = b.dependency("bdwgc", .{
        .target = target,
        .optimize = optimize,
        // TODO: Allow passing options to bdwgc's build.zig
    });

    const module = b.addModule("bdwgc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkLibrary(bdwgc.artifact("gc"));

    const tests = b.addTest(.{
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}

const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("zig-window", .{
        .source_file = .{ .path = "src/main.zig" },
    });

    // TODO: This is a workaround until modules support linking to system libraries
    const lib = b.addStaticLibrary(.{
        .name = "zig-window",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkSystemLibrary("xcb");
    lib.install();

    const example = b.addExecutable(.{
        .name = "zig-window-example",
        .root_source_file = .{ .path = "example.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.addModule("zig-window", mod);
    example.linkLibrary(lib);

    const run_cmd = example.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}

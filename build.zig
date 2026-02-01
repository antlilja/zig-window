const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = b.addOptions();
    switch (target.result.os.tag) {
        .linux => {
            const enable_wayland = b.option(bool, "enable-wayland", "enable wayland backend") orelse true;
            const enable_x11 = b.option(bool, "enable-x11", "enable x11 backend") orelse true;
            if (!enable_wayland and !enable_x11) @panic("At least one linux backend has to be enabled");
            options.addOption(bool, "enable-wayland", enable_wayland);
            options.addOption(bool, "enable-x11", enable_x11);
        },
        else => {},
    }

    const mod = b.addModule("zig-window", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addOptions("options", options);

    const example = b.addExecutable(.{
        .name = "zig-window-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("zig-window", mod);
    b.installArtifact(example);

    b.default_step.dependOn(&example.step);

    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}

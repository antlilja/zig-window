const std = @import("std");
const Build = std.Build;

const ScanProtocolsStep = @import("zig-wayland").ScanProtocolsStep;

pub fn build(b: *Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const scanner = ScanProtocolsStep.create(b);
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.generate("wl_compositor", 1);
    scanner.generate("wl_shm", 1);
    scanner.generate("xdg_wm_base", 1);

    const scanner_module = b.createModule(.{
        .source_file = .{ .generated = &scanner.result },
    });

    const mod = b.addModule("zig-window", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{.{
            .name = "wayland",
            .module = scanner_module,
        }},
    });

    // TODO: This is a workaround until modules support linking to system libraries
    const lib = b.addStaticLibrary(.{
        .name = "zig-window",
        .target = target,
        .optimize = optimize,
    });
    lib.step.dependOn(&scanner.step);
    lib.linkLibC();
    lib.linkSystemLibrary("wayland-client");
    b.installArtifact(lib);
    scanner.addCSource(lib);

    const example = b.addExecutable(.{
        .name = "zig-window-example",
        .root_source_file = .{ .path = "example.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.addModule("zig-window", mod);
    example.linkLibrary(lib);

    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}

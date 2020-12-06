const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});

    const lib = b.addStaticLibrary("zig-window", "src/main.zig");
    switch (target.getOsTag()) {
        .linux => {
            lib.linkSystemLibrary("c");
            lib.linkSystemLibrary("xcb-cursor");
        },
        else => @panic("Unsupported OS"),
    }
    lib.exportArtifact();

    const build_examples = b.option(bool, "build-examples", "Build zig window examples");
    if (build_examples != null and build_examples.?) {
        const mode = b.standardReleaseOptions();
        const exe = b.addExecutable("example", "examples/src/main.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.linkLibrary(lib);
        exe.addPackagePath("zig-window", "src/main.zig");
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}

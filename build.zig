const Builder = @import("std").build.Builder;

const pack = @import("pack.zig");

pub fn build(b: *Builder) !void {
    const build_examples = b.option(bool, "build-examples", "Build zig window examples");

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zig-window", "src/main.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    try pack.addPackages(b, lib);

    if (build_examples != null and build_examples.?) {
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

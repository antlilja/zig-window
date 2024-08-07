const std = @import("std");
const zw = @import("zig-window");

fn handleEvent(_: ?*anyopaque, event: zw.Event) void {
    switch (event) {
        .Destroy => std.log.info("Window destroyed", .{}),
        .FocusIn => std.log.info("Focus in", .{}),
        .FocusOut => std.log.info("Focus out", .{}),
        .Resize => |size| {
            const width, const height = size;
            std.log.info("Resize: {}, {}", .{ width, height });
        },
        .KeyPress => |value| std.log.info("Key pressed: {}", .{value}),
        .KeyRelease => |value| std.log.info("Key released: {}", .{value}),
        .MouseScrollV => |value| std.log.info("Mouse scroll vertical: {}", .{value}),
        .MousePress => |value| std.log.info("{} pressed", .{value}),
        .MouseRelease => |value| std.log.info("{} released", .{value}),
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try zw.init(gpa.allocator());
    defer zw.deinit();

    const window = try zw.createWindow(.{
        .name = "Example window",
        .width = 1920,
        .height = 1080,
        .event_handler = .{
            .handle = null,
            .handle_event_fn = @ptrCast(&handleEvent),
        },
    });
    defer window.destroy();

    while (window.isOpen()) {
        zw.pollEvents();
    }
}

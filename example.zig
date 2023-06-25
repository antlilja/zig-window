const std = @import("std");
const zw = @import("zig-window");

fn handleEvent(_: ?*anyopaque, event: zw.Event) void {
    switch (event) {
        .Destroy => std.log.info("Window destroyed", .{}),
        .FocusIn => std.log.info("Focus in", .{}),
        .FocusOut => std.log.info("Focus out", .{}),
        .Resize => |value| std.log.info("Resize: {}, {}", .{ value.width, value.height }),
        .KeyPress => |value| std.log.info("Key pressed: {}", .{value}),
        .KeyRelease => |value| std.log.info("Key released: {}", .{value}),
        .MouseScrollV => |value| std.log.info("Mouse scroll vertical: {}", .{value}),
        .MousePress => |value| std.log.info("{} pressed", .{value}),
        .MouseRelease => |value| std.log.info("{} released", .{value}),
        else => {},
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var window = try zw.Window.create("Example window", 960, 540, &handleEvent, null, gpa.allocator());
    defer window.destroy();

    while (window.isOpen()) {
        window.handleEvents();
    }
}

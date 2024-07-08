# zig-window
A work in progress zig window library

Currently only supports linux X11 and Windows.

## Example:
```zig
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

    const context = try zw.init(gpa.allocator());
    defer context.deinit();

    const window = try context.createWindow(.{
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
        context.pollEvents();
    }
}
```

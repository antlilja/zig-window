# zig-window
A work in progress zig window library

Currently only supports linux thorugh XCB.

## Example:
```zig
const std = @import("std");
const zw = @import("zig-window");

fn handleEvent(event: zw.Event) void {
    switch (event) {
        .Destroy => std.debug.warn("Window destroyed\n", .{}),
        .FocusIn => std.debug.warn("Focus in\n", .{}),
        .FocusOut => std.debug.warn("Focus out\n", .{}),
        .Resize => |value| std.debug.warn("Resize: {}, {}\n", .{ value.width, value.height }),
        .KeyPress => |value| std.debug.warn("Key pressed: {}\n", .{value}),
        .KeyRelease => |value| std.debug.warn("Key released: {}\n", .{value}),
        .MouseScrollV => |value| std.debug.warn("Mouse scroll vertical: {}\n", .{value}),
        .MousePress => |value| std.debug.warn("{} pressed\n", .{value}),
        .MouseRelease => |value| std.debug.warn("{} released\n", .{value}),
        else => {},
    }
}

pub fn main() anyerror!void {
    var window = try zw.Window.create("Example window", 960, 540);
    defer window.destroy();

    while (window.is_open()) {
        window.handle_events(handleEvent);
    }
}
```

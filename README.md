# zig-window
A work in progress zig window library

Currently only supports linux through XCB.

## Example using function event handler:
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

    while (window.isOpen()) {
        window.handleEvents(handleEvent);
    }
}
```

## Example using struct event handler:
```zig
const std = @import("std");
const zw = @import("zig-window");

const EventHandler = struct {
    unhandled_event_count: usize = 0,

    pub fn handleEvent(self: *EventHandler, event: zw.Event) void {
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
            else => {
                self.unhandled_event_count += 1;
                std.debug.warn("Unhandled event number: {}\n", .{self.unhandled_event_count});
            },
        }
    }
};

pub fn main() anyerror!void {
    var window = try zw.Window.create("Example window", 960, 540);
    defer window.destroy();

    var event_handler = EventHandler{};

    while (window.isOpen()) {
        window.handleEvents(&event_handler);
    }
}
```

## The event handler can also return errors:
```zig
const std = @import("std");
const zw = @import("zig-window");

fn handleEvent(event: zw.Event) !void {
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
        else => return error.UnhandledEvent,
    }
}

pub fn main() anyerror!void {
    var window = try zw.Window.create("Example window", 960, 540);
    defer window.destroy();

    while (window.isOpen()) {
        try window.handleEvents(handleEvent);
    }
}
```

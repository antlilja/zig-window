# zig-window
A work in progress zig window library

Currently only supports linux through XCB.

## Example using function event handler:
```zig
const std = @import("std");
const zw = @import("zig-window");

fn handleEvent(event: zw.Event) void {
    switch (event) {
        .Destroy => std.log.info("Window destroyed\n", .{}),
        .FocusIn => std.log.info("Focus in\n", .{}),
        .FocusOut => std.log.info("Focus out\n", .{}),
        .Resize => |value| std.log.info("Resize: {}, {}\n", .{ value.width, value.height }),
        .KeyPress => |value| std.log.info("Key pressed: {}\n", .{value}),
        .KeyRelease => |value| std.log.info("Key released: {}\n", .{value}),
        .MouseScrollV => |value| std.log.info("Mouse scroll vertical: {}\n", .{value}),
        .MousePress => |value| std.log.info("{} pressed\n", .{value}),
        .MouseRelease => |value| std.log.info("{} released\n", .{value}),
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
            .Destroy => std.log.info("Window destroyed\n", .{}),
            .FocusIn => std.log.info("Focus in\n", .{}),
            .FocusOut => std.log.info("Focus out\n", .{}),
            .Resize => |value| std.log.info("Resize: {}, {}\n", .{ value.width, value.height }),
            .KeyPress => |value| std.log.info("Key pressed: {}\n", .{value}),
            .KeyRelease => |value| std.log.info("Key released: {}\n", .{value}),
            .MouseScrollV => |value| std.log.info("Mouse scroll vertical: {}\n", .{value}),
            .MousePress => |value| std.log.info("{} pressed\n", .{value}),
            .MouseRelease => |value| std.log.info("{} released\n", .{value}),
            else => {
                self.unhandled_event_count += 1;
                std.log.info("Unhandled event number: {}\n", .{self.unhandled_event_count});
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
        .Destroy => std.log.info("Window destroyed\n", .{}),
        .FocusIn => std.log.info("Focus in\n", .{}),
        .FocusOut => std.log.info("Focus out\n", .{}),
        .Resize => |value| std.log.info("Resize: {}, {}\n", .{ value.width, value.height }),
        .KeyPress => |value| std.log.info("Key pressed: {}\n", .{value}),
        .KeyRelease => |value| std.log.info("Key released: {}\n", .{value}),
        .MouseScrollV => |value| std.log.info("Mouse scroll vertical: {}\n", .{value}),
        .MousePress => |value| std.log.info("{} pressed\n", .{value}),
        .MouseRelease => |value| std.log.info("{} released\n", .{value}),
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

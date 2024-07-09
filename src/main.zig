const std = @import("std");

pub const Context = @import("Context.zig");

pub const EventHandler = @import("EventHandler.zig");
pub const Key = EventHandler.Key;
pub const Mouse = EventHandler.Mouse;
pub const Event = EventHandler.Event;

pub const Window = @import("Window.zig");

const XcbContext = @import("XcbContext.zig");
const Win32Context = @import("Win32Context.zig");

pub fn init(allocator: std.mem.Allocator) !Context {
    return switch (@import("builtin").target.os.tag) {
        .linux => try XcbContext.init(allocator),
        .windows => try Win32Context.init(allocator),
        else => @compileError("Unsupported OS"),
    };
}

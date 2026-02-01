const std = @import("std");
const options = @import("options");

pub const Context = @import("Context.zig");

pub const EventHandler = @import("EventHandler.zig");
pub const Key = EventHandler.Key;
pub const Mouse = EventHandler.Mouse;
pub const Event = EventHandler.Event;

pub const Window = @import("Window.zig");

const XcbContext = @import("XcbContext.zig");
const WaylandContext = @import("WaylandContext.zig");
const Win32Context = @import("Win32Context.zig");

pub fn init(allocator: std.mem.Allocator, config: Context.Config) Context.InitError!Context {
    return switch (@import("builtin").target.os.tag) {
        .linux => blk: {
            var wayland_err: Context.InitError = undefined;
            if (options.@"enable-wayland") wayland_blk: {
                break :blk WaylandContext.init(allocator, config) catch |err| {
                    wayland_err = err;
                    break :wayland_blk;
                };
            }

            break :blk if (options.@"enable-x11") try XcbContext.init(allocator, config) else wayland_err;
        },
        .windows => try Win32Context.init(allocator, config),
        else => @compileError("Unsupported OS"),
    };
}

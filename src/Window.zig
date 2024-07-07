const std = @import("std");

const EventHandler = @import("EventHandler.zig");

pub const Config = struct {
    name: []const u8,
    width: u32,
    height: u32,
    event_handler: EventHandler,
    resizable: bool = true,
};

const Self = @This();

handle: *anyopaque,

is_open_fn: *const fn (*anyopaque) bool,
destroy_fn: *const fn (*anyopaque) void,

pub fn isOpen(self: Self) bool {
    return self.is_open_fn(self.handle);
}

pub fn destroy(self: Self) void {
    self.destroy_fn(self.handle);
}

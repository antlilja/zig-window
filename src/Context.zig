const std = @import("std");

const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

pub const CreateWindowError = error{
    OutOfMemory,
    FailedToCreateWindow,
};

pub const Monitor = struct {
    is_primary: bool,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

const Self = @This();

handle: *anyopaque,

deinit_fn: *const fn (*anyopaque) void,

create_window_fn: *const fn (*anyopaque, Window.Config) CreateWindowError!Window,

poll_events_fn: *const fn (*anyopaque) void,

get_monitors_fn: *const fn (*anyopaque, std.mem.Allocator) std.mem.Allocator.Error![]const Monitor,

required_vulkan_instance_extensions_fn: *const fn (*anyopaque) []const [*:0]const u8,

pub fn deinit(self: Self) void {
    self.deinit_fn(self.handle);
}

pub fn createWindow(
    self: Self,
    config: Window.Config,
) CreateWindowError!Window {
    return self.create_window_fn(self.handle, config);
}

pub fn pollEvents(self: Self) void {
    self.poll_events_fn(self.handle);
}

pub fn getMonitors(self: Self, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const Monitor {
    return self.get_monitors_fn(self.handle, allocator);
}

pub fn requiredVulkanInstanceExtensions(self: Self) []const [*:0]const u8 {
    return self.required_vulkan_instance_extensions_fn(self.handle);
}

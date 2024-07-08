const std = @import("std");

const Error = @import("base.zig").Error;

const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const Self = @This();

handle: *anyopaque,

deinit_fn: *const fn (*anyopaque) void,

create_window_fn: *const fn (*anyopaque, Window.Config) Error!Window,

poll_events_fn: *const fn (*anyopaque) void,

required_vulkan_instance_extensions_fn: *const fn (*anyopaque) []const [*:0]const u8,

pub fn deinit(self: Self) void {
    self.deinit_fn(self.handle);
}

pub fn createWindow(
    self: Self,
    config: Window.Config,
) Error!Window {
    return self.create_window_fn(self.handle, config);
}

pub fn pollEvents(self: Self) void {
    self.poll_events_fn(self.handle);
}

pub fn requiredVulkanInstanceExtensions(self: Self) []const [*:0]const u8 {
    return self.required_vulkan_instance_extensions_fn(self.handle);
}

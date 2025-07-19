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

pub const GetInstanceProcAddrFn = fn (*const anyopaque, [*:0]const u8) callconv(.c) ?*const anyopaque;

pub const VulkanGetPresentationSupportError = error{FailedToLoadFunction};

handle: *anyopaque,

deinit_fn: *const fn (*anyopaque) void,

create_window_fn: *const fn (*anyopaque, Window.Config) CreateWindowError!Window,

poll_events_fn: *const fn (*anyopaque) void,

get_monitors_fn: *const fn (*anyopaque, std.mem.Allocator) std.mem.Allocator.Error![]const Monitor,

required_vulkan_instance_extensions_fn: *const fn (*anyopaque) []const [*:0]const u8,

get_physical_device_presentation_support_fn: *const fn (*anyopaque, *const anyopaque, *const anyopaque, u32, *const GetInstanceProcAddrFn) u32,

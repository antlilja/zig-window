const std = @import("std");

const EventHandler = @import("EventHandler.zig");

pub const Config = struct {
    name: []const u8,
    width: u32,
    height: u32,
    event_handler: EventHandler,
    resizable: bool = true,
};

pub const GetInstanceProcAddrFn = fn (*const anyopaque, [*:0]const u8) ?*const anyopaque;

pub const VulkanSurfaceError = error{
    FailedToCreateSurface,
    FailedToLoadFunction,
};

const Self = @This();

handle: *anyopaque,

is_open_fn: *const fn (*anyopaque) bool,
destroy_fn: *const fn (*anyopaque) void,

get_size_fn: *const fn (*anyopaque) struct { u32, u32 },

create_vulkan_surface_fn: *const fn (
    *anyopaque,
    *anyopaque,
    *const GetInstanceProcAddrFn,
    ?*anyopaque,
) VulkanSurfaceError!*anyopaque,

pub fn isOpen(self: Self) bool {
    return self.is_open_fn(self.handle);
}

pub fn destroy(self: Self) void {
    self.destroy_fn(self.handle);
}

pub fn getSize(self: Self) struct { u32, u32 } {
    return self.get_size_fn(self.handle);
}

pub fn createVulkanSurface(
    self: Self,
    comptime Instance: type,
    comptime Surface: type,
    instance: Instance,
    get_instance_proc_addr: *const GetInstanceProcAddrFn,
    allocation_callbacks: ?*const anyopaque,
) VulkanSurfaceError!Surface {
    const func: *const fn (
        *anyopaque,
        Instance,
        *const GetInstanceProcAddrFn,
        ?*const anyopaque,
    ) VulkanSurfaceError!Surface = @ptrCast(self.create_vulkan_surface_fn);

    return func(
        self.handle,
        instance,
        get_instance_proc_addr,
        allocation_callbacks,
    );
}

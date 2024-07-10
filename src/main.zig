const std = @import("std");

pub const Context = @import("Context.zig");

pub const EventHandler = @import("EventHandler.zig");
pub const Key = EventHandler.Key;
pub const Mouse = EventHandler.Mouse;
pub const Event = EventHandler.Event;

pub const Window = @import("Window.zig");

const XcbContext = @import("XcbContext.zig");
const Win32Context = @import("Win32Context.zig");

var initialized: bool = false;
var context: Context = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    std.debug.assert(!initialized);
    context = switch (@import("builtin").target.os.tag) {
        .linux => try XcbContext.init(allocator),
        .windows => try Win32Context.init(allocator),
        else => @compileError("Unsupported OS"),
    };
    initialized = true;
}

pub fn deinit() void {
    std.debug.assert(initialized);
    context.deinit_fn(context.handle);
}

pub fn createWindow(
    config: Window.Config,
) Context.CreateWindowError!Window {
    std.debug.assert(initialized);
    return context.create_window_fn(context.handle, config);
}

pub fn pollEvents() void {
    std.debug.assert(initialized);
    context.poll_events_fn(context.handle);
}

pub fn getMonitors(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const Context.Monitor {
    std.debug.assert(initialized);
    return context.get_monitors_fn(context.handle, allocator);
}

pub fn requiredVulkanInstanceExtensions() []const [*:0]const u8 {
    std.debug.assert(initialized);
    return context.required_vulkan_instance_extensions_fn(context.handle);
}

pub fn getPhysicalDevicePresentationSupport(
    comptime Instance: type,
    comptime PhysicalDevice: type,
    instance: Instance,
    physical_device: PhysicalDevice,
    queue_family_index: u32,
    get_instance_proc_addr: *const Context.GetInstanceProcAddrFn,
) Context.VulkanGetPresentationSupportError!u32 {
    std.debug.assert(initialized);
    const func: *const fn (
        *anyopaque,
        Instance,
        PhysicalDevice,
        u32,
        *const Context.GetInstanceProcAddrFn,
    ) Context.VulkanGetPresentationSupportError!u32 = @ptrCast(context.get_physical_device_presentation_support_fn);

    return func(
        context.handle,
        instance,
        physical_device,
        queue_family_index,
        get_instance_proc_addr,
    );
}

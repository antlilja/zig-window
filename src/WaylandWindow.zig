const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const wayland = @import("wayland.zig");

const WaylandContext = @import("WaylandContext.zig");

const Self = @This();

const xdg_surface_listener = wayland.XdgSurface.Listener{
    .configure = @ptrCast(&xdgSurfaceHandleConfigure),
};

const xdg_top_level_listener = wayland.XdgToplevel.Listener{
    .configure = @ptrCast(&xdgToplevelHandleConfigure),
    .close = @ptrCast(&xdgToplevelHandleClose),
};

width: u32,
height: u32,
is_open: bool,
resizable: bool,

event_handler: EventHandler,

context: *WaylandContext,
surface: *wayland.Surface,
xdg_surface: *wayland.XdgSurface,
toplevel: *wayland.XdgToplevel,

resize: ?EventHandler.Event.ResizeData = null,

pub fn create(
    self: *Self,
    context: *WaylandContext,
    config: Window.Config,
) Context.CreateWindowError!void {
    const surface = context.lib.wl_compositor_create_surface(context.compositor) orelse return error.FailedToCreateWindow;
    context.lib.wl_surface_set_user_data(surface, self);

    const xdg_surface = context.lib.xdg_wm_base_get_xdg_surface(context.wm_base, surface) orelse return error.FailedToCreateWindow;
    context.lib.xdg_surface_add_listener(xdg_surface, &xdg_surface_listener, self);

    const toplevel = context.lib.xdg_surface_get_toplevel(xdg_surface) orelse return error.FailedToCreateWindow;
    context.lib.xdg_toplevel_add_listener(toplevel, &xdg_top_level_listener, self);

    context.lib.xdg_toplevel_set_title(toplevel, "Example window");
    context.lib.xdg_toplevel_set_app_id(toplevel, "Example window");

    if (!config.resizable) {
        context.lib.xdg_toplevel_set_max_size(toplevel, @intCast(config.width), @intCast(config.height));
        context.lib.xdg_toplevel_set_min_size(toplevel, @intCast(config.width), @intCast(config.height));
    }

    self.* = .{
        .is_open = true,
        .width = config.width,
        .height = config.height,
        .resizable = config.resizable,

        .event_handler = config.event_handler,

        .context = context,
        .surface = surface,
        .xdg_surface = xdg_surface,
        .toplevel = toplevel,
    };

    context.lib.wl_surface_commit(surface);
    context.lib.wl_display_roundtrip(context.display);
    context.lib.wl_surface_commit(surface);
}

pub fn destroy(self: *const Self) void {
    self.context.lib.xdg_toplevel_destroy(self.toplevel);
    self.context.lib.xdg_surface_destroy(self.xdg_surface);
    self.context.lib.wl_surface_destroy(self.surface);
    self.context.destroyWindow(self);
}

pub fn isOpen(self: *const Self) bool {
    return self.is_open;
}

pub fn getSize(self: *const Self) struct { u32, u32 } {
    return .{ self.width, self.height };
}

pub fn createVulkanSurface(
    self: *const Self,
    instance: *const anyopaque,
    get_instance_proc_addr: *const Context.GetInstanceProcAddrFn,
    allocation_callbacks: ?*const anyopaque,
) Window.VulkanSurfaceError!*anyopaque {
    const CreateInfo = extern struct {
        s_type: c_int = 1000006000,
        p_next: ?*anyopaque = null,
        flags: c_int = 0,
        display: *wayland.Display,
        surface: *wayland.Surface,
    };
    const create_surface: *const fn (
        *const anyopaque,
        *const CreateInfo,
        ?*const anyopaque,
        **anyopaque,
    ) callconv(.c) c_int = @ptrCast(get_instance_proc_addr(
        instance,
        "vkCreateWaylandSurfaceKHR",
    ) orelse return error.FailedToLoadFunction);

    const create_info = CreateInfo{
        .display = self.context.display,
        .surface = self.surface,
    };

    var surface: *anyopaque = undefined;
    if (create_surface(
        instance,
        &create_info,
        allocation_callbacks,
        &surface,
    ) != 0) return error.FailedToCreateSurface;

    return surface;
}

fn xdgSurfaceHandleConfigure(self: *Self, xdg_surface: *wayland.XdgSurface, serial: u32) callconv(.c) void {
    self.context.lib.xdg_surface_ack_configure(xdg_surface, serial);
    if (self.resize) |resize| {
        self.event_handler.handleEvent(.{ .Resize = resize });
        self.resize = null;
    }
}

fn xdgToplevelHandleConfigure(
    self: *Self,
    toplevel: *wayland.XdgToplevel,
    width: i32,
    height: i32,
    states: *anyopaque,
) callconv(.c) void {
    _ = toplevel;
    _ = states;
    if (width != 0 and height != 0) self.resize = .{
        @intCast(width),
        @intCast(height),
    };
}

fn xdgToplevelHandleClose(self: *Self, toplevel: *wayland.XdgToplevel) callconv(.c) void {
    _ = toplevel;
    self.is_open = false;
}

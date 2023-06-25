const std = @import("std");
const c = std.c;
const base = @import("base.zig");
const Event = base.Event;
const Rect = base.Rect;
const Point = base.Point;
const Cursor = base.Cursor;
const Error = base.Error;
const EventHandler = base.EventHandler;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const xdg = wayland.client.xdg;

pub const Window = struct {
    width: u32,
    height: u32,
    is_open: bool = true,
    is_fullscreen: bool = false,
    allocator: std.mem.Allocator,

    // Platform specific
    display: *wl.Display,
    registry: *wl.Registry,
    compositor: *wl.Compositor,
    surface: *wl.Surface,

    xdg_base: *xdg.WmBase,
    xdg_surface: *xdg.Surface,
    xdg_toplevel: *xdg.Toplevel,

    event_handler_data: ?*anyopaque,
    event_handler: EventHandler,

    pub fn create(
        name: []const u8,
        width: u32,
        height: u32,
        event_handler: EventHandler,
        event_handler_data: ?*anyopaque,
        allocator: std.mem.Allocator,
    ) !*Window {
        _ = name;
        const self = try allocator.create(Window);
        errdefer allocator.destroy(self);
        self.* = .{
            .width = width,
            .height = height,

            .event_handler = event_handler,
            .event_handler_data = event_handler_data,

            .allocator = allocator,

            .display = undefined,
            .registry = undefined,
            .compositor = undefined,
            .surface = undefined,

            .xdg_base = undefined,
            .xdg_surface = undefined,
            .xdg_toplevel = undefined,
        };

        self.display = try wl.Display.connect(null);
        errdefer self.display.disconnect();

        self.registry = try self.display.getRegistry();

        self.registry.setListener(*Window, registryListener, self);

        if (self.display.roundtrip() != .SUCCESS) return error.FailedToCreateWindow;

        self.surface = try self.compositor.createSurface();
        errdefer self.surface.destroy();

        self.xdg_surface = try self.xdg_base.getXdgSurface(self.surface);
        errdefer self.xdg_surface.destroy();

        self.xdg_toplevel = try self.xdg_surface.getToplevel();
        errdefer self.xdg_toplevel.destroy();

        // self.xdg_toplevel.setTitle(name);

        self.xdg_surface.setListener(*Window, xdgSurfaceListener, self);
        self.xdg_toplevel.setListener(*Window, xdgToplevelListener, self);

        self.surface.commit();
        if (self.display.roundtrip() != .SUCCESS) return error.FailedToCreateWindow;

        return self;
    }

    pub fn destroy(self: *const Window) void {
        self.xdg_toplevel.destroy();
        self.xdg_surface.destroy();
        self.surface.destroy();
        self.display.disconnect();
        self.allocator.destroy(self);
    }

    pub fn isOpen(self: *const Window) bool {
        return self.is_open;
    }

    pub fn isFullscreen(self: *const Window) bool {
        return self.is_fullscreen;
    }

    pub fn setName(self: *const Window, name: []const u8) void {
        _ = self;
        _ = name;
    }

    pub fn setSize(self: Window, width: u16, height: u16) void {
        if (self.is_fullscreen()) return;
        _ = width;
        _ = height;
    }

    pub fn setFullscreen(self: *Window, comptime fullscreen: bool) void {
        if (self.isFullscreen() == fullscreen) return;

        if (fullscreen) self.*.flags |= 0b10 else self.*.flags &= 0b101;
    }

    pub fn update(self: *Window) void {
        while (!self.display.prepareRead()) {
            _ = self.display.dispatchPending();
        }

        _ = self.display.flush();
        _ = self.display.readEvents();
        _ = self.display.dispatchPending();
    }

    fn registryListener(
        registry: *wl.Registry,
        event: wl.Registry.Event,
        self: *Window,
    ) void {
        switch (event) {
            .global => |global| {
                if (std.cstr.cmp(global.interface, wl.Compositor.getInterface().name) == 0) {
                    self.compositor = registry.bind(global.name, wl.Compositor, 1) catch return;
                } else if (std.cstr.cmp(global.interface, xdg.WmBase.getInterface().name) == 0) {
                    self.xdg_base = registry.bind(global.name, xdg.WmBase, 1) catch return;
                }
            },
            .global_remove => {},
        }
    }

    fn xdgSurfaceListener(xdg_surface: *xdg.Surface, event: xdg.Surface.Event, self: *Window) void {
        switch (event) {
            .configure => |configure| {
                xdg_surface.ackConfigure(configure.serial);
                self.surface.commit();
            },
        }
    }

    fn xdgToplevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, self: *Window) void {
        switch (event) {
            .configure => |configure| {
                const new_width = @intCast(u32, configure.width);
                const new_height = @intCast(u32, configure.height);

                if ((new_width == self.width and new_height == self.height) or
                    configure.width == 0 or configure.height == 0) return;

                self.width = new_width;
                self.height = new_height;
                self.event_handler(self.event_handler_data, Event{ .Resize = .{
                    .width = new_width,
                    .height = new_height,
                } });
            },
            .close => {
                self.is_open = false;
                self.event_handler(self.event_handler_data, Event.Destroy);
            },
        }
    }
};

const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const win32 = @import("win32.zig");

const Win32Context = @import("Win32Context.zig");

const Self = @This();

width: u32,
height: u32,
is_open: bool,

event_handler: EventHandler,

context: *Win32Context,
hwnd: *anyopaque,

pub fn create(
    self: *Self,
    context: *Win32Context,
    config: Window.Config,
) Context.CreateWindowError!void {
    var buffer: [256]u8 = undefined;
    if (config.name.len >= buffer.len - 1) return error.FailedToCreateWindow;
    @memcpy(buffer[0..config.name.len], config.name);
    buffer[config.name.len] = 0;
    const name_z: [*:0]u8 = @ptrCast(buffer[0..config.name.len]);

    const style = if (config.resizable)
        win32.WS_VISIBLE |
            win32.WS_OVERLAPPED |
            win32.WS_CAPTION |
            win32.WS_SYSMENU |
            win32.WS_THICKFRAME |
            win32.WS_MINIMIZEBOX |
            win32.WS_MAXIMIZEBOX
    else
        win32.WS_VISIBLE |
            win32.WS_OVERLAPPED |
            win32.WS_CAPTION |
            win32.WS_SYSMENU |
            win32.WS_MINIMIZEBOX;

    var rect = win32.Rect{
        .left = 0,
        .right = @intCast(config.width),
        .top = 0,
        .bottom = @intCast(config.height),
    };

    _ = win32.AdjustWindowRectEx(
        &rect,
        style,
        0,
        0,
    );

    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;

    const hwnd = win32.CreateWindowExA(
        0,
        "zig_window",
        name_z,
        style,
        -2147483648,
        -2147483648,
        width,
        height,
        null,
        null,
        context.instance,
        null,
    ) orelse return error.FailedToCreateWindow;

    self.* = .{
        .width = config.width,
        .height = config.height,
        .is_open = true,
        .event_handler = config.event_handler,
        .context = context,
        .hwnd = hwnd,
    };

    _ = win32.SetWindowLongPtrA(hwnd, -21, @ptrCast(self)) orelse blk: {
        if (win32.GetLastError() == 0) break :blk;
        return error.FailedToCreateWindow;
    };
}

pub fn destroy(self: *Self) void {
    win32.DestroyWindow(self.hwnd);
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
        s_type: c_int = 1000009000,
        p_next: ?*anyopaque = null,
        flags: c_int = 0,
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };
    const create_surface: *const fn (
        *const anyopaque,
        *const CreateInfo,
        ?*const anyopaque,
        **anyopaque,
    ) c_int = @ptrCast(get_instance_proc_addr(
        instance,
        "vkCreateWin32SurfaceKHR",
    ) orelse return error.FailedToLoadFunction);

    const create_info = CreateInfo{
        .hinstance = self.context.instance,
        .hwnd = self.hwnd,
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

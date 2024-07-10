const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const Win32Context = @import("Win32Context.zig");

const Self = @This();

extern fn CreateWindowExA(
    ex_style: u32,
    class_name: ?[*:0]const u8,
    window_name: ?[*:0]const u8,
    style: u32,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    parent: ?*anyopaque,
    menu: ?*anyopaque,
    instance: ?*anyopaque,
    lp_param: ?*anyopaque,
) callconv(.C) ?*anyopaque;
extern fn DestroyWindow(hwnd: *anyopaque) callconv(.C) void;
extern fn AdjustWindowRectEx(rect: *Win32Context.Rect, style: u32, menu: c_int, ex_style: u32) callconv(.C) c_int;
extern fn SetWindowLongPtrA(hwnd: *anyopaque, index: c_int, ptr: *anyopaque) callconv(.C) ?*anyopaque;
extern fn SetLastError(code: u32) callconv(.C) void;
extern fn GetLastError() callconv(.C) u32;

const WS_CAPTION: u32 = 0x00C00000;
const WS_MAXIMIZEBOX: u32 = 0x00010000;
const WS_MINIMIZEBOX: u32 = 0x00020000;
const WS_OVERLAPPED: u32 = 0x00000000;
const WS_SYSMENU: u32 = 0x00080000;
const WS_THICKFRAME: u32 = 0x00040000;
const WS_VISIBLE: u32 = 0x10000000;

width: u32,
height: u32,
is_open: bool,
resizable: bool,

event_handler: EventHandler,

context: *const Win32Context,
hwnd: *anyopaque,

pub fn create(
    context: *const Win32Context,
    config: Window.Config,
) Context.CreateWindowError!*Self {
    const name_z = try context.allocator.dupeZ(u8, config.name);
    defer context.allocator.free(name_z);

    const style = if (config.resizable)
        WS_VISIBLE |
            WS_OVERLAPPED |
            WS_CAPTION |
            WS_SYSMENU |
            WS_THICKFRAME |
            WS_MINIMIZEBOX |
            WS_MAXIMIZEBOX
    else
        WS_VISIBLE |
            WS_OVERLAPPED |
            WS_CAPTION |
            WS_SYSMENU |
            WS_MINIMIZEBOX;

    var rect = Win32Context.Rect{
        .left = 0,
        .right = @intCast(config.width),
        .top = 0,
        .bottom = @intCast(config.height),
    };

    _ = AdjustWindowRectEx(
        &rect,
        style,
        0,
        0,
    );

    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;

    const hwnd = CreateWindowExA(
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

    const self = try context.allocator.create(Self);
    errdefer context.allocator.destroy(self);

    self.* = .{
        .width = config.width,
        .height = config.height,
        .is_open = true,
        .resizable = config.resizable,
        .event_handler = config.event_handler,
        .context = context,
        .hwnd = hwnd,
    };

    _ = SetWindowLongPtrA(hwnd, -21, @ptrCast(self)) orelse blk: {
        if (GetLastError() == 0) break :blk;
        return error.FailedToCreateWindow;
    };

    return self;
}

pub fn destroy(self: *Self) void {
    DestroyWindow(self.hwnd);
    self.context.allocator.destroy(self);
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

const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const win32 = @import("win32.zig");

const Win32Window = @import("Win32Window.zig");

const Self = @This();

const required_vulkan_extensions = [_][*:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_win32_surface",
};

instance: *anyopaque,

windows: []Win32Window,
available_windows: std.ArrayList(u32),

pub fn init(allocator: std.mem.Allocator, config: Context.Config) Context.InitError!Context {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.windows = try allocator.alloc(Win32Window, config.max_window_count);
    errdefer allocator.free(self.windows);

    self.available_windows = try .initCapacity(allocator, config.max_window_count);
    errdefer self.available_windows.deinit(allocator);
    for (0..config.max_window_count) |window_index| self.available_windows.appendAssumeCapacity(@intCast(window_index));

    self.instance = win32.GetModuleHandleA(null);

    const window_class = win32.WindowClass{
        .instance = self.instance,
        .proc = &windowProc,
        .class_name = "zig_window",
        .cursor = win32.LoadCursorA(null, 32512),
        .size = @sizeOf(win32.WindowClass),
    };

    if (win32.RegisterClassExA(&window_class) == 0) return error.FailedToInitialize;

    return .{
        .handle = @ptrCast(self),
        .deinit_fn = @ptrCast(&deinit),
        .poll_events_fn = @ptrCast(&pollEvents),
        .create_window_fn = @ptrCast(&createWindow),
        .get_monitors_fn = @ptrCast(&getMonitors),
        .required_vulkan_instance_extensions_fn = @ptrCast(&requiredVulkanInstanceExtensions),
        .get_physical_device_presentation_support_fn = @ptrCast(&getPhysicalDevicePresentationSupport),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.available_windows.deinit(allocator);
    allocator.free(self.windows);
    allocator.destroy(self);
}

pub fn pollEvents(_: *Self) void {
    var msg: win32.Message = undefined;
    while (win32.PeekMessageA(
        &msg,
        null,
        0,
        0,
        1,
    ) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}

pub fn createWindow(self: *Self, config: Window.Config) Context.CreateWindowError!Window {
    const window_index = self.available_windows.pop() orelse return error.MaxWindowCountExceeded;
    const window = &self.windows[window_index];
    try window.create(
        self,
        config,
    );
    errdefer window.destroy();

    return .{
        .handle = @ptrCast(window),
        .is_open_fn = @ptrCast(&Win32Window.isOpen),
        .destroy_fn = @ptrCast(&Win32Window.destroy),
        .get_size_fn = @ptrCast(&Win32Window.getSize),
        .create_vulkan_surface_fn = @ptrCast(&Win32Window.createVulkanSurface),
    };
}

pub fn destroyWindow(self: *Self, window: *const Win32Window) void {
    const window_index: u32 = @intCast(@intFromPtr(window) - @intFromPtr(self.windows.ptr));
    self.available_windows.appendAssumeCapacity(window_index);
}

pub fn getMonitors(_: *Self, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const Context.Monitor {
    const State = struct {
        out_of_memory: bool = false,
        allocator: std.mem.Allocator,
        monitors: std.ArrayList(Context.Monitor),
    };
    var state = State{
        .allocator = allocator,
        .monitors = .empty,
    };
    defer state.monitors.deinit(allocator);
    _ = win32.EnumDisplayMonitors(null, null, &struct {
        fn proc(monitor: *anyopaque, _: ?*anyopaque, _: ?*win32.Rect, lparam: *anyopaque) callconv(.c) c_int {
            const state_: *State = @ptrCast(@alignCast(lparam));
            var monitor_info: win32.MonitorInfo = undefined;
            monitor_info.size = @sizeOf(win32.MonitorInfo);
            if (win32.GetMonitorInfoA(monitor, &monitor_info) != 0) {
                state_.monitors.append(state_.allocator, .{
                    .is_primary = (monitor_info.flags & 1) != 0,
                    .x = monitor_info.work.left,
                    .y = monitor_info.work.top,
                    .width = @intCast(monitor_info.work.right - monitor_info.work.left),
                    .height = @intCast(monitor_info.work.bottom - monitor_info.work.top),
                }) catch {
                    state_.out_of_memory = true;
                };
            }
            return 1;
        }
    }.proc, @ptrCast(&state));

    if (state.out_of_memory) return error.OutOfMemory;

    return try state.monitors.toOwnedSlice(allocator);
}

pub fn requiredVulkanInstanceExtensions(_: *const Self) []const [*:0]const u8 {
    return &required_vulkan_extensions;
}

pub fn getPhysicalDevicePresentationSupport(
    _: *Self,
    instance: *const anyopaque,
    physical_device: *const anyopaque,
    queue_family_index: u32,
    get_instance_proc_addr: *const Context.GetInstanceProcAddrFn,
) Context.VulkanGetPresentationSupportError!u32 {
    const get_physical_device_presentation_support: *const fn (
        *const anyopaque,
        u32,
    ) u32 = @ptrCast(get_instance_proc_addr(
        instance,
        "vkGetPhysicalDeviceWin32PresentationSupportKHR",
    ) orelse return error.FailedToLoadFunction);

    return get_physical_device_presentation_support(
        physical_device,
        queue_family_index,
    );
}

fn windowProc(hwnd: ?*anyopaque, msg: win32.MessageId, wparam: u64, lparam: i64) callconv(.c) usize {
    const window: *Win32Window = @ptrCast(@alignCast(win32.GetWindowLongPtrA(hwnd, -21) orelse return win32.DefWindowProcA(hwnd, @intFromEnum(msg), wparam, lparam)));
    switch (msg) {
        .sys_key_down, .key_down => window.event_handler.handleEvent(.{ .KeyPress = keycodeToEnum(wparam, lparam) }),
        .sys_key_up, .key_up => window.event_handler.handleEvent(.{ .KeyRelease = keycodeToEnum(wparam, lparam) }),
        .size => {
            const size: u64 = @bitCast(lparam);
            const word: u32 = @truncate(size);
            const width: u16 = @truncate(word);
            const height: u16 = @truncate(word >> 16);
            window.width = @intCast(width);
            window.height = @intCast(height);
            window.event_handler.handleEvent(.{ .Resize = .{
                window.width,
                window.height,
            } });
        },
        .set_focus => window.event_handler.handleEvent(.FocusIn),
        .kill_focus => window.event_handler.handleEvent(.FocusOut),
        .close => {
            window.is_open = false;
            window.event_handler.handleEvent(.Destroy);
            return 0;
        },
        .mouse_move => {
            const coords: u64 = @bitCast(lparam);
            const word: u32 = @truncate(coords);
            const x: u16 = @truncate(word);
            const y: u16 = @truncate(word >> 16);
            window.event_handler.handleEvent(.{ .MouseMove = .{
                @intCast(x),
                @intCast(y),
            } });
        },
        .left_button_down => window.event_handler.handleEvent(.{ .MousePress = .left }),
        .left_button_up => window.event_handler.handleEvent(.{ .MouseRelease = .left }),
        .right_button_down => window.event_handler.handleEvent(.{ .MousePress = .right }),
        .right_button_up => window.event_handler.handleEvent(.{ .MouseRelease = .right }),
        .middle_button_down => window.event_handler.handleEvent(.{ .MousePress = .middle }),
        .middle_button_up => window.event_handler.handleEvent(.{ .MouseRelease = .middle }),
        .x_button_down => window.event_handler.handleEvent(.{ .MousePress = if ((wparam >> 16) == 1) .one else .two }),
        .x_button_up => window.event_handler.handleEvent(.{ .MouseRelease = if ((wparam >> 16) == 1) .one else .two }),
        else => {},
    }
    return win32.DefWindowProcA(hwnd, @intFromEnum(msg), wparam, lparam);
}

fn keycodeToEnum(code: u64, param: i64) EventHandler.Key {
    return switch (code) {
        0x30 => .zero,
        0x31 => .one,
        0x32 => .two,
        0x33 => .three,
        0x34 => .four,
        0x35 => .five,
        0x36 => .six,
        0x37 => .seven,
        0x38 => .eight,
        0x39 => .nine,
        0x60 => .numpad_0,
        0x61 => .numpad_1,
        0x62 => .numpad_2,
        0x63 => .numpad_3,
        0x64 => .numpad_4,
        0x65 => .numpad_5,
        0x66 => .numpad_6,
        0x67 => .numpad_7,
        0x68 => .numpad_8,
        0x69 => .numpad_9,
        0x6e => .numpad_decimal,
        0x6b => .numpad_add,
        0x6d => .numpad_subtract,
        0x6a => .numpad_multiply,
        0x6f => .numpad_divide,
        0x90 => .numpad_lock,
        0x41 => .a,
        0x42 => .b,
        0x43 => .c,
        0x44 => .d,
        0x45 => .e,
        0x46 => .f,
        0x47 => .g,
        0x48 => .h,
        0x49 => .i,
        0x4a => .j,
        0x4b => .k,
        0x4c => .l,
        0x4d => .m,
        0x4e => .n,
        0x4f => .o,
        0x50 => .p,
        0x51 => .q,
        0x52 => .r,
        0x53 => .s,
        0x54 => .t,
        0x55 => .u,
        0x56 => .v,
        0x57 => .w,
        0x58 => .x,
        0x59 => .y,
        0x5a => .z,
        0x26 => .up,
        0x28 => .down,
        0x27 => .right,
        0x25 => .left,
        0xbe => .period,
        0xbc => .comma,
        0x10 => if (win32.MapVirtualKeyA(@truncate((@as(u64, @bitCast(param)) & 0xff0000) >> 16), 3) == 0xa1) .right_shift else .left_shift,
        0x11 => if ((param & 0x1000000) != 0) .right_ctrl else .left_ctrl,
        0x12 => if ((param & 0x1000000) != 0) .right_alt else .left_alt,
        0xd => if ((param & 0x1000000) != 0) .numpad_enter else .enter,
        0x2d => .insert,
        0x2e => .delete,
        0x24 => .home,
        0x23 => .end,
        0x21 => .page_up,
        0x22 => .page_down,
        0x2c => .print_screen,
        0x91 => .scroll_lock,
        0x13 => .pause,
        0x1b => .escape,
        0x9 => .tab,
        0x14 => .caps_lock,
        0x5b => .left_super,
        0x20 => .space,
        0x8 => .backspace,
        0x5d => .menu,
        0xbf => .slash,
        0xdc => .back_slash,
        0xbd => .minus,
        0xbb => .equal,
        0xde => .apostrophe,
        0xba => .semicolon,
        0xdb => .left_bracket,
        0xdd => .right_bracket,
        0xc0 => .tilde,
        0x70 => .f1,
        0x71 => .f2,
        0x72 => .f3,
        0x73 => .f4,
        0x74 => .f5,
        0x75 => .f6,
        0x76 => .f7,
        0x77 => .f8,
        0x78 => .f9,
        0x79 => .f10,
        0x7a => .f11,
        0x7b => .f12,
        0xe2 => .oem_1,
        else => .none,
    };
}

const std = @import("std");

const base = @import("base.zig");
const Error = base.Error;
const Event = base.Event;
const Key = base.Key;
const Mouse = base.Mouse;
const Rect = base.Rect;
const Point = base.Point;

const EventHandler = @import("EventHandler.zig");
const Context = @import("Context.zig");
const Window = @import("Window.zig");

const Win32Window = @import("Win32Window.zig");

const MessageId = enum(u32) {
    move = 0x3,
    size = 0x5,
    set_focus = 0x7,
    kill_focus = 0x8,
    close = 0x10,
    key_down = 0x100,
    key_up = 0x101,
    sys_key_down = 0x104,
    sys_key_up = 0x105,
    mouse_move = 0x200,
    left_button_down = 0x201,
    left_button_up = 0x202,
    right_button_down = 0x204,
    right_button_up = 0x205,
    middle_button_down = 0x207,
    middle_button_up = 0x208,
    mouse_wheel = 0x20a,
    x_button_down = 0x20b,
    x_button_up = 0x20c,
    mouse_horizontal_wheel = 0x20e,
    mouse_leave = 0x2a3,
    _,
};

const WindowClass = extern struct {
    size: u32 = 0,
    style: u32 = 0,
    proc: *const fn (*anyopaque, MessageId, u64, i64) callconv(.C) usize,
    class_extra: c_int = 0,
    window_extra: c_int = 0,
    instance: ?*anyopaque = null,
    icon: ?*anyopaque = null,
    cursor: ?*anyopaque = null,
    brush: ?*anyopaque = null,
    menu_name: ?[*:0]const u8 = null,
    class_name: ?[*:0]const u8 = null,
    icon_sm: ?*anyopaque = null,
};

const Message = extern struct {
    hwnd: *anyopaque,
    message: u32,
    w_param: u64,
    l_param: u64,
    time: u32,
    point: extern struct {
        x: i32,
        y: i32,
    },
    private: u32,
};

const Self = @This();

extern fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.C) *anyopaque;
extern fn RegisterClassExA(window_class: *const WindowClass) callconv(.C) u16;
extern fn LoadCursorA(instance: ?*anyopaque, cursor: usize) callconv(.C) ?*anyopaque;
extern fn PeekMessageA(msg: *Message, hwnd: ?*anyopaque, filter_min: u32, filter_max: u32, remove_msg: u32) callconv(.C) c_int;
extern fn TranslateMessage(msg: *const Message) callconv(.C) c_int;
extern fn DispatchMessageW(msg: *const Message) callconv(.C) *anyopaque;
extern fn DefWindowProcA(hwnd: ?*anyopaque, msg: u32, wparam: u64, lparam: i64) callconv(.C) usize;
extern fn GetWindowLongPtrA(hwnd: ?*anyopaque, index: c_int) ?*anyopaque;
extern fn MapVirtualKeyA(code: u32, map_type: u32) callconv(.C) u32;

const required_vulkan_extensions = [_][*:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_win32_surface",
};

instance: *anyopaque,

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Context {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.instance = GetModuleHandleA(null);
    self.allocator = allocator;

    const window_class = WindowClass{
        .instance = self.instance,
        .proc = &windowProc,
        .class_name = "zig_window",
        .cursor = LoadCursorA(null, 32512),
        .size = @sizeOf(WindowClass),
    };

    if (RegisterClassExA(&window_class) == 0) return error.FailedToInitialize;

    return .{
        .handle = @ptrCast(self),
        .deinit_fn = @ptrCast(&deinit),
        .poll_events_fn = @ptrCast(&pollEvents),
        .create_window_fn = @ptrCast(&createWindow),
        .required_vulkan_instance_extensions_fn = @ptrCast(&requiredVulkanInstanceExtensions),
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.destroy(self);
}

pub fn pollEvents(_: *Self) void {
    var msg: Message = undefined;
    while (PeekMessageA(
        &msg,
        null,
        0,
        0,
        1,
    ) != 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
}

pub fn createWindow(self: *Self, config: Window.Config) Error!Window {
    const window = try Win32Window.create(
        self,
        config,
    );

    return .{
        .handle = @ptrCast(window),
        .is_open_fn = @ptrCast(&Win32Window.isOpen),
        .destroy_fn = @ptrCast(&Win32Window.destroy),
        .get_size_fn = @ptrCast(&Win32Window.getSize),
        .create_vulkan_surface_fn = @ptrCast(&Win32Window.createVulkanSurface),
    };
}

pub fn requiredVulkanInstanceExtensions(_: *const Self) []const [*:0]const u8 {
    return &required_vulkan_extensions;
}

fn windowProc(hwnd: ?*anyopaque, msg: MessageId, wparam: u64, lparam: i64) callconv(.C) usize {
    const window: *Win32Window = @alignCast(@ptrCast(GetWindowLongPtrA(hwnd, -21) orelse return DefWindowProcA(hwnd, @intFromEnum(msg), wparam, lparam)));
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
            window.event_handler.handleEvent(.{ .Resize = Rect{
                .width = window.width,
                .height = window.height,
            } });
        },
        .set_focus => window.event_handler.handleEvent(.FocusIn),
        .kill_focus => window.event_handler.handleEvent(.FocusOut),
        .close => {
            window.is_open = false;
            window.event_handler.handleEvent(.Destroy);
        },
        .mouse_move => {
            const coords: u64 = @bitCast(lparam);
            const word: u32 = @truncate(coords >> 32);
            const x: u16 = @truncate(word);
            const y: u16 = @truncate(word >> 16);
            window.event_handler.handleEvent(.{ .MouseMove = Point{
                .x = @intCast(x),
                .y = @intCast(y),
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
    return DefWindowProcA(hwnd, @intFromEnum(msg), wparam, lparam);
}

fn keycodeToEnum(code: u64, param: i64) Key {
    return switch (code) {
        0x30 => Key.zero,
        0x31 => Key.one,
        0x32 => Key.two,
        0x33 => Key.three,
        0x34 => Key.four,
        0x35 => Key.five,
        0x36 => Key.six,
        0x37 => Key.seven,
        0x38 => Key.eight,
        0x39 => Key.nine,
        0x60 => Key.numpad_0,
        0x61 => Key.numpad_1,
        0x62 => Key.numpad_2,
        0x63 => Key.numpad_3,
        0x64 => Key.numpad_4,
        0x65 => Key.numpad_5,
        0x66 => Key.numpad_6,
        0x67 => Key.numpad_7,
        0x68 => Key.numpad_8,
        0x69 => Key.numpad_9,
        0x6e => Key.numpad_decimal,
        0x6b => Key.numpad_add,
        0x6d => Key.numpad_subtract,
        0x6a => Key.numpad_multiply,
        0x6f => Key.numpad_divide,
        0x90 => Key.numpad_lock,
        0x41 => Key.a,
        0x42 => Key.b,
        0x43 => Key.c,
        0x44 => Key.d,
        0x45 => Key.e,
        0x46 => Key.f,
        0x47 => Key.g,
        0x48 => Key.h,
        0x49 => Key.i,
        0x4a => Key.j,
        0x4b => Key.k,
        0x4c => Key.l,
        0x4d => Key.m,
        0x4e => Key.n,
        0x4f => Key.o,
        0x50 => Key.p,
        0x51 => Key.q,
        0x52 => Key.r,
        0x53 => Key.s,
        0x54 => Key.t,
        0x55 => Key.u,
        0x56 => Key.v,
        0x57 => Key.w,
        0x58 => Key.x,
        0x59 => Key.y,
        0x5a => Key.z,
        0x26 => Key.up,
        0x28 => Key.down,
        0x27 => Key.right,
        0x25 => Key.left,
        0xbe => Key.period,
        0xbc => Key.comma,
        0x10 => if (MapVirtualKeyA(@truncate((@as(u64, @bitCast(param)) & 0xff0000) >> 16), 3) == 0xa1) Key.RightShift else Key.LeftShift,
        0x11 => if ((param & 0x1000000) != 0) Key.right_ctrl else Key.left_ctrl,
        0x12 => if ((param & 0x1000000) != 0) Key.right_alt else Key.left_alt,
        0xd => if ((param & 0x1000000) != 0) Key.numpad_enter else Key.enter,
        0x2d => Key.insert,
        0x2e => Key.delete,
        0x24 => Key.home,
        0x23 => Key.end,
        0x21 => Key.page_up,
        0x22 => Key.page_down,
        0x2c => Key.print_screen,
        0x91 => Key.scroll_lock,
        0x13 => Key.pause,
        0x1b => Key.escape,
        0x9 => Key.tab,
        0x14 => Key.caps_lock,
        0x5b => Key.left_super,
        0x20 => Key.space,
        0x8 => Key.backspace,
        0x5d => Key.menu,
        0xbf => Key.slash,
        0xdc => Key.back_slash,
        0xbd => Key.minus,
        0xbb => Key.equal,
        0xde => Key.apostrophe,
        0xba => Key.semicolon,
        0xdb => Key.left_bracket,
        0xdd => Key.right_bracket,
        0xc0 => Key.tilde,
        0x70 => Key.f1,
        0x71 => Key.f2,
        0x72 => Key.f3,
        0x73 => Key.f4,
        0x74 => Key.f5,
        0x75 => Key.f6,
        0x76 => Key.f7,
        0x77 => Key.f8,
        0x78 => Key.f9,
        0x79 => Key.f10,
        0x7a => Key.f11,
        0x7b => Key.f12,
        0xe2 => Key.oem_1,
        else => Key.none,
    };
}

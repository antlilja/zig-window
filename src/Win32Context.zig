const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
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

pub fn createWindow(self: *Self, config: Window.Config) Context.CreateWindowError!Window {
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
        },
        .mouse_move => {
            const coords: u64 = @bitCast(lparam);
            const word: u32 = @truncate(coords >> 32);
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
    return DefWindowProcA(hwnd, @intFromEnum(msg), wparam, lparam);
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
        0x10 => if (MapVirtualKeyA(@truncate((@as(u64, @bitCast(param)) & 0xff0000) >> 16), 3) == 0xa1) .right_shift else .left_shift,
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

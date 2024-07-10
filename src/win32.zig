pub const MessageId = enum(u32) {
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

pub const WindowClass = extern struct {
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

pub const Message = extern struct {
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

pub const Rect = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const MonitorInfo = extern struct {
    size: u32,
    monitor: Rect,
    work: Rect,
    flags: u32,
};

pub extern fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.C) *anyopaque;
pub extern fn RegisterClassExA(window_class: *const WindowClass) callconv(.C) u16;
pub extern fn LoadCursorA(instance: ?*anyopaque, cursor: usize) callconv(.C) ?*anyopaque;
pub extern fn PeekMessageA(msg: *Message, hwnd: ?*anyopaque, filter_min: u32, filter_max: u32, remove_msg: u32) callconv(.C) c_int;
pub extern fn TranslateMessage(msg: *const Message) callconv(.C) c_int;
pub extern fn DispatchMessageW(msg: *const Message) callconv(.C) *anyopaque;
pub extern fn DefWindowProcA(hwnd: ?*anyopaque, msg: u32, wparam: u64, lparam: i64) callconv(.C) usize;
pub extern fn GetWindowLongPtrA(hwnd: ?*anyopaque, index: c_int) callconv(.C) ?*anyopaque;
pub extern fn MapVirtualKeyA(code: u32, map_type: u32) callconv(.C) u32;
pub extern fn EnumDisplayMonitors(hdisplay: ?*anyopaque, rect: ?*Rect, proc: *const fn (*anyopaque, ?*anyopaque, ?*Rect, *anyopaque) callconv(.C) c_int, *anyopaque) callconv(.C) c_int;
pub extern fn GetMonitorInfoA(monitor: *anyopaque, monitor_info: *MonitorInfo) callconv(.C) c_int;
pub extern fn CreateWindowExA(ex_style: u32, class_name: ?[*:0]const u8, window_name: ?[*:0]const u8, style: u32, x: c_int, y: c_int, width: c_int, height: c_int, parent: ?*anyopaque, menu: ?*anyopaque, instance: ?*anyopaque, lp_param: ?*anyopaque) callconv(.C) ?*anyopaque;
pub extern fn DestroyWindow(hwnd: *anyopaque) callconv(.C) void;
pub extern fn AdjustWindowRectEx(rect: *Rect, style: u32, menu: c_int, ex_style: u32) callconv(.C) c_int;
pub extern fn SetWindowLongPtrA(hwnd: *anyopaque, index: c_int, ptr: *anyopaque) callconv(.C) ?*anyopaque;
pub extern fn SetLastError(code: u32) callconv(.C) void;
pub extern fn GetLastError() callconv(.C) u32;

pub const WS_CAPTION: u32 = 0x00C00000;
pub const WS_MAXIMIZEBOX: u32 = 0x00010000;
pub const WS_MINIMIZEBOX: u32 = 0x00020000;
pub const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_SYSMENU: u32 = 0x00080000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_VISIBLE: u32 = 0x10000000;

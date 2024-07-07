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

const XcbWindow = @import("XcbWindow.zig");

pub const Connection = opaque {};

pub const Screen = extern struct {
    root: u32,
    default_colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: u32,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

pub const ScreenIterator = extern struct {
    data: *Screen,
    rem: c_int,
    index: c_int,
};

pub const Setup = extern struct {
    status: u8,
    pad0: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: u8,
    max_keycode: u8,
    pad1: [4]u8,
};

pub const VoidCookie = extern struct {
    sequence: c_uint,
};

pub const InternAtomCookie = extern struct {
    sequence: c_uint,
};

pub const InternAtomReply = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    length: u32,
    atom: u32,
};

pub const GenericError = extern struct {
    response_type: u8,
    error_code: u8,
    sequence: u16,
    resource_id: u32,
    minor_code: u16,
    major_code: u8,
    pad0: u8,
    pad: [5]u32,
    full_sequence: u32,
};

pub const GenericEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    pad: [7]u32,
    full_sequence: u32,
};

pub const FocusEvent = extern struct {
    response_type: u8,
    detail: u8,
    sequence: u16,
    window: u32,
    mode: u8,
    pad0: [3]u8,
};

pub const ClientMessageEvent = extern struct {
    response_type: u8,
    format: u8,
    sequence: u16,
    window: u32,
    type: u32,
    data: extern union {
        data8: [20]u8,
        data16: [10]u16,
        data32: [5]u32,
    },
};

pub const ConfigureNotifyEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    event: u32,
    window: u32,
    above_sibling: u32,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: u8,
    pad1: u8,
};

pub const KeyEvent = extern struct {
    response_type: u8,
    detail: u8,
    sequence: u16,
    time: u32,
    root: u32,
    window: u32,
    child: u32,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};

pub const ButtonEvent = extern struct {
    response_type: u8,
    detail: u8,
    sequence: u16,
    time: u32,
    root: u32,
    window: u32,
    child: u32,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};

pub const MotionNotifyEvent = extern struct {
    response_type: u8,
    detail: u8,
    sequence: u16,
    time: u32,
    root: u32,
    window: u32,
    child: u32,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};

const Self = @This();

const KEY_PRESS: c_int = 2;
const KEY_RELEASE: c_int = 3;
const BUTTON_PRESS: c_int = 4;
const BUTTON_RELEASE: c_int = 5;
const MOTION_NOTIFY: c_int = 6;
const FOCUS_IN: c_int = 9;
const FOCUS_OUT: c_int = 10;
const CLIENT_MESSAGE: c_int = 33;
const CONFIGURE_NOTIFY: c_int = 22;

connect_fn: *const fn (displayname: ?[*:0]const u8, screenp: ?[*:0]c_int) callconv(.C) ?*Connection,
disconnect_fn: *const fn (connection: *Connection) callconv(.C) void,
connection_has_error_fn: *const fn (connection: *Connection) callconv(.C) c_int,

get_setup_fn: *const fn (connection: *Connection) callconv(.C) *const Setup,
setup_roots_iterator_fn: *const fn (root: *const Setup) callconv(.C) ScreenIterator,

generate_id_fn: *const fn (connection: *Connection) callconv(.C) u32,

create_window_fn: *const fn (
    connection: *Connection,
    depth: u8,
    wid: u32,
    parent: u32,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    _class: u16,
    visual: u32,
    value_mask: u32,
    value_list: ?*const anyopaque,
) callconv(.C) VoidCookie,
destroy_window_fn: *const fn (connection: *Connection, window: u32) callconv(.C) VoidCookie,

map_window_fn: *const fn (connection: *Connection, window: u32) callconv(.C) VoidCookie,
unmap_window_fn: *const fn (connection: *Connection, window: u32) callconv(.C) VoidCookie,

poll_for_event_fn: *const fn (connection: *Connection) callconv(.C) ?*GenericEvent,

intern_atom_fn: *const fn (
    connection: *Connection,
    only_if_exists: u8,
    name_len: u16,
    name: [*:0]const u8,
) callconv(.C) InternAtomCookie,

intern_atom_reply_fn: *const fn (
    connection: *Connection,
    cookie: InternAtomCookie,
    e: ?*GenericError,
) callconv(.C) *InternAtomReply,

change_property_fn: *const fn (
    connection: *Connection,
    mode: u8,
    window: u32,
    property: u32,
    @"type": u32,
    format: u8,
    data_len: u32,
    data: ?*const anyopaque,
) callconv(.C) VoidCookie,

flush_fn: *const fn (connection: *Connection) callconv(.C) c_int,

allocator: std.mem.Allocator,

windows: std.AutoHashMapUnmanaged(u32, *XcbWindow),

connection: *Connection,

pub fn init(
    handle: *anyopaque,
    allocator: std.mem.Allocator,
) !Context {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.connect_fn = @ptrCast(std.c.dlsym(handle, "xcb_connect") orelse return error.FailedToLoadFunction);
    self.disconnect_fn = @ptrCast(std.c.dlsym(handle, "xcb_disconnect") orelse return error.FailedToLoadFunction);
    self.connection_has_error_fn = @ptrCast(std.c.dlsym(handle, "xcb_connection_has_error") orelse return error.FailedToLoadFunction);

    self.get_setup_fn = @ptrCast(std.c.dlsym(handle, "xcb_get_setup") orelse return error.FailedToLoadFunction);
    self.setup_roots_iterator_fn = @ptrCast(std.c.dlsym(handle, "xcb_setup_roots_iterator") orelse return error.FailedToLoadFunction);

    self.generate_id_fn = @ptrCast(std.c.dlsym(handle, "xcb_generate_id") orelse return error.FailedToLoadFunction);

    self.create_window_fn = @ptrCast(std.c.dlsym(handle, "xcb_create_window") orelse return error.FailedToLoadFunction);
    self.destroy_window_fn = @ptrCast(std.c.dlsym(handle, "xcb_destroy_window") orelse return error.FailedToLoadFunction);

    self.map_window_fn = @ptrCast(std.c.dlsym(handle, "xcb_map_window") orelse return error.FailedToLoadFunction);
    self.unmap_window_fn = @ptrCast(std.c.dlsym(handle, "xcb_unmap_window") orelse return error.FailedToLoadFunction);

    self.poll_for_event_fn = @ptrCast(std.c.dlsym(handle, "xcb_poll_for_event") orelse return error.FailedToLoadFunction);

    self.intern_atom_fn = @ptrCast(std.c.dlsym(handle, "xcb_intern_atom") orelse return error.FailedToLoadFunction);
    self.intern_atom_reply_fn = @ptrCast(std.c.dlsym(handle, "xcb_intern_atom_reply") orelse return error.FailedToLoadFunction);

    self.change_property_fn = @ptrCast(std.c.dlsym(handle, "xcb_change_property") orelse return error.FailedToLoadFunction);

    self.flush_fn = @ptrCast(std.c.dlsym(handle, "xcb_flush") orelse return error.FailedToLoadFunction);

    self.allocator = allocator;

    self.connection = self.connect_fn(null, null) orelse return error.FailedToInitialize;
    errdefer self.disconnect_fn(self.connection);

    if (self.connection_has_error_fn(self.connection) != 0) return error.FailedToInitialize;

    self.windows = .{};

    return .{
        .handle = @ptrCast(self),
        .deinit_fn = @ptrCast(&deinit),
        .poll_events_fn = @ptrCast(&pollEvents),
        .create_window_fn = @ptrCast(&createWindow),
    };
}

pub fn deinit(self: *Self) void {
    self.disconnect_fn(self.connection);
    self.windows.deinit(self.allocator);
    self.allocator.destroy(self);
}

pub fn createWindow(
    self: *Self,
    config: Window.Config,
) Error!Window {
    const window = try XcbWindow.create(
        self,
        config,
        self.allocator,
    );

    try self.windows.put(
        self.allocator,
        window.window,
        window,
    );

    return .{
        .handle = @ptrCast(window),
        .is_open_fn = @ptrCast(&XcbWindow.isOpen),
        .destroy_fn = @ptrCast(&XcbWindow.destroy),
    };
}

pub fn pollEvents(self: *Self) void {
    var maybe_current = self.poll_for_event_fn(self.connection);

    while (maybe_current) |current| {
        const maybe_next = self.poll_for_event_fn(self.connection);
        self.proccessEvent(
            current,
            maybe_next,
        );
        std.c.free(current);
        maybe_current = maybe_next;
    }
}

fn proccessEvent(
    self: *Self,
    current: *GenericEvent,
    next: ?*GenericEvent,
) void {
    switch (@as(i16, @intCast(current.*.response_type)) & (-0x80 - 1)) {
        CLIENT_MESSAGE => {
            const client_event: *ClientMessageEvent = @ptrCast(current);
            if (self.windows.get(client_event.*.window)) |window| {
                if (client_event.*.data.data32[0] == window.delete_window_atom) {
                    window.is_open = false;
                    window.event_handler.handleEvent(.Destroy);
                }
            }
        },
        CONFIGURE_NOTIFY => {
            const config_event: *ConfigureNotifyEvent = @ptrCast(current);
            if (self.windows.get(config_event.*.window)) |window| {
                if (config_event.width != window.width or config_event.height != window.height) {
                    window.width = config_event.width;
                    window.height = config_event.height;
                    window.event_handler.handleEvent(.{ .Resize = Rect{
                        .width = window.width,
                        .height = window.height,
                    } });
                }
            }
        },
        FOCUS_IN => {
            const focus_event: *FocusEvent = @ptrCast(current);
            if (self.windows.get(focus_event.*.window)) |window| window.event_handler.handleEvent(.FocusIn);
        },
        FOCUS_OUT => {
            const focus_event: *FocusEvent = @ptrCast(current);
            if (self.windows.get(focus_event.*.window)) |window| window.event_handler.handleEvent(.FocusOut);
        },
        KEY_PRESS => {
            const key_event: *KeyEvent = @ptrCast(current);
            if (self.windows.get(key_event.window)) |window| blk: {
                if (window.last_key_time >= key_event.time) {
                    window.last_key_time = key_event.time;
                    break :blk;
                }
                window.last_key_time = key_event.time;
                window.event_handler.handleEvent(.{
                    .KeyPress = keycodeToEnum(key_event.detail),
                });
            }
        },
        KEY_RELEASE => {
            const key_event: *KeyEvent = @ptrCast(current);
            if (self.windows.get(key_event.*.window)) |window| blk: {
                const maybe_next_event: ?*KeyEvent = @ptrCast(next);
                if (maybe_next_event) |next_event| {
                    if (((@as(i16, @intCast(next_event.response_type)) & (-0x80 - 1)) == KEY_PRESS) and
                        (next_event.time - key_event.time) < 20 and
                        next_event.detail == key_event.detail and
                        next_event.window == key_event.window)
                    {
                        window.last_key_time = key_event.time;
                        break :blk;
                    }
                }
                window.last_key_time = key_event.time;
                window.event_handler.handleEvent(.{
                    .KeyRelease = keycodeToEnum(key_event.detail),
                });
            }
        },
        BUTTON_PRESS => {
            const button_event: *ButtonEvent = @ptrCast(current);
            if (self.windows.get(button_event.*.window)) |window| {
                window.event_handler.handleEvent(switch (button_event.detail) {
                    4 => .{ .MouseScrollV = 1 },
                    5 => .{ .MouseScrollV = -1 },
                    6 => .{ .MouseScrollH = 1 },
                    7 => .{ .MouseScrollH = -1 },
                    else => .{ .MousePress = mousecodeToEnum(button_event.detail) },
                });
            }
        },
        BUTTON_RELEASE => {
            const button_event: *ButtonEvent = @ptrCast(current);
            if (self.windows.get(button_event.*.window)) |window| {
                if (button_event.detail != 4 and button_event.detail != 5) {
                    window.event_handler.handleEvent(.{
                        .MouseRelease = mousecodeToEnum(button_event.detail),
                    });
                }
            }
        },
        MOTION_NOTIFY => {
            const motion_event: *MotionNotifyEvent = @ptrCast(current);
            if (self.windows.get(motion_event.*.window)) |window| {
                window.event_handler.handleEvent(.{
                    .MouseMove = Point{
                        .x = motion_event.event_x,
                        .y = motion_event.event_y,
                    },
                });
            }
        },
        else => {},
    }
}

fn keycodeToEnum(code: u8) Key {
    switch (code) {
        19 => return Key.Zero,
        10 => return Key.One,
        11 => return Key.Two,
        12 => return Key.Three,
        13 => return Key.Four,
        14 => return Key.Five,
        15 => return Key.Six,
        16 => return Key.Seven,
        17 => return Key.Eight,
        18 => return Key.Nine,
        90 => return Key.Numpad0,
        87 => return Key.Numpad1,
        88 => return Key.Numpad2,
        89 => return Key.Numpad3,
        83 => return Key.Numpad4,
        84 => return Key.Numpad5,
        85 => return Key.Numpad6,
        79 => return Key.Numpad7,
        80 => return Key.Numpad8,
        81 => return Key.Numpad9,
        91 => return Key.NumpadDecimal,
        86 => return Key.NumpadAdd,
        82 => return Key.NumpadSubtract,
        63 => return Key.NumpadMultiply,
        106 => return Key.NumpadDivide,
        77 => return Key.NumpadLock,
        104 => return Key.NumpadEnter,
        38 => return Key.A,
        56 => return Key.B,
        54 => return Key.C,
        40 => return Key.D,
        26 => return Key.E,
        41 => return Key.F,
        42 => return Key.G,
        43 => return Key.H,
        31 => return Key.I,
        44 => return Key.J,
        45 => return Key.K,
        46 => return Key.L,
        58 => return Key.M,
        57 => return Key.N,
        32 => return Key.O,
        33 => return Key.P,
        24 => return Key.Q,
        27 => return Key.R,
        39 => return Key.S,
        28 => return Key.T,
        30 => return Key.U,
        55 => return Key.V,
        25 => return Key.W,
        53 => return Key.X,
        29 => return Key.Y,
        52 => return Key.Z,
        111 => return Key.Up,
        116 => return Key.Down,
        114 => return Key.Right,
        113 => return Key.Left,
        60 => return Key.Period,
        59 => return Key.Comma,
        50 => return Key.LeftShift,
        62 => return Key.RightShift,
        37 => return Key.LeftCtrl,
        105 => return Key.RightCtrl,
        64 => return Key.LeftAlt,
        108 => return Key.RightAlt,
        118 => return Key.Insert,
        119 => return Key.Delete,
        110 => return Key.Home,
        115 => return Key.End,
        112 => return Key.PageUp,
        117 => return Key.PageDown,
        107 => return Key.PrintScreen,
        78 => return Key.ScrollLock,
        127 => return Key.Pause,
        9 => return Key.Escape,
        23 => return Key.Tab,
        66 => return Key.CapsLock,
        133 => return Key.LeftSuper,
        65 => return Key.Space,
        22 => return Key.Backspace,
        36 => return Key.Enter,
        135 => return Key.Menu,
        61 => return Key.Slash,
        51 => return Key.Backslash,
        20 => return Key.Minus,
        21 => return Key.Equal,
        48 => return Key.Apostrophe,
        47 => return Key.Semicolon,
        34 => return Key.LeftBracket,
        35 => return Key.RightBracket,
        49 => return Key.Tilde,
        67 => return Key.F1,
        68 => return Key.F2,
        69 => return Key.F3,
        70 => return Key.F4,
        71 => return Key.F5,
        72 => return Key.F6,
        73 => return Key.F7,
        74 => return Key.F8,
        75 => return Key.F9,
        76 => return Key.F10,
        95 => return Key.F11,
        96 => return Key.F12,
        94 => return Key.OEM1,
        else => return Key.NONE,
    }
}

fn mousecodeToEnum(code: u8) Mouse {
    switch (code) {
        1 => return Mouse.Left,
        2 => return Mouse.Middle,
        3 => return Mouse.Right,
        8 => return Mouse.One,
        9 => return Mouse.Two,
        else => return Mouse.NONE,
    }
}

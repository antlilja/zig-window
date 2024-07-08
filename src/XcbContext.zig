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

const required_vulkan_extensions = [_][*:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_xcb_surface",
};

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
        .required_vulkan_instance_extensions_fn = @ptrCast(&requiredVulkanInstanceExtensions),
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
        .get_size_fn = @ptrCast(&XcbWindow.getSize),
        .create_vulkan_surface_fn = @ptrCast(&XcbWindow.createVulkanSurface),
    };
}

pub fn requiredVulkanInstanceExtensions(_: *const Self) []const [*:0]const u8 {
    return &required_vulkan_extensions;
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
                        .x = @intCast(motion_event.event_x),
                        .y = @intCast(motion_event.event_y),
                    },
                });
            }
        },
        else => {},
    }
}

fn keycodeToEnum(code: u8) Key {
    return switch (code) {
        19 => Key.zero,
        10 => Key.one,
        11 => Key.two,
        12 => Key.three,
        13 => Key.four,
        14 => Key.five,
        15 => Key.six,
        16 => Key.seven,
        17 => Key.eight,
        18 => Key.nine,
        90 => Key.numpad_0,
        87 => Key.numpad_1,
        88 => Key.numpad_2,
        89 => Key.numpad_3,
        83 => Key.numpad_4,
        84 => Key.numpad_5,
        85 => Key.numpad_6,
        79 => Key.numpad_7,
        80 => Key.numpad_8,
        81 => Key.numpad_9,
        91 => Key.numpad_decimal,
        86 => Key.numpad_add,
        82 => Key.numpad_subtract,
        63 => Key.numpad_multiply,
        106 => Key.numpad_divide,
        77 => Key.numpad_lock,
        104 => Key.numpad_enter,
        38 => Key.a,
        56 => Key.b,
        54 => Key.c,
        40 => Key.d,
        26 => Key.e,
        41 => Key.f,
        42 => Key.g,
        43 => Key.h,
        31 => Key.i,
        44 => Key.j,
        45 => Key.k,
        46 => Key.l,
        58 => Key.m,
        57 => Key.n,
        32 => Key.o,
        33 => Key.p,
        24 => Key.q,
        27 => Key.r,
        39 => Key.s,
        28 => Key.t,
        30 => Key.u,
        55 => Key.v,
        25 => Key.w,
        53 => Key.x,
        29 => Key.y,
        52 => Key.z,
        111 => Key.up,
        116 => Key.down,
        114 => Key.right,
        113 => Key.left,
        60 => Key.period,
        59 => Key.comma,
        50 => Key.left_shift,
        62 => Key.right_shift,
        37 => Key.left_ctrl,
        105 => Key.right_ctrl,
        64 => Key.left_alt,
        108 => Key.right_alt,
        118 => Key.insert,
        119 => Key.delete,
        110 => Key.home,
        115 => Key.end,
        112 => Key.page_up,
        117 => Key.page_down,
        107 => Key.print_screen,
        78 => Key.scroll_lock,
        127 => Key.pause,
        9 => Key.escape,
        23 => Key.tab,
        66 => Key.caps_lock,
        133 => Key.left_super,
        65 => Key.space,
        22 => Key.backspace,
        36 => Key.enter,
        135 => Key.menu,
        61 => Key.slash,
        51 => Key.back_slash,
        20 => Key.minus,
        21 => Key.equal,
        48 => Key.apostrophe,
        47 => Key.semicolon,
        34 => Key.left_bracket,
        35 => Key.right_bracket,
        49 => Key.tilde,
        67 => Key.f1,
        68 => Key.f2,
        69 => Key.f3,
        70 => Key.f4,
        71 => Key.f5,
        72 => Key.f6,
        73 => Key.f7,
        74 => Key.f8,
        75 => Key.f9,
        76 => Key.f10,
        95 => Key.f11,
        96 => Key.f12,
        94 => Key.oem_1,
        else => Key.none,
    };
}

fn mousecodeToEnum(code: u8) Mouse {
    return switch (code) {
        1 => Mouse.left,
        2 => Mouse.middle,
        3 => Mouse.right,
        8 => Mouse.one,
        9 => Mouse.two,
        else => Mouse.none,
    };
}

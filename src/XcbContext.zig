const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
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

const ResponseType = enum(i16) {
    key_press = 2,
    key_release = 3,
    button_press = 4,
    button_release = 5,
    motion_notify = 6,
    focus_in = 9,
    focus_out = 10,
    configure_notify = 22,
    client_message = 33,
    _,
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
        .create_window_fn = @ptrCast(&createWindow),
        .poll_events_fn = @ptrCast(&pollEvents),
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
) Context.CreateWindowError!Window {
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
    switch (enumFromResponseType(current.response_type)) {
        .client_message => {
            const client_event: *ClientMessageEvent = @ptrCast(current);
            if (self.windows.get(client_event.window)) |window| {
                if (client_event.*.data.data32[0] == window.delete_window_atom) {
                    window.is_open = false;
                    window.event_handler.handleEvent(.Destroy);
                }
            }
        },
        .configure_notify => {
            const config_event: *ConfigureNotifyEvent = @ptrCast(current);
            if (self.windows.get(config_event.window)) |window| {
                if (config_event.width != window.width or config_event.height != window.height) {
                    window.width = config_event.width;
                    window.height = config_event.height;
                    window.event_handler.handleEvent(.{ .Resize = .{
                        window.width,
                        window.height,
                    } });
                }
            }
        },
        .focus_in => {
            const focus_event: *FocusEvent = @ptrCast(current);
            if (self.windows.get(focus_event.window)) |window| window.event_handler.handleEvent(.FocusIn);
        },
        .focus_out => {
            const focus_event: *FocusEvent = @ptrCast(current);
            if (self.windows.get(focus_event.window)) |window| window.event_handler.handleEvent(.FocusOut);
        },
        .key_press => {
            const key_event: *KeyEvent = @ptrCast(current);
            if (self.windows.get(key_event.window)) |window| blk: {
                if (window.last_key_time >= key_event.time) {
                    window.last_key_time = key_event.time;
                    break :blk;
                }
                window.last_key_time = key_event.time;
                window.event_handler.handleEvent(.{
                    .KeyPress = enumFromKeycode(key_event.detail),
                });
            }
        },
        .key_release => {
            const key_event: *KeyEvent = @ptrCast(current);
            if (self.windows.get(key_event.window)) |window| blk: {
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
                    .KeyRelease = enumFromKeycode(key_event.detail),
                });
            }
        },
        .button_press => {
            const button_event: *ButtonEvent = @ptrCast(current);
            if (self.windows.get(button_event.window)) |window| {
                window.event_handler.handleEvent(switch (button_event.detail) {
                    4 => .{ .MouseScrollV = 1 },
                    5 => .{ .MouseScrollV = -1 },
                    6 => .{ .MouseScrollH = 1 },
                    7 => .{ .MouseScrollH = -1 },
                    else => .{ .MousePress = enumFromMousecode(button_event.detail) },
                });
            }
        },
        .button_release => {
            const button_event: *ButtonEvent = @ptrCast(current);
            if (self.windows.get(button_event.window)) |window| {
                if (button_event.detail != 4 and button_event.detail != 5) {
                    window.event_handler.handleEvent(.{
                        .MouseRelease = enumFromMousecode(button_event.detail),
                    });
                }
            }
        },
        .motion_notify => {
            const motion_event: *MotionNotifyEvent = @ptrCast(current);
            if (self.windows.get(motion_event.window)) |window| {
                window.event_handler.handleEvent(.{
                    .MouseMove = .{
                        @intCast(motion_event.event_x),
                        @intCast(motion_event.event_y),
                    },
                });
            }
        },
        else => {},
    }
}

fn enumFromResponseType(ty: u8) ResponseType {
    return @enumFromInt(@as(i16, @intCast(ty)) & (-0x80 - 1));
}

fn enumFromKeycode(code: u8) EventHandler.Key {
    return switch (code) {
        19 => .zero,
        10 => .one,
        11 => .two,
        12 => .three,
        13 => .four,
        14 => .five,
        15 => .six,
        16 => .seven,
        17 => .eight,
        18 => .nine,
        90 => .numpad_0,
        87 => .numpad_1,
        88 => .numpad_2,
        89 => .numpad_3,
        83 => .numpad_4,
        84 => .numpad_5,
        85 => .numpad_6,
        79 => .numpad_7,
        80 => .numpad_8,
        81 => .numpad_9,
        91 => .numpad_decimal,
        86 => .numpad_add,
        82 => .numpad_subtract,
        63 => .numpad_multiply,
        106 => .numpad_divide,
        77 => .numpad_lock,
        104 => .numpad_enter,
        38 => .a,
        56 => .b,
        54 => .c,
        40 => .d,
        26 => .e,
        41 => .f,
        42 => .g,
        43 => .h,
        31 => .i,
        44 => .j,
        45 => .k,
        46 => .l,
        58 => .m,
        57 => .n,
        32 => .o,
        33 => .p,
        24 => .q,
        27 => .r,
        39 => .s,
        28 => .t,
        30 => .u,
        55 => .v,
        25 => .w,
        53 => .x,
        29 => .y,
        52 => .z,
        111 => .up,
        116 => .down,
        114 => .right,
        113 => .left,
        60 => .period,
        59 => .comma,
        50 => .left_shift,
        62 => .right_shift,
        37 => .left_ctrl,
        105 => .right_ctrl,
        64 => .left_alt,
        108 => .right_alt,
        118 => .insert,
        119 => .delete,
        110 => .home,
        115 => .end,
        112 => .page_up,
        117 => .page_down,
        107 => .print_screen,
        78 => .scroll_lock,
        127 => .pause,
        9 => .escape,
        23 => .tab,
        66 => .caps_lock,
        133 => .left_super,
        65 => .space,
        22 => .backspace,
        36 => .enter,
        135 => .menu,
        61 => .slash,
        51 => .back_slash,
        20 => .minus,
        21 => .equal,
        48 => .apostrophe,
        47 => .semicolon,
        34 => .left_bracket,
        35 => .right_bracket,
        49 => .tilde,
        67 => .f1,
        68 => .f2,
        69 => .f3,
        70 => .f4,
        71 => .f5,
        72 => .f6,
        73 => .f7,
        74 => .f8,
        75 => .f9,
        76 => .f10,
        95 => .f11,
        96 => .f12,
        94 => .oem_1,
        else => .none,
    };
}

fn enumFromMousecode(code: u8) EventHandler.Mouse {
    return switch (code) {
        1 => .left,
        2 => .middle,
        3 => .right,
        8 => .one,
        9 => .two,
        else => .none,
    };
}

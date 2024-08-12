const std = @import("std");

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
    data: *const Screen,
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

pub const ResponseType = enum(i16) {
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

pub const EventMask = packed struct(u32) {
    key_press: bool = false,
    key_release: bool = false,
    button_press: bool = false,
    button_release: bool = false,
    enter_window: bool = false,
    leave_window: bool = false,
    pointer_motion: bool = false,
    reserved: u8 = 0,
    exposure: bool = false,
    visibility_change: bool = false,
    structure_notify: bool = false,
    reserved2: u3 = 0,
    focus_change: bool = false,
    reserved3: u10 = 0,
};

pub const WindowValueMask = packed struct(u32) {
    reserved: u1 = 0,
    back_pixel: bool = false,
    reserved2: u9 = 0,
    event_mask: bool = false,
    reserved3: u20 = 0,
};

pub const SizeHints = extern struct {
    flags: u32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    width_inc: i32,
    height_inc: i32,
    min_aspect_num: i32,
    min_aspect_den: i32,
    max_aspect_num: i32,
    max_aspect_den: i32,
    base_width: i32,
    base_height: i32,
    win_gravity: u32,
};

pub const Library = struct {
    handle: std.DynLib,

    connect: *const fn (displayname: ?[*:0]const u8, screenp: ?[*:0]c_int) callconv(.C) ?*Connection,
    disconnect: *const fn (connection: *Connection) callconv(.C) void,
    connection_has_error: *const fn (connection: *Connection) callconv(.C) c_int,

    get_setup: *const fn (connection: *Connection) callconv(.C) *const Setup,
    setup_roots_iterator: *const fn (root: *const Setup) callconv(.C) ScreenIterator,

    generate_id: *const fn (connection: *Connection) callconv(.C) u32,

    create_window: *const fn (
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
        value_mask: WindowValueMask,
        value_list: ?[*]const u32,
    ) callconv(.C) u32,
    destroy_window: *const fn (connection: *Connection, window: u32) callconv(.C) u32,

    map_window: *const fn (connection: *Connection, window: u32) callconv(.C) u32,
    unmap_window: *const fn (connection: *Connection, window: u32) callconv(.C) u32,

    poll_for_event: *const fn (connection: *Connection) callconv(.C) ?*GenericEvent,

    intern_atom: *const fn (
        connection: *Connection,
        only_if_exists: u8,
        name_len: u16,
        name: [*:0]const u8,
    ) callconv(.C) u32,
    intern_atom_reply: *const fn (
        connection: *Connection,
        cookie: u32,
        e: ?*GenericError,
    ) callconv(.C) *InternAtomReply,

    change_property: *const fn (
        connection: *Connection,
        mode: u8,
        window: u32,
        property: u32,
        @"type": u32,
        format: u8,
        data_len: u32,
        data: ?*const anyopaque,
    ) callconv(.C) u32,

    flush: *const fn (connection: *Connection) callconv(.C) c_int,

    pub fn deinit(self: *Library) void {
        self.handle.close();
    }
};

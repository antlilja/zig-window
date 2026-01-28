const std = @import("std");

const xcb = @import("base.zig");

pub const UseExtensionReply = extern struct {
    response_type: u8,
    supported: u8,
    sequence: u16,
    length: u32,
    server_major: u16,
    server_minor: u16,
    pad0: [20]u8,
};

pub const GetDeviceInfoReply = extern struct {
    response_type: u8,
    device_id: u8,
    sequence: u16,
    length: u32,
    present: u16,
    supported: u16,
    unsupported: u16,
    n_device_led_fbs: u16,
    first_btn_wanted: u8,
    n_btns_wanted: u8,
    first_btn_rtrn: u8,
    n_btns_rtrn: u8,
    total_btns: u8,
    has_own_state: u8,
    dflt_kbd_fb: u16,
    dflt_led_fb: u16,
    pad0: [2]u8,
    dev_type: u32,
    name_len: u16,
};

pub const ClientFlagsReply = extern struct {
    response_type: u8,
    device_id: u8,
    sequence: u16,
    length: u32,
    supported: u32,
    value: u32,
    auto_ctrls: u32,
    auto_ctrls_values: u32,
    pad0: [8]u8,
};
pub const Library = struct {
    handle: std.DynLib,

    use_extension: *const fn (
        connection: *xcb.Connection,
        wanted_major: u16,
        wanted_minor: u16,
    ) callconv(.c) u32,

    use_extension_reply: *const fn (
        connection: *xcb.Connection,
        cookie: u32,
        e: ?**xcb.GenericError,
    ) callconv(.c) ?*UseExtensionReply,

    get_device_info: *const fn (
        connection: *xcb.Connection,
        device_spec: u16,
        wanted: u16,
        all_buttons: u8,
        first_button: u8,
        n_buttons: u8,
        led_class: u16,
        led_id: u16,
    ) callconv(.c) u32,

    get_device_info_reply: *const fn (
        connection: *xcb.Connection,
        cookie: u32,
        e: ?**xcb.GenericError,
    ) callconv(.c) ?*GetDeviceInfoReply,

    per_client_flags: *const fn (
        connection: *xcb.Connection,
        device_spec: u16,
        change: u32,
        value: u32,
        ctrls_to_change: u32,
        auto_ctrls: u32,
        auto_ctrls_values: u32,
    ) callconv(.c) u32,

    per_client_flags_reply: *const fn (
        connection: *xcb.Connection,
        cookie: u32,
        e: ?**xcb.GenericError,
    ) callconv(.c) ?*ClientFlagsReply,

    pub fn deinit(self: *Library) void {
        self.handle.close();
    }
};

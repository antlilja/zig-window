const std = @import("std");

const xcb = @import("base.zig");

pub const GetMonitorsReply = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    length: u32,
    timestamp: u32,
    num_monitors: u32,
    num_outputs: u32,
    pad1: [12]u8,
};

pub const MonitorInfoIterator = extern struct {
    data: *MonitorInfo,
    rem: c_int,
    index: c_int,
};

pub const MonitorInfo = extern struct {
    name: u32,
    primary: u8,
    automatic: u8,
    num_output: u16,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    width_in_millimeters: u32,
    height_in_millimeters: u32,
};

pub const Library = struct {
    handle: std.DynLib,

    get_monitors: *const fn (connection: *xcb.Connection, window: u32, get_active: u8) callconv(.C) u32,
    get_monitors_reply: *const fn (
        connection: *xcb.Connection,
        cookie: u32,
        ?*?*xcb.GenericError,
    ) callconv(.C) *const GetMonitorsReply,
    get_monitors_monitors_iterator: *const fn (*const GetMonitorsReply) callconv(.C) MonitorInfoIterator,
    monitor_info_next: *const fn (*MonitorInfoIterator) callconv(.C) void,

    pub fn deinit(self: *Library) void {
        self.handle.close();
    }
};

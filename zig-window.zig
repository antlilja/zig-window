const std = @import("std");
const base = @import("src/base.zig");
const xcb = @import("src/xcb.zig");

pub const Event = base.Event;
pub const Rect = base.Rect;
pub const Point = base.Point;
pub const Cursor = base.Cursor;
pub const Error = base.Error;

pub const Window = switch (@import("builtin").target.os.tag) {
    .linux => xcb.Window,
    else => unreachable,
};

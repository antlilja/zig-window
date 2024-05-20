const std = @import("std");

const base = @import("base.zig");
const xcb = @import("xcb.zig");

pub const Key = base.Key;
pub const Mouse = base.Mouse;
pub const Event = base.Event;
pub const Rect = base.Rect;
pub const Point = base.Point;
pub const Cursor = base.Cursor;
pub const Error = base.Error;

pub const Window = switch (@import("builtin").target.os.tag) {
    .linux => xcb.Window,
    else => unreachable,
};

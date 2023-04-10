const std = @import("std");

const base = @import("base.zig");
// const xcb = @import("xcb.zig");
const wayland = @import("wayland.zig");

pub const Key = base.Key;
pub const Event = base.Event;
pub const Rect = base.Rect;
pub const Point = base.Point;
pub const Cursor = base.Cursor;
pub const Error = base.Error;

pub const Window = switch (@import("builtin").target.os.tag) {
    .linux => wayland.Window,
    else => unreachable,
};

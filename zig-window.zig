const std = @import("std");
const xcb = @import("src/xcb.zig");

pub usingnamespace switch (std.Target.current.os.tag) {
    .linux => xcb,
    else => unreachable,
};

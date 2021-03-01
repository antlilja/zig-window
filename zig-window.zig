const std = @import("std");
const target = switch (std.Target.current.os.tag) {
    .linux => "src/xcb.zig",
    else => unreachable,
};

pub usingnamespace @import(target);

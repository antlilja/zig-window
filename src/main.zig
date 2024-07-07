const std = @import("std");

pub usingnamespace @import("base.zig");
const XcbContext = @import("XcbContext.zig");

const Context = @import("Context.zig");

pub fn init(allocator: std.mem.Allocator) !Context {
    return switch (@import("builtin").target.os.tag) {
        .linux => try XcbContext.init(
            std.c.dlopen("libxcb.so.1", 2) orelse return error.FailedToLoadFunctions,
            allocator,
        ),
        else => @compileError("Unsupported OS"),
    };
}

const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const xcb = @import("xcb/base.zig");

const XcbContext = @import("XcbContext.zig");

const Self = @This();

const PROP_MODE_REPLACE: c_int = 0;

const ATOM_STRING: c_int = 31;
const ATOM_WM_NAME: c_int = 39;
const ATOM_WM_NORMAL_HINTS: c_int = 40;
const ATOM_WM_SIZE_HINTS: c_int = 41;

width: u32,
height: u32,
is_open: bool,

event_handler: EventHandler,

context: *XcbContext,
window: u32,
delete_window_atom: u32,

key_states: std.enums.EnumArray(EventHandler.Key, bool) = .initFill(false),

pub fn create(
    self: *Self,
    context: *XcbContext,
    config: Window.Config,
) Context.CreateWindowError!void {
    const setup = context.xcb_lib.get_setup(context.connection);
    const screen = context.xcb_lib.setup_roots_iterator(setup).data;

    const window = context.xcb_lib.generate_id(context.connection);
    _ = context.xcb_lib.create_window(
        context.connection,
        0, // Copy from parent
        window,
        screen.root,
        0,
        0,
        @intCast(config.width),
        @intCast(config.height),
        1,
        1, // Input output
        screen.root_visual,
        .{
            .back_pixel = true,
            .event_mask = true,
        },
        &.{
            screen.black_pixel,
            @bitCast(xcb.EventMask{
                .key_press = true,
                .key_release = true,
                .button_press = true,
                .button_release = true,
                .enter_window = true,
                .leave_window = true,
                .pointer_motion = true,
                .exposure = true,
                .visibility_change = true,
                .structure_notify = true,
                .focus_change = true,
            }),
        },
    );

    // Setup window destruction
    const delete_window_atom = blk: {
        const protocols_reply = context.xcb_lib.intern_atom_reply(
            context.connection,
            context.xcb_lib.intern_atom(
                context.connection,
                1,
                "WM_PROTOCOLS".len,
                "WM_PROTOCOLS",
            ),
            null,
        );
        defer std.c.free(protocols_reply);

        const delete_window_reply = context.xcb_lib.intern_atom_reply(
            context.connection,
            context.xcb_lib.intern_atom(
                context.connection,
                0,
                "WM_DELETE_WINDOW".len,
                "WM_DELETE_WINDOW",
            ),
            null,
        );
        defer std.c.free(delete_window_reply);

        _ = context.xcb_lib.change_property(
            context.connection,
            PROP_MODE_REPLACE,
            window,
            protocols_reply.*.atom,
            4,
            32,
            1,
            &delete_window_reply.atom,
        );

        break :blk delete_window_reply.atom;
    };

    // Set window name
    _ = context.xcb_lib.change_property(
        context.connection,
        PROP_MODE_REPLACE,
        window,
        ATOM_WM_NAME,
        ATOM_STRING,
        8,
        @intCast(config.name.len),
        &config.name[0],
    );

    if (!config.resizable) {
        const size_hints = xcb.SizeHints{
            .flags = (1 << 4) | (1 << 5),
            .min_width = @intCast(config.width),
            .max_width = @intCast(config.width),
            .min_height = @intCast(config.height),
            .max_height = @intCast(config.height),
            .x = undefined,
            .y = undefined,
            .width = undefined,
            .height = undefined,
            .width_inc = undefined,
            .height_inc = undefined,
            .min_aspect_num = undefined,
            .max_aspect_num = undefined,
            .min_aspect_den = undefined,
            .max_aspect_den = undefined,
            .base_width = undefined,
            .base_height = undefined,
            .win_gravity = undefined,
        };
        _ = context.xcb_lib.change_property(
            context.connection,
            PROP_MODE_REPLACE,
            window,
            ATOM_WM_NORMAL_HINTS,
            ATOM_WM_SIZE_HINTS,
            32,
            @sizeOf(xcb.SizeHints) >> 2,
            @ptrCast(&size_hints),
        );
    }

    _ = context.xcb_lib.map_window(context.connection, window);
    _ = context.xcb_lib.flush(context.connection);

    self.* = .{
        .is_open = true,
        .width = config.width,
        .height = config.height,

        .event_handler = config.event_handler,

        .context = context,

        .window = window,
        .delete_window_atom = delete_window_atom,
    };
}

pub fn destroy(self: *const Self) void {
    _ = self.context.xcb_lib.destroy_window(self.context.connection, self.window);
    self.context.destroyWindow(self);
}

pub fn isOpen(self: *const Self) bool {
    return self.is_open;
}

pub fn getSize(self: *const Self) struct { u32, u32 } {
    return .{ self.width, self.height };
}

pub fn createVulkanSurface(
    self: *const Self,
    instance: *const anyopaque,
    get_instance_proc_addr: *const Context.GetInstanceProcAddrFn,
    allocation_callbacks: ?*const anyopaque,
) Window.VulkanSurfaceError!*anyopaque {
    const CreateInfo = extern struct {
        s_type: c_int = 1000005000,
        p_next: ?*anyopaque = null,
        flags: c_int = 0,
        connection: *xcb.Connection,
        window: u32,
    };
    const create_surface: *const fn (
        *const anyopaque,
        *const CreateInfo,
        ?*const anyopaque,
        **anyopaque,
    ) callconv(.c) c_int = @ptrCast(get_instance_proc_addr(
        instance,
        "vkCreateXcbSurfaceKHR",
    ) orelse return error.FailedToLoadFunction);

    const create_info = CreateInfo{
        .connection = self.context.connection,
        .window = self.window,
    };

    var surface: *anyopaque = undefined;
    if (create_surface(
        instance,
        &create_info,
        allocation_callbacks,
        &surface,
    ) != 0) return error.FailedToCreateSurface;

    return surface;
}

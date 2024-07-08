const std = @import("std");

const Error = @import("base.zig").Error;

const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const XcbContext = @import("XcbContext.zig");

const SizeHints = extern struct {
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

const Self = @This();

const COPY_FROM_PARENT: c_int = 0;
const WINDOW_CLASS_INPUT_OUTPUT: c_int = 1;
const PROP_MODE_REPLACE: c_int = 0;

const ATOM_STRING: c_int = 31;
const ATOM_WM_NAME: c_int = 39;
const ATOM_WM_NORMAL_HINTS: c_int = 40;
const ATOM_WM_SIZE_HINTS: c_int = 41;

const CW_BACK_PIXEL: c_int = 2;
const CW_EVENT_MASK: c_int = 2048;

const EVENT_MASK_KEY_PRESS: c_int = 1;
const EVENT_MASK_KEY_RELEASE: c_int = 2;
const EVENT_MASK_BUTTON_PRESS: c_int = 4;
const EVENT_MASK_BUTTON_RELEASE: c_int = 8;
const EVENT_MASK_ENTER_WINDOW: c_int = 16;
const EVENT_MASK_LEAVE_WINDOW: c_int = 32;
const EVENT_MASK_POINTER_MOTION: c_int = 64;
const EVENT_MASK_EXPOSURE: c_int = 32768;
const EVENT_MASK_VISIBILITY_CHANGE: c_int = 65536;
const EVENT_MASK_STRUCTURE_NOTIFY: c_int = 131072;
const EVENT_MASK_FOCUS_CHANGE: c_int = 2097152;

width: u32,
height: u32,
is_open: bool,
resizable: bool,

event_handler: EventHandler,

context: *const XcbContext,
window: u32,
delete_window_atom: u32,

last_key_time: u32,

pub fn create(
    context: *const XcbContext,
    config: Window.Config,
    allocator: std.mem.Allocator,
) Error!*Self {
    const screen = context.setup_roots_iterator_fn(context.get_setup_fn(context.connection)).data;

    const mask = CW_BACK_PIXEL | CW_EVENT_MASK;
    const values = [2]u32{
        screen.black_pixel,

        @intCast(EVENT_MASK_EXPOSURE | EVENT_MASK_STRUCTURE_NOTIFY |
            EVENT_MASK_ENTER_WINDOW | EVENT_MASK_LEAVE_WINDOW |
            EVENT_MASK_KEY_PRESS | EVENT_MASK_KEY_RELEASE |
            EVENT_MASK_BUTTON_PRESS | EVENT_MASK_BUTTON_RELEASE |
            EVENT_MASK_POINTER_MOTION | EVENT_MASK_FOCUS_CHANGE),
    };

    const window = context.generate_id_fn(context.connection);
    _ = context.create_window_fn(
        context.connection,
        COPY_FROM_PARENT,
        window,
        screen.*.root,
        0,
        0,
        @intCast(config.width),
        @intCast(config.height),
        1,
        WINDOW_CLASS_INPUT_OUTPUT,
        screen.*.root_visual,
        mask,
        &values[0],
    );

    // Setup window destruction
    const protocols_reply = context.intern_atom_reply_fn(
        context.connection,
        context.intern_atom_fn(
            context.connection,
            1,
            "WM_PROTOCOLS".len,
            "WM_PROTOCOLS",
        ),
        null,
    );
    defer std.c.free(protocols_reply);

    const delete_window_reply = context.intern_atom_reply_fn(
        context.connection,
        context.intern_atom_fn(
            context.connection,
            0,
            "WM_DELETE_WINDOW".len,
            "WM_DELETE_WINDOW",
        ),
        null,
    );
    defer std.c.free(delete_window_reply);

    const delete_window_atom = delete_window_reply.*.atom;
    _ = context.change_property_fn(
        context.connection,
        PROP_MODE_REPLACE,
        window,
        protocols_reply.*.atom,
        4,
        32,
        1,
        &delete_window_atom,
    );

    // Set window name
    _ = context.change_property_fn(
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
        const size_hints = SizeHints{
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
        _ = context.change_property_fn(
            context.connection,
            PROP_MODE_REPLACE,
            window,
            ATOM_WM_NORMAL_HINTS,
            ATOM_WM_SIZE_HINTS,
            32,
            @sizeOf(SizeHints) >> 2,
            @ptrCast(&size_hints),
        );
    }

    _ = context.map_window_fn(context.connection, window);
    _ = context.flush_fn(context.connection);

    const self = try allocator.create(Self);
    self.* = .{
        .is_open = true,
        .width = config.width,
        .height = config.height,
        .resizable = config.resizable,

        .event_handler = config.event_handler,

        .context = context,

        .window = window,
        .delete_window_atom = delete_window_atom,

        .last_key_time = 0,
    };

    return self;
}

pub fn destroy(self: *const Self) void {
    _ = self.context.destroy_window_fn(self.context.connection, self.window);
    self.context.allocator.destroy(self);
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
    get_instance_proc_addr_fn: *const Window.GetInstanceProcAddrFn,
    allocation_callbacks: ?*const anyopaque,
) Window.VulkanSurfaceError!*anyopaque {
    const CreateInfo = extern struct {
        s_type: c_int = 1000005000,
        p_next: ?*anyopaque = null,
        flags: c_int = 0,
        connection: *XcbContext.Connection,
        window: u32,
    };
    const create_surface_func: *const fn (
        *const anyopaque,
        *const CreateInfo,
        ?*const anyopaque,
        **anyopaque,
    ) c_int = @ptrCast(get_instance_proc_addr_fn(
        instance,
        "vkCreateXcbSurfaceKHR",
    ) orelse return error.FailedToLoadFunction);

    const create_info = CreateInfo{
        .connection = self.context.connection,
        .window = self.window,
    };

    var surface: *anyopaque = undefined;
    if (create_surface_func(
        instance,
        &create_info,
        allocation_callbacks,
        &surface,
    ) != 0) return error.FailedToCreateSurface;

    return surface;
}

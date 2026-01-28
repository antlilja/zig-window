const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const xcb = @import("xcb/base.zig");
const randr = @import("xcb/randr.zig");
const xkb = @import("xcb/xkb.zig");

const XcbWindow = @import("XcbWindow.zig");

const Self = @This();

const required_vulkan_extensions = [_][*:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_xcb_surface",
};

windows: []XcbWindow,
available_windows: std.ArrayList(u32),
window_map: std.AutoHashMapUnmanaged(u32, *XcbWindow),

xcb_lib: xcb.Library,
randr_lib: ?randr.Library,
xkb_lib: xkb.Library,

connection: *xcb.Connection,

fn load(comptime Library: type, comptime prefix: []const u8, lib_name: []const u8) ?Library {
    var library: Library = undefined;
    library.handle = std.DynLib.open(lib_name) catch return null;
    inline for (@typeInfo(Library).@"struct".fields[1..]) |field| {
        @field(library, field.name) = library.handle.lookup(
            field.type,
            prefix ++ field.name,
        ) orelse return null;
    }
    return library;
}

pub fn init(allocator: std.mem.Allocator, config: Context.Config) !Context {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.xcb_lib = load(
        xcb.Library,
        "xcb_",
        "libxcb.so.1",
    ) orelse return error.FailedToLoadFunction;
    errdefer self.xcb_lib.deinit();

    self.randr_lib = load(
        randr.Library,
        "xcb_randr_",
        "libxcb-randr.so",
    ) orelse null;
    errdefer if (self.randr_lib) |*randr_lib| randr_lib.deinit();

    self.xkb_lib = load(
        xkb.Library,
        "xcb_xkb_",
        "libxcb-xkb.so",
    ) orelse return error.FailedToLoadFunction;
    errdefer self.xkb_lib.deinit();

    self.connection = self.xcb_lib.connect(null, null) orelse return error.FailedToInitialize;
    errdefer self.xcb_lib.disconnect(self.connection);

    if (self.xcb_lib.connection_has_error(self.connection) != 0) return error.FailedToInitialize;

    self.window_map = .{};
    try self.window_map.ensureTotalCapacity(allocator, config.max_window_count);
    errdefer self.window_map.deinit(allocator);

    self.windows = try allocator.alloc(XcbWindow, config.max_window_count);
    errdefer allocator.free(self.windows);

    self.available_windows = try .initCapacity(allocator, config.max_window_count);
    errdefer self.available_windows.deinit(allocator);
    for (0..config.max_window_count) |window_index| self.available_windows.appendAssumeCapacity(@intCast(window_index));

    // Setup non repeatable release
    {
        {
            const reply = self.xkb_lib.use_extension_reply(
                self.connection,
                self.xkb_lib.use_extension(
                    self.connection,
                    1,
                    13,
                ),
                null,
            ) orelse return error.FailedToCreateWindow;
            defer std.c.free(reply);
        }

        const kbd_device_id = blk: {
            const reply = self.xkb_lib.get_device_info_reply(
                self.connection,
                self.xkb_lib.get_device_info(
                    self.connection,
                    256, // XCB_XKB_ID_USE_CORE_KBD
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                ),
                null,
            ) orelse return error.FailedToCreateWindow;
            defer std.c.free(reply);

            break :blk reply.device_id;
        };

        const reply = self.xkb_lib.per_client_flags_reply(
            self.connection,
            self.xkb_lib.per_client_flags(
                self.connection,
                kbd_device_id,
                1, // XCB_XKB_PER_CLIENT_FLAG_DETECTABLE_AUTO_REPEAT
                1, // XCB_XKB_PER_CLIENT_FLAG_DETECTABLE_AUTO_REPEAT
                0,
                0,
                0,
            ),
            null,
        ) orelse return error.FailedToCreateWindow;
        defer std.c.free(reply);
    }

    return .{
        .handle = @ptrCast(self),
        .deinit_fn = @ptrCast(&deinit),
        .create_window_fn = @ptrCast(&createWindow),
        .poll_events_fn = @ptrCast(&pollEvents),
        .get_monitors_fn = @ptrCast(&getMonitors),
        .required_vulkan_instance_extensions_fn = @ptrCast(&requiredVulkanInstanceExtensions),
        .get_physical_device_presentation_support_fn = @ptrCast(&getPhysicalDevicePresentationSupport),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.xcb_lib.disconnect(self.connection);
    if (self.randr_lib) |*randr_lib| randr_lib.deinit();
    self.xcb_lib.deinit();
    self.available_windows.deinit(allocator);
    allocator.free(self.windows);
    self.window_map.deinit(allocator);
    allocator.destroy(self);
}

pub fn createWindow(
    self: *Self,
    config: Window.Config,
) Context.CreateWindowError!Window {
    const window_index = self.available_windows.pop() orelse return error.MaxWindowCountExceeded;
    const window = &self.windows[window_index];

    try window.create(
        self,
        config,
    );
    errdefer window.destroy();

    self.window_map.putAssumeCapacity(
        window.window,
        window,
    );

    return .{
        .handle = @ptrCast(window),
        .is_open_fn = @ptrCast(&XcbWindow.isOpen),
        .destroy_fn = @ptrCast(&XcbWindow.destroy),
        .get_size_fn = @ptrCast(&XcbWindow.getSize),
        .create_vulkan_surface_fn = @ptrCast(&XcbWindow.createVulkanSurface),
    };
}

pub fn destroyWindow(self: *Self, window: *const XcbWindow) void {
    _ = self.window_map.remove(window.window);
    const window_index: u32 = @intCast(@intFromPtr(window) - @intFromPtr(self.windows.ptr));
    self.available_windows.appendAssumeCapacity(window_index);
}

pub fn getMonitors(
    self: *Self,
    allocator: std.mem.Allocator,
) std.mem.Allocator.Error![]const Context.Monitor {
    const randr_lib = self.randr_lib orelse return &.{};

    const setup = self.xcb_lib.get_setup(self.connection);
    const screen = self.xcb_lib.setup_roots_iterator(setup).data;

    const cookie = randr_lib.get_monitors(self.connection, screen.root, 1);
    const reply = randr_lib.get_monitors_reply(
        self.connection,
        cookie,
        null,
    );
    defer std.c.free(@constCast(reply));

    const monitors = try allocator.alloc(Context.Monitor, reply.num_monitors);
    errdefer allocator.free(monitors);

    var it = randr_lib.get_monitors_monitors_iterator(reply);
    var index: usize = 0;
    while (it.rem != 0) : ({
        randr_lib.monitor_info_next(&it);
        index += 1;
    }) {
        monitors[index] = .{
            .is_primary = it.data.primary != 0,
            .x = @intCast(it.data.x),
            .y = @intCast(it.data.y),
            .width = @intCast(it.data.width),
            .height = @intCast(it.data.height),
        };
    }

    return monitors;
}

pub fn requiredVulkanInstanceExtensions(_: *const Self) []const [*:0]const u8 {
    return &required_vulkan_extensions;
}

pub fn getPhysicalDevicePresentationSupport(
    self: *Self,
    instance: *const anyopaque,
    physical_device: *const anyopaque,
    queue_family_index: u32,
    get_instance_proc_addr: *const Context.GetInstanceProcAddrFn,
) Context.VulkanGetPresentationSupportError!u32 {
    const setup = self.xcb_lib.get_setup(self.connection);
    const screen = self.xcb_lib.setup_roots_iterator(setup).data;

    const get_physical_device_presentation_support: *const fn (
        *const anyopaque,
        u32,
        *const xcb.Connection,
        u32,
    ) u32 = @ptrCast(get_instance_proc_addr(
        instance,
        "vkGetPhysicalDeviceXcbPresentationSupportKHR",
    ) orelse return error.FailedToLoadFunction);

    return get_physical_device_presentation_support(
        physical_device,
        queue_family_index,
        self.connection,
        screen.root_visual,
    );
}

pub fn pollEvents(self: *Self) void {
    while (self.xcb_lib.poll_for_event(self.connection)) |event| {
        switch (enumFromResponseType(event.response_type)) {
            .client_message => {
                const client_event: *const xcb.ClientMessageEvent = @ptrCast(event);
                if (self.window_map.get(client_event.window)) |window| {
                    if (client_event.*.data.data32[0] == window.delete_window_atom) {
                        window.is_open = false;
                        window.event_handler.handleEvent(.Destroy);
                    }
                }
            },
            .configure_notify => {
                const config_event: *const xcb.ConfigureNotifyEvent = @ptrCast(event);
                if (self.window_map.get(config_event.window)) |window| {
                    if (config_event.width != window.width or config_event.height != window.height) {
                        window.width = config_event.width;
                        window.height = config_event.height;
                        window.event_handler.handleEvent(.{ .Resize = .{
                            window.width,
                            window.height,
                        } });
                    }
                }
            },
            .focus_in => {
                const focus_event: *const xcb.FocusEvent = @ptrCast(event);
                if (self.window_map.get(focus_event.window)) |window| window.event_handler.handleEvent(.FocusIn);
            },
            .focus_out => {
                const focus_event: *const xcb.FocusEvent = @ptrCast(event);
                if (self.window_map.get(focus_event.window)) |window| window.event_handler.handleEvent(.FocusOut);
            },
            .key_press => {
                const key_event: *const xcb.KeyEvent = @ptrCast(event);
                if (self.window_map.get(key_event.window)) |window| {
                    const keycode = enumFromKeycode(key_event.detail);
                    const state_ptr = window.key_states.getPtr(keycode);
                    if (state_ptr.*) continue;
                    state_ptr.* = true;
                    window.event_handler.handleEvent(.{
                        .KeyPress = keycode,
                    });
                }
            },
            .key_release => {
                const key_event: *const xcb.KeyEvent = @ptrCast(event);
                if (self.window_map.get(key_event.window)) |window| {
                    const keycode = enumFromKeycode(key_event.detail);
                    window.key_states.set(keycode, false);
                    window.event_handler.handleEvent(.{
                        .KeyRelease = keycode,
                    });
                }
            },
            .button_press => {
                const button_event: *const xcb.ButtonEvent = @ptrCast(event);
                if (self.window_map.get(button_event.window)) |window| {
                    window.event_handler.handleEvent(switch (button_event.detail) {
                        4 => .{ .MouseScrollV = 1 },
                        5 => .{ .MouseScrollV = -1 },
                        6 => .{ .MouseScrollH = 1 },
                        7 => .{ .MouseScrollH = -1 },
                        else => .{ .MousePress = enumFromMousecode(button_event.detail) },
                    });
                }
            },
            .button_release => {
                const button_event: *const xcb.ButtonEvent = @ptrCast(event);
                if (self.window_map.get(button_event.window)) |window| {
                    if (button_event.detail != 4 and button_event.detail != 5) {
                        window.event_handler.handleEvent(.{
                            .MouseRelease = enumFromMousecode(button_event.detail),
                        });
                    }
                }
            },
            .motion_notify => {
                const motion_event: *const xcb.MotionNotifyEvent = @ptrCast(event);
                if (self.window_map.get(motion_event.window)) |window| {
                    window.event_handler.handleEvent(.{
                        .MouseMove = .{
                            motion_event.event_x,
                            motion_event.event_y,
                        },
                    });
                }
            },
            else => {},
        }
        std.c.free(event);
    }
}

fn enumFromResponseType(ty: u8) xcb.ResponseType {
    return @enumFromInt(@as(i16, @intCast(ty)) & (-0x80 - 1));
}

fn enumFromKeycode(code: u8) EventHandler.Key {
    return switch (code) {
        19 => .zero,
        10 => .one,
        11 => .two,
        12 => .three,
        13 => .four,
        14 => .five,
        15 => .six,
        16 => .seven,
        17 => .eight,
        18 => .nine,
        90 => .numpad_0,
        87 => .numpad_1,
        88 => .numpad_2,
        89 => .numpad_3,
        83 => .numpad_4,
        84 => .numpad_5,
        85 => .numpad_6,
        79 => .numpad_7,
        80 => .numpad_8,
        81 => .numpad_9,
        91 => .numpad_decimal,
        86 => .numpad_add,
        82 => .numpad_subtract,
        63 => .numpad_multiply,
        106 => .numpad_divide,
        77 => .numpad_lock,
        104 => .numpad_enter,
        38 => .a,
        56 => .b,
        54 => .c,
        40 => .d,
        26 => .e,
        41 => .f,
        42 => .g,
        43 => .h,
        31 => .i,
        44 => .j,
        45 => .k,
        46 => .l,
        58 => .m,
        57 => .n,
        32 => .o,
        33 => .p,
        24 => .q,
        27 => .r,
        39 => .s,
        28 => .t,
        30 => .u,
        55 => .v,
        25 => .w,
        53 => .x,
        29 => .y,
        52 => .z,
        111 => .up,
        116 => .down,
        114 => .right,
        113 => .left,
        60 => .period,
        59 => .comma,
        50 => .left_shift,
        62 => .right_shift,
        37 => .left_ctrl,
        105 => .right_ctrl,
        64 => .left_alt,
        108 => .right_alt,
        118 => .insert,
        119 => .delete,
        110 => .home,
        115 => .end,
        112 => .page_up,
        117 => .page_down,
        107 => .print_screen,
        78 => .scroll_lock,
        127 => .pause,
        9 => .escape,
        23 => .tab,
        66 => .caps_lock,
        133 => .left_super,
        65 => .space,
        22 => .backspace,
        36 => .enter,
        135 => .menu,
        61 => .slash,
        51 => .back_slash,
        20 => .minus,
        21 => .equal,
        48 => .apostrophe,
        47 => .semicolon,
        34 => .left_bracket,
        35 => .right_bracket,
        49 => .tilde,
        67 => .f1,
        68 => .f2,
        69 => .f3,
        70 => .f4,
        71 => .f5,
        72 => .f6,
        73 => .f7,
        74 => .f8,
        75 => .f9,
        76 => .f10,
        95 => .f11,
        96 => .f12,
        94 => .oem_1,
        else => .none,
    };
}

fn enumFromMousecode(code: u8) EventHandler.Mouse {
    return switch (code) {
        1 => .left,
        2 => .middle,
        3 => .right,
        8 => .one,
        9 => .two,
        else => .none,
    };
}

const std = @import("std");

const Context = @import("Context.zig");
const EventHandler = @import("EventHandler.zig");
const Window = @import("Window.zig");

const wayland = @import("wayland.zig");

const WaylandWindow = @import("WaylandWindow.zig");

const Self = @This();

const required_vulkan_extensions = [_][*:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_wayland_surface",
};

const registry_listener = wayland.Registry.Listener{
    .global = @ptrCast(&registryHandleGlobal),
    .global_remove = @ptrCast(&registryHandleGlobalRemove),
};

const xdg_wm_base_listener = wayland.XdgWmBase.Listener{
    .ping = @ptrCast(&xdgWmBaseHandlePing),
};

const seat_listener = wayland.Seat.Listener{
    .capabilities = @ptrCast(&seatHandleCapabilities),
    .name = @ptrCast(&seatHandleName),
};

const pointer_listener = wayland.Pointer.Listener{
    .enter = @ptrCast(&pointerHandleEnter),
    .leave = @ptrCast(&pointerHandleLeave),
    .motion = @ptrCast(&pointerHandleMotion),
    .button = @ptrCast(&pointerHandleButton),
    .axis = @ptrCast(&pointerHandleAxis),
};

const keyboard_listener = wayland.Keyboard.Listener{
    .map = @ptrCast(&keyboardHandleMap),
    .enter = @ptrCast(&keyboardHandleEnter),
    .leave = @ptrCast(&keyboardHandleLeave),
    .key = @ptrCast(&keyboardHandleKey),
    .mod = @ptrCast(&keyboardHandleMod),
    .rep = @ptrCast(&keyboardHandleRep),
};

const output_listener = wayland.Output.Listener{
    .geometry = @ptrCast(&outputHandleGeometry),
    .mode = @ptrCast(&outputHandleMode),
    .done = @ptrCast(&outputHandleDone),
    .scale = @ptrCast(&outputHandleScale),
};

allocator: std.mem.Allocator,
windows: []WaylandWindow,
available_windows: std.ArrayList(u32),

lib: wayland.Library,

display: *wayland.Display,
registry: *wayland.Registry,
compositor: *wayland.Compositor,
seat: *wayland.Seat,
pointer: *wayland.Pointer,
keyboard: *wayland.Keyboard,
wm_base: *wayland.XdgWmBase,

outputs: std.ArrayList(*wayland.Output),
monitors: std.ArrayList(Context.Monitor),

focused_window: ?*WaylandWindow = null,

fn load(lib_name: []const u8) ?wayland.Library {
    var library: wayland.Library = undefined;
    library.handle = std.DynLib.open(lib_name) catch return null;
    inline for (@typeInfo(wayland.Library).@"struct".fields[1..]) |field| {
        @field(library, field.name) = library.handle.lookup(
            field.type,
            field.name,
        ) orelse return null;
    }
    return library;
}

pub fn init(allocator: std.mem.Allocator, config: Context.Config) Context.InitError!Context {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.allocator = allocator;

    self.lib = load("libwayland-client.so") orelse return error.FailedToInitialize;
    errdefer self.lib.deinit();

    self.display = self.lib.wl_display_connect(null) orelse return error.FailedToInitialize;
    errdefer self.lib.wl_display_disconnect(self.display);

    self.registry = self.lib.wl_display_get_registry(self.display) orelse return error.FailedToInitialize;
    errdefer self.lib.wl_registry_destroy(self.registry);

    self.outputs = .empty;
    self.monitors = .empty;

    self.lib.wl_registry_add_listener(
        self.registry,
        &registry_listener,
        @ptrCast(self),
    );
    self.lib.wl_display_roundtrip(self.display);
    errdefer {
        self.lib.xdg_wm_base_destroy(self.wm_base);
        self.lib.wl_compositor_destroy(self.compositor);
    }

    self.lib.wl_display_roundtrip(self.display);

    self.windows = try allocator.alloc(WaylandWindow, config.max_window_count);
    errdefer allocator.free(self.windows);

    self.available_windows = try .initCapacity(allocator, config.max_window_count);
    errdefer self.available_windows.deinit(allocator);
    for (0..config.max_window_count) |window_index| self.available_windows.appendAssumeCapacity(@intCast(window_index));

    self.focused_window = null;

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
    self.monitors.deinit(allocator);
    for (self.outputs.items) |output| self.lib.wl_output_destroy(output);
    self.outputs.deinit(allocator);
    self.lib.xdg_wm_base_destroy(self.wm_base);
    self.lib.wl_compositor_destroy(self.compositor);
    self.lib.wl_registry_destroy(self.registry);
    self.lib.wl_display_disconnect(self.display);
    self.available_windows.deinit(allocator);
    allocator.free(self.windows);
    self.lib.deinit();
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

    return .{
        .handle = @ptrCast(window),
        .is_open_fn = @ptrCast(&WaylandWindow.isOpen),
        .destroy_fn = @ptrCast(&WaylandWindow.destroy),
        .get_size_fn = @ptrCast(&WaylandWindow.getSize),
        .create_vulkan_surface_fn = @ptrCast(&WaylandWindow.createVulkanSurface),
    };
}

pub fn destroyWindow(self: *Self, window: *const WaylandWindow) void {
    const window_index: u32 = @intCast(@intFromPtr(window) - @intFromPtr(self.windows.ptr));
    self.available_windows.appendAssumeCapacity(window_index);
}

pub fn getMonitors(
    self: *Self,
    allocator: std.mem.Allocator,
) std.mem.Allocator.Error![]const Context.Monitor {
    return self.monitors.toOwnedSlice(allocator);
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
    const get_physical_device_presentation_support: *const fn (
        *const anyopaque,
        u32,
        *const wayland.Display,
    ) u32 = @ptrCast(get_instance_proc_addr(
        instance,
        "vkGetPhysicalDeviceWaylandPresentationSupportKHR",
    ) orelse return error.FailedToLoadFunction);

    return get_physical_device_presentation_support(
        physical_device,
        queue_family_index,
        self.display,
    );
}

pub fn pollEvents(self: *Self) void {
    self.lib.wl_display_roundtrip(self.display);
}

fn registryHandleGlobal(
    self: *Self,
    registry: *wayland.Registry,
    name: u32,
    interface_z: [*:0]const u8,
    version: u32,
) callconv(.c) void {
    _ = version;
    const interface = interface_z[0..std.mem.len(interface_z)];
    if (std.mem.eql(u8, interface, "wl_compositor")) {
        self.compositor = @ptrCast(self.lib.wl_registry_bind(
            registry,
            name,
            &wayland.wl.compositor.interface,
            1,
        ) orelse @panic("Failed to bind compositor"));
    } else if (std.mem.eql(u8, interface, "xdg_wm_base")) {
        self.wm_base = @ptrCast(self.lib.wl_registry_bind(
            registry,
            name,
            &wayland.xdg.wm_base.interface,
            1,
        ) orelse @panic("Failed to bind xdg wm base"));
        self.lib.xdg_wm_base_add_listener(self.wm_base, &xdg_wm_base_listener, @ptrCast(self));
    } else if (std.mem.eql(u8, interface, "wl_seat")) {
        self.seat = @ptrCast(self.lib.wl_registry_bind(
            registry,
            name,
            &wayland.wl.seat.interface,
            1,
        ) orelse @panic("Failed to bind seat"));
        self.lib.wl_seat_add_listener(self.seat, &seat_listener, self);
    } else if (std.mem.eql(u8, interface, "wl_output")) {
        const output: *wayland.Output = @ptrCast(self.lib.wl_registry_bind(
            registry,
            name,
            &wayland.wl.output.interface,
            1,
        ) orelse @panic("Failed to bind output"));
        self.outputs.append(self.allocator, output) catch @panic("Failed to bind output");
        self.monitors.append(self.allocator, .{
            .width = 0,
            .height = 0,
            .x = 0,
            .y = 0,
            .is_primary = false,
        }) catch @panic("Failed to bind output");
        self.lib.wl_output_add_listener(output, &output_listener, self);
    }
}

fn registryHandleGlobalRemove(
    self: *Self,
    registry: *wayland.Registry,
    name: u32,
) callconv(.c) void {
    _ = self;
    _ = registry;
    _ = name;
}

fn outputHandleGeometry(
    self: *Self,
    output: *wayland.Output,
    x: i32,
    y: i32,
    physical_width: i32,
    physical_height: i32,
    subpixel: wayland.Output.Subpixel,
    make: [*:0]const u8,
    model: [*:0]const u8,
    transform: wayland.Output.Transform,
) callconv(.c) void {
    const monitor = blk: {
        for (self.outputs.items, 0..) |o, i| {
            if (o == output) break :blk &self.monitors.items[i];
        }
        return;
    };
    _ = physical_width;
    _ = physical_height;
    _ = subpixel;
    _ = make;
    _ = model;
    _ = transform;
    monitor.x = x;
    monitor.y = y;
}

fn outputHandleMode(self: *Self, output: *wayland.Output, flags: wayland.Output.Mode, width: i32, height: i32, refresh: i32) callconv(.c) void {
    const monitor: *Context.Monitor = blk: {
        for (self.outputs.items, 0..) |o, i| {
            if (o == output) break :blk &self.monitors.items[i];
        }
        return;
    };
    _ = refresh;
    monitor.width = @intCast(width);
    monitor.height = @intCast(height);
    monitor.is_primary = flags.preferred;
}

fn outputHandleDone(self: *Self, output: *wayland.Output) callconv(.c) void {
    _ = self;
    _ = output;
}

fn outputHandleScale(self: *Self, output: *wayland.Output, factor: i32) callconv(.c) void {
    _ = self;
    _ = output;
    _ = factor;
}

fn seatHandleCapabilities(self: *Self, seat: *wayland.Seat, capabilities: wayland.Seat.Capabilities) callconv(.c) void {
    if (capabilities.pointer) {
        self.pointer = self.lib.wl_seat_get_pointer(seat) orelse @panic("Failed to get pointer");
        self.lib.wl_pointer_add_listener(self.pointer, &pointer_listener, self);
    }
    if (capabilities.keyboard) {
        self.keyboard = self.lib.wl_seat_get_keyboard(seat) orelse @panic("Failed to get keyboard");
        self.lib.wl_keyboard_add_listener(self.keyboard, &keyboard_listener, self);
    }
}

fn seatHandleName(self: *Self, seat: *wayland.Seat, name: [*]i8) callconv(.c) void {
    _ = self;
    _ = seat;
    _ = name;
}

fn pointerHandleEnter(self: *Self, pointer: *wayland.Pointer, serial: u32, surface: *wayland.Surface, surface_x: wayland.Fixed, surface_y: wayland.Fixed) callconv(.c) void {
    _ = serial;
    _ = pointer;
    _ = surface_x;
    _ = surface_y;
    const focused_window: *WaylandWindow = @ptrCast(@alignCast(self.lib.wl_surface_get_user_data(surface)));
    self.focused_window = focused_window;
    focused_window.event_handler.handleEvent(.FocusIn);
}

fn pointerHandleLeave(self: *Self, pointer: *wayland.Pointer, serial: u32, surface: *wayland.Surface) callconv(.c) void {
    _ = serial;
    _ = pointer;

    self.focused_window = null;
    const focused_window: *WaylandWindow = @ptrCast(@alignCast(self.lib.wl_surface_get_user_data(surface)));
    focused_window.event_handler.handleEvent(.FocusOut);
}

fn pointerHandleMotion(self: *Self, pointer: *wayland.Pointer, time: u32, surface_x: wayland.Fixed, surface_y: wayland.Fixed) callconv(.c) void {
    _ = pointer;
    _ = time;
    const focused_window = self.focused_window orelse return;

    focused_window.event_handler.handleEvent(.{
        .MouseMove = .{ surface_x.toInt(), surface_y.toInt() },
    });
}

fn pointerHandleButton(self: *Self, pointer: *wayland.Pointer, serial: u32, time: u32, button: u32, state: wayland.Pointer.ButtonState) callconv(.c) void {
    _ = pointer;
    _ = serial;
    _ = time;
    const focused_window = self.focused_window orelse return;

    const buttoncode: EventHandler.Mouse = switch (button) {
        272 => .left,
        274 => .middle,
        273 => .right,
        275 => .one,
        276 => .two,
        else => .none,
    };

    focused_window.event_handler.handleEvent(switch (state) {
        .pressed => .{ .MousePress = buttoncode },
        .released => .{ .MouseRelease = buttoncode },
    });
}

fn pointerHandleAxis(self: *Self, pointer: *wayland.Pointer, time: u32, axis: wayland.Pointer.Axis, value: wayland.Fixed) callconv(.c) void {
    _ = pointer;
    _ = time;
    const focused_window = self.focused_window orelse return;
    focused_window.event_handler.handleEvent(switch (axis) {
        .vertical_scroll => .{ .MouseScrollV = @truncate(value.toInt()) },
        .horizontal_scroll => .{ .MouseScrollH = @truncate(value.toInt()) },
    });
}

fn keyboardHandleMap(self: *Self, keyboard: *wayland.Keyboard, format: wayland.Keyboard.Format, fd: i32, sz: u32) callconv(.c) void {
    _ = self;
    _ = keyboard;
    _ = fd;
    _ = sz;
    if (format != .xkb_v1) @panic("Incorrect keyboard format");
}

fn keyboardHandleEnter(self: *Self, keyboard: *wayland.Keyboard, serial: u32, surface: *wayland.Surface, keys: ?*wayland.Array) callconv(.c) void {
    _ = self;
    _ = keyboard;
    _ = serial;
    _ = surface;
    _ = keys;
}

fn keyboardHandleLeave(self: *Self, keyboard: *wayland.Keyboard, serial: u32, surface: *wayland.Surface) callconv(.c) void {
    _ = self;
    _ = keyboard;
    _ = serial;
    _ = surface;
}

fn keyboardHandleKey(self: *Self, keyboard: *wayland.Keyboard, serial: u32, time: u32, key: u32, state: wayland.Keyboard.KeyState) callconv(.c) void {
    const focused_window = self.focused_window orelse return;
    const keycode: EventHandler.Key = switch (key + 8) {
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
    _ = keyboard;
    _ = serial;
    _ = time;
    focused_window.event_handler.handleEvent(switch (state) {
        .pressed => .{ .KeyPress = keycode },
        .released => .{ .KeyRelease = keycode },
        else => unreachable,
    });
}

fn keyboardHandleMod(self: *Self, keyboard: *wayland.Keyboard, serial: u32, depressed: u32, latched: u32, locked: u32, group: u32) callconv(.c) void {
    _ = self;
    _ = keyboard;
    _ = serial;
    _ = depressed;
    _ = latched;
    _ = locked;
    _ = group;
}

fn keyboardHandleRep(self: *Self, keyboard: *wayland.Keyboard, rate: i32, delay: i32) callconv(.c) void {
    _ = self;
    _ = keyboard;
    _ = rate;
    _ = delay;
}

fn xdgWmBaseHandlePing(self: *Self, wm_base: *wayland.XdgWmBase, serial: u32) callconv(.c) void {
    self.lib.xdg_wm_base_pong(wm_base, serial);
}

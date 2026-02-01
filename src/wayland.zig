const std = @import("std");

pub const Display = opaque {};

pub const Registry = opaque {
    pub const Listener = extern struct {
        global: *const fn (data: ?*anyopaque, registry: *Registry, name: u32, interface: [*:0]const u8, version: u32) callconv(.c) void,
        global_remove: *const fn (data: ?*anyopaque, registry: *Registry, name: u32) callconv(.c) void,
    };
};

pub const Compositor = opaque {};

pub const Output = opaque {
    pub const Subpixel = enum(u32) {
        unknown = 0,
        none = 1,
        horizontal_rgb = 2,
        horizontal_bgr = 3,
        vertical_rgb = 4,
        vertical_bgr = 5,
    };

    pub const Transform = enum(u32) {
        normal = 0,
        transform_90 = 1,
        transform_180 = 2,
        transform_270 = 3,
        flipped = 4,
        flipped_90 = 5,
        flipped_180 = 6,
        flipped_270 = 7,
    };

    pub const Mode = packed struct(u32) {
        current: bool,
        preferred: bool,
        reserved: u30,
    };

    pub const Listener = extern struct {
        geometry: *const fn (data: ?*anyopaque, output: *Output, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: Subpixel, make: [*:0]const u8, model: [*:0]const u8, transform: Transform) callconv(.c) void,
        mode: *const fn (data: ?*anyopaque, output: *Output, flags: Mode, width: i32, height: i32, refresh: i32) callconv(.c) void,
        done: *const fn (data: ?*anyopaque, output: *Output) callconv(.c) void,
        scale: *const fn (data: ?*anyopaque, output: *Output, factor: i32) callconv(.c) void,
    };
};

pub const Seat = opaque {
    pub const Capabilities = packed struct(u32) {
        pointer: bool,
        keyboard: bool,
        touch: bool,
        reserved: u29,
    };

    pub const Listener = extern struct {
        capabilities: *const fn (data: ?*anyopaque, seat: *Seat, capabilities: Capabilities) callconv(.c) void,
        name: *const fn (data: ?*anyopaque, seat: *Seat, name: [*]i8) callconv(.c) void,
    };
};

pub const Pointer = opaque {
    pub const ButtonState = enum(u32) {
        released = 0,
        pressed = 1,
    };

    pub const Axis = enum(u32) {
        vertical_scroll = 0,
        horizontal_scroll = 1,
    };

    pub const Listener = extern struct {
        enter: *const fn (data: ?*anyopaque, pointer: *Pointer, serial: u32, surface: *Surface, surface_x: Fixed, surface_y: Fixed) callconv(.c) void,
        leave: *const fn (data: ?*anyopaque, pointer: *Pointer, serial: u32, surface: *Surface) callconv(.c) void,
        motion: *const fn (data: ?*anyopaque, pointer: *Pointer, time: u32, surface_x: Fixed, surface_y: Fixed) callconv(.c) void,
        button: *const fn (data: ?*anyopaque, pointer: *Pointer, serial: u32, time: u32, button: u32, state: ButtonState) callconv(.c) void,
        axis: *const fn (data: ?*anyopaque, pointer: *Pointer, time: u32, axis: Axis, value: Fixed) callconv(.c) void,
    };
};

pub const Keyboard = opaque {
    pub const Format = enum(u32) {
        no_keymap = 0,
        xkb_v1 = 1,
        _,
    };

    pub const KeyState = enum(u32) {
        released = 0,
        pressed = 1,
        repeated = 2,
    };

    pub const Listener = extern struct {
        map: *const fn (data: ?*anyopaque, keyboard: *Keyboard, format: Format, fd: i32, size: u32) callconv(.c) void,
        enter: *const fn (data: ?*anyopaque, keyboard: *Keyboard, serial: u32, surface: *Surface, keys: ?*Array) callconv(.c) void,
        leave: *const fn (data: ?*anyopaque, keyboard: *Keyboard, serial: u32, surface: *Surface) callconv(.c) void,
        key: *const fn (data: ?*anyopaque, keyboard: *Keyboard, serial: u32, time: u32, key: u32, state: KeyState) callconv(.c) void,
        mod: *const fn (data: ?*anyopaque, keyboard: *Keyboard, serial: u32, depressed: u32, latched: u32, locked: u32, group: u32) callconv(.c) void,
        rep: *const fn (data: ?*anyopaque, keyboard: *Keyboard, rate: i32, delay: i32) callconv(.c) void,
    };
};

pub const Surface = opaque {};

pub const XdgWmBase = opaque {
    pub const Listener = extern struct {
        ping: *const fn (data: ?*anyopaque, wm_base: *XdgWmBase, serial: u32) callconv(.c) void,
    };
};

pub const XdgSurface = opaque {
    pub const Listener = extern struct {
        configure: *const fn (data: ?*anyopaque, surface: *XdgSurface, serial: u32) callconv(.c) void,
    };
};

pub const XdgToplevel = opaque {
    pub const Listener = extern struct {
        configure: *const fn (data: ?*anyopaque, top_level: *XdgToplevel, width: i32, height: i32, states: *anyopaque) callconv(.c) void,
        close: *const fn (data: ?*anyopaque, top_level: *XdgToplevel) callconv(.c) void,
    };
};

pub const Library = struct {
    handle: std.DynLib,

    wl_proxy_add_listener: *const fn (proxy: *anyopaque, listener: *const anyopaque, data: ?*anyopaque) callconv(.c) void,
    wl_proxy_marshal: *const fn (proxy: *anyopaque, opcode: u32) callconv(.c) void,
    wl_proxy_marshal_array: *const fn (proxy: *anyopaque, opcode: u32, args: ?[*]Argument) callconv(.c) void,
    wl_proxy_marshal_constructor: *const fn (proxy: *anyopaque, opcode: u32, interface: *const Interface) callconv(.c) ?*anyopaque,
    wl_proxy_marshal_array_constructor: *const fn (proxy: *anyopaque, opcode: u32, args: ?[*]Argument, interface: *const Interface) callconv(.c) ?*anyopaque,
    wl_proxy_set_user_data: *const fn (proxy: *anyopaque, user_data: ?*anyopaque) callconv(.c) void,
    wl_proxy_get_user_data: *const fn (proxy: *anyopaque) callconv(.c) ?*anyopaque,
    wl_proxy_destroy: *const fn (proxy: *anyopaque) callconv(.c) void,

    wl_display_connect: *const fn (name: ?[*:0]const u8) callconv(.c) ?*Display,
    wl_display_disconnect: *const fn (display: *Display) callconv(.c) void,
    wl_display_roundtrip: *const fn (display: *Display) callconv(.c) void,

    pub inline fn wl_display_get_registry(self: *const Library, display: *Display) ?*Registry {
        return @ptrCast(self.wl_proxy_marshal_constructor(
            display,
            1,
            &wl.registry.interface,
        ));
    }

    pub inline fn wl_registry_add_listener(self: *const Library, registry: *Registry, listener: *const Registry.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            registry,
            listener,
            data,
        );
    }

    pub inline fn wl_registry_bind(
        self: *const Library,
        registry: *Registry,
        name: u32,
        interface: *const Interface,
        version: u32,
    ) ?*anyopaque {
        var args = [_]Argument{
            .{ .u = name },
            .{ .s = interface.name },
            .{ .u = version },
            .{ .o = null },
        };
        return self.wl_proxy_marshal_array_constructor(
            registry,
            0,
            &args,
            interface,
        );
    }

    pub inline fn wl_registry_destroy(self: *const Library, registry: *Registry) void {
        self.wl_proxy_destroy(registry);
    }

    pub inline fn wl_compositor_create_surface(self: *const Library, compositor: *Compositor) ?*Surface {
        return @ptrCast(self.wl_proxy_marshal_constructor(
            compositor,
            0,
            &wl.surface.interface,
        ));
    }

    pub inline fn wl_compositor_destroy(self: *const Library, compositor: *Compositor) void {
        self.wl_proxy_destroy(compositor);
    }

    pub inline fn wl_surface_commit(self: *const Library, surface: *Surface) void {
        self.wl_proxy_marshal(surface, 6);
    }

    pub inline fn wl_surface_set_user_data(self: *const Library, surface: *Surface, data: ?*anyopaque) void {
        self.wl_proxy_set_user_data(surface, data);
    }

    pub inline fn wl_surface_get_user_data(self: *const Library, surface: *Surface) ?*anyopaque {
        return self.wl_proxy_get_user_data(surface);
    }

    pub inline fn wl_surface_destroy(self: *const Library, surface: *Surface) void {
        self.wl_proxy_destroy(surface);
    }

    pub inline fn wl_output_add_listener(self: *const Library, output: *Output, listener: *const Output.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            output,
            listener,
            data,
        );
    }

    pub inline fn wl_output_destroy(self: *const Library, output: *Output) void {
        self.wl_proxy_destroy(output);
    }

    pub inline fn wl_seat_add_listener(self: *const Library, seat: *Seat, listener: *const Seat.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            seat,
            listener,
            data,
        );
    }

    pub inline fn wl_seat_get_pointer(self: *const Library, seat: *Seat) ?*Pointer {
        return @ptrCast(self.wl_proxy_marshal_constructor(
            seat,
            0,
            &wl.pointer.interface,
        ));
    }

    pub inline fn wl_seat_get_keyboard(self: *const Library, seat: *Seat) ?*Keyboard {
        return @ptrCast(self.wl_proxy_marshal_constructor(
            seat,
            1,
            &wl.keyboard.interface,
        ));
    }

    pub inline fn wl_pointer_add_listener(self: *const Library, pointer: *Pointer, listener: *const Pointer.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            pointer,
            listener,
            data,
        );
    }

    pub inline fn wl_keyboard_add_listener(self: *const Library, keyboard: *Keyboard, listener: *const Keyboard.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            keyboard,
            listener,
            data,
        );
    }

    pub inline fn xdg_wm_base_add_listener(self: *const Library, wm_base: *XdgWmBase, listener: *const XdgWmBase.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            wm_base,
            listener,
            data,
        );
    }

    pub inline fn xdg_wm_base_get_xdg_surface(self: *const Library, wm_base: *XdgWmBase, surface: *Surface) ?*XdgSurface {
        var args = [_]Argument{
            .{ .o = null },
            .{ .o = surface },
        };
        return @ptrCast(self.wl_proxy_marshal_array_constructor(
            wm_base,
            2,
            &args,
            &xdg.surface.interface,
        ));
    }

    pub inline fn xdg_wm_base_pong(self: *const Library, wm_base: *XdgWmBase, serial: u32) void {
        var args = [_]Argument{
            .{ .u = serial },
        };
        self.wl_proxy_marshal_array(wm_base, 3, &args);
    }

    pub inline fn xdg_wm_base_destroy(self: *const Library, wm_base: *XdgWmBase) void {
        self.wl_proxy_destroy(wm_base);
    }

    pub inline fn xdg_surface_add_listener(self: *const Library, surface: *XdgSurface, listener: *const XdgSurface.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            surface,
            listener,
            data,
        );
    }

    pub inline fn xdg_surface_get_toplevel(self: *const Library, surface: *XdgSurface) ?*XdgToplevel {
        var args = [_]Argument{.{ .o = null }};
        return @ptrCast(self.wl_proxy_marshal_array_constructor(
            surface,
            1,
            &args,
            &xdg.toplevel.interface,
        ));
    }

    pub inline fn xdg_surface_ack_configure(self: *const Library, surface: *XdgSurface, serial: u32) void {
        var args = [_]Argument{
            .{ .u = serial },
        };
        self.wl_proxy_marshal_array(surface, 4, &args);
    }

    pub inline fn xdg_surface_destroy(self: *const Library, surface: *XdgSurface) void {
        self.wl_proxy_destroy(surface);
    }

    pub inline fn xdg_toplevel_add_listener(self: *const Library, toplevel: *XdgToplevel, listener: *const XdgToplevel.Listener, data: ?*anyopaque) void {
        self.wl_proxy_add_listener(
            toplevel,
            listener,
            data,
        );
    }

    pub inline fn xdg_toplevel_set_title(self: *const Library, toplevel: *XdgToplevel, name: [*:0]const u8) void {
        var args = [_]Argument{.{ .s = name }};
        self.wl_proxy_marshal_array(toplevel, 2, &args);
    }

    pub inline fn xdg_toplevel_set_app_id(self: *const Library, toplevel: *XdgToplevel, app_id: [*:0]const u8) void {
        var args = [_]Argument{.{ .s = app_id }};
        self.wl_proxy_marshal_array(toplevel, 3, &args);
    }

    pub inline fn xdg_toplevel_set_max_size(self: *const Library, toplevel: *XdgToplevel, width: i32, height: i32) void {
        var args = [_]Argument{
            .{ .i = width },
            .{ .i = height },
        };
        self.wl_proxy_marshal_array(toplevel, 7, &args);
    }

    pub inline fn xdg_toplevel_set_min_size(self: *const Library, toplevel: *XdgToplevel, width: i32, height: i32) void {
        var args = [_]Argument{
            .{ .i = width },
            .{ .i = height },
        };
        self.wl_proxy_marshal_array(toplevel, 8, &args);
    }

    pub inline fn xdg_toplevel_destroy(self: *const Library, toplevel: *XdgToplevel) void {
        self.wl_proxy_destroy(toplevel);
    }

    pub fn deinit(self: *Library) void {
        self.handle.close();
    }
};

pub const Array = extern struct {
    size: usize,
    alloc: usize,
    data: ?*anyopaque,

    /// Does not clone memory
    pub fn fromArrayList(comptime T: type, array_list: std.ArrayList(T)) Array {
        return Array{
            .size = array_list.items.len * @sizeOf(T),
            .alloc = array_list.capacity * @sizeOf(T),
            .data = array_list.items.ptr,
        };
    }

    pub fn slice(array: Array, comptime T: type) []align(4) T {
        const data = array.data orelse return &[0]T{};
        // The wire protocol/libwayland only guarantee 32-bit word alignment.
        const ptr: [*]align(4) T = @ptrCast(@alignCast(data));
        return ptr[0..@divExact(array.size, @sizeOf(T))];
    }
};

pub const Fixed = enum(i32) {
    _,

    pub fn toInt(f: Fixed) i24 {
        return @truncate(@intFromEnum(f) >> 8);
    }

    pub fn fromInt(i: i24) Fixed {
        return @enumFromInt(@as(i32, i) << 8);
    }
};

const Argument = extern union {
    i: i32,
    u: u32,
    f: Fixed,
    s: ?[*:0]const u8,
    o: ?*anyopaque,
    n: u32,
    a: ?*Array,
    h: i32,
};

const Message = extern struct {
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: ?[*]const ?*const Interface,
};

const Interface = extern struct {
    name: [*:0]const u8,
    version: c_int,
    method_count: c_int,
    methods: ?[*]const Message,
    event_count: c_int,
    events: ?[*]const Message,
};

pub const wl = struct {
    pub const display = struct {
        pub const interface: Interface = .{
            .name = "wl_display",
            .version = 1,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "sync",
                    .signature = "n",
                    .types = &.{
                        &wl.callback.interface,
                    },
                },
                .{
                    .name = "get_registry",
                    .signature = "n",
                    .types = &.{
                        &wl.registry.interface,
                    },
                },
            },
            .event_count = 2,
            .events = &.{
                .{
                    .name = "error",
                    .signature = "ous",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "delete_id",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
        const Error = enum(c_int) {
            pub const invalid_object_since_version = 1;
            pub const invalid_method_since_version = 1;
            pub const no_memory_since_version = 1;
            pub const implementation_since_version = 1;

            invalid_object = 0,
            invalid_method = 1,
            no_memory = 2,
            implementation = 3,
            _,
        };
    };

    pub const registry = struct {
        pub const interface: Interface = .{
            .name = "wl_registry",
            .version = 1,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "bind",
                    .signature = "usun",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
            },
            .event_count = 2,
            .events = &.{
                .{
                    .name = "global",
                    .signature = "usu",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "global_remove",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };

    pub const callback = struct {
        pub const interface: Interface = .{
            .name = "wl_callback",
            .version = 1,
            .method_count = 0,
            .methods = null,
            .event_count = 1,
            .events = &.{
                .{
                    .name = "done",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };

    pub const buffer = struct {
        pub const interface: Interface = .{
            .name = "wl_buffer",
            .version = 1,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
            },
            .event_count = 1,
            .events = &.{
                .{
                    .name = "release",
                    .signature = "",
                    .types = null,
                },
            },
        };
    };

    pub const compositor = struct {
        pub const interface = Interface{
            .name = "wl_compositor",
            .version = 6,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "create_surface",
                    .signature = "n",
                    .types = &.{
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "create_region",
                    .signature = "n",
                    .types = &.{
                        &wl.region.interface,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };

    pub const surface = struct {
        pub const interface: Interface = .{
            .name = "wl_surface",
            .version = 6,
            .method_count = 11,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "attach",
                    .signature = "?oii",
                    .types = &.{
                        &wl.buffer.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "damage",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "frame",
                    .signature = "n",
                    .types = &.{
                        &wl.callback.interface,
                    },
                },
                .{
                    .name = "set_opaque_region",
                    .signature = "?o",
                    .types = &.{
                        &wl.region.interface,
                    },
                },
                .{
                    .name = "set_input_region",
                    .signature = "?o",
                    .types = &.{
                        &wl.region.interface,
                    },
                },
                .{
                    .name = "commit",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_buffer_transform",
                    .signature = "2i",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_buffer_scale",
                    .signature = "3i",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "damage_buffer",
                    .signature = "4iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "offset",
                    .signature = "5ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
            },
            .event_count = 4,
            .events = &.{
                .{
                    .name = "enter",
                    .signature = "o",
                    .types = &.{
                        &wl.output.interface,
                    },
                },
                .{
                    .name = "leave",
                    .signature = "o",
                    .types = &.{
                        &wl.output.interface,
                    },
                },
                .{
                    .name = "preferred_buffer_scale",
                    .signature = "6i",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "preferred_buffer_transform",
                    .signature = "6u",
                    .types = &.{
                        null,
                    },
                },
            },
        };

        const Error = enum(c_int) {
            pub const invalid_scale_since_version = 1;
            pub const invalid_transform_since_version = 1;
            pub const invalid_size_since_version = 1;
            pub const invalid_offset_since_version = 1;
            pub const defunct_role_object_since_version = 1;

            invalid_scale = 0,
            invalid_transform = 1,
            invalid_size = 2,
            invalid_offset = 3,
            defunct_role_object = 4,
            _,
        };
    };

    pub const region = struct {
        pub const interface: Interface = .{
            .name = "wl_region",
            .version = 1,
            .method_count = 3,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "add",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "subtract",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };

    pub const shm = struct {
        pub const interface: Interface = .{
            .name = "wl_shm",
            .version = 2,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "create_pool",
                    .signature = "nhi",
                    .types = &.{
                        &wl.shm_pool.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "release",
                    .signature = "2",
                    .types = null,
                },
            },
            .event_count = 1,
            .events = &.{
                .{
                    .name = "format",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
        /// These errors can be emitted in response to wl_shm requests.
        pub const Error = enum(c_int) {
            pub const invalid_format_since_version = 1;
            pub const invalid_stride_since_version = 1;
            pub const invalid_fd_since_version = 1;

            invalid_format = 0,
            invalid_stride = 1,
            invalid_fd = 2,
            _,
        };

        /// This describes the memory layout of an individual pixel.
        ///
        /// All renderers should support argb8888 and xrgb8888 but any other
        /// formats are optional and may not be supported by the particular
        /// renderer in use.
        ///
        /// The drm format codes match the macros defined in drm_fourcc.h, except
        /// argb8888 and xrgb8888. The formats actually supported by the compositor
        /// will be reported by the format event.
        ///
        /// For all wl_shm formats and unless specified in another protocol
        /// extension, pre-multiplied alpha is used for pixel values.
        pub const Format = enum(c_int) {
            pub const argb8888_since_version = 1;
            pub const xrgb8888_since_version = 1;
            pub const c8_since_version = 1;
            pub const rgb332_since_version = 1;
            pub const bgr233_since_version = 1;
            pub const xrgb4444_since_version = 1;
            pub const xbgr4444_since_version = 1;
            pub const rgbx4444_since_version = 1;
            pub const bgrx4444_since_version = 1;
            pub const argb4444_since_version = 1;
            pub const abgr4444_since_version = 1;
            pub const rgba4444_since_version = 1;
            pub const bgra4444_since_version = 1;
            pub const xrgb1555_since_version = 1;
            pub const xbgr1555_since_version = 1;
            pub const rgbx5551_since_version = 1;
            pub const bgrx5551_since_version = 1;
            pub const argb1555_since_version = 1;
            pub const abgr1555_since_version = 1;
            pub const rgba5551_since_version = 1;
            pub const bgra5551_since_version = 1;
            pub const rgb565_since_version = 1;
            pub const bgr565_since_version = 1;
            pub const rgb888_since_version = 1;
            pub const bgr888_since_version = 1;
            pub const xbgr8888_since_version = 1;
            pub const rgbx8888_since_version = 1;
            pub const bgrx8888_since_version = 1;
            pub const abgr8888_since_version = 1;
            pub const rgba8888_since_version = 1;
            pub const bgra8888_since_version = 1;
            pub const xrgb2101010_since_version = 1;
            pub const xbgr2101010_since_version = 1;
            pub const rgbx1010102_since_version = 1;
            pub const bgrx1010102_since_version = 1;
            pub const argb2101010_since_version = 1;
            pub const abgr2101010_since_version = 1;
            pub const rgba1010102_since_version = 1;
            pub const bgra1010102_since_version = 1;
            pub const yuyv_since_version = 1;
            pub const yvyu_since_version = 1;
            pub const uyvy_since_version = 1;
            pub const vyuy_since_version = 1;
            pub const ayuv_since_version = 1;
            pub const nv12_since_version = 1;
            pub const nv21_since_version = 1;
            pub const nv16_since_version = 1;
            pub const nv61_since_version = 1;
            pub const yuv410_since_version = 1;
            pub const yvu410_since_version = 1;
            pub const yuv411_since_version = 1;
            pub const yvu411_since_version = 1;
            pub const yuv420_since_version = 1;
            pub const yvu420_since_version = 1;
            pub const yuv422_since_version = 1;
            pub const yvu422_since_version = 1;
            pub const yuv444_since_version = 1;
            pub const yvu444_since_version = 1;
            pub const r8_since_version = 1;
            pub const r16_since_version = 1;
            pub const rg88_since_version = 1;
            pub const gr88_since_version = 1;
            pub const rg1616_since_version = 1;
            pub const gr1616_since_version = 1;
            pub const xrgb16161616f_since_version = 1;
            pub const xbgr16161616f_since_version = 1;
            pub const argb16161616f_since_version = 1;
            pub const abgr16161616f_since_version = 1;
            pub const xyuv8888_since_version = 1;
            pub const vuy888_since_version = 1;
            pub const vuy101010_since_version = 1;
            pub const y210_since_version = 1;
            pub const y212_since_version = 1;
            pub const y216_since_version = 1;
            pub const y410_since_version = 1;
            pub const y412_since_version = 1;
            pub const y416_since_version = 1;
            pub const xvyu2101010_since_version = 1;
            pub const xvyu12_16161616_since_version = 1;
            pub const xvyu16161616_since_version = 1;
            pub const y0l0_since_version = 1;
            pub const x0l0_since_version = 1;
            pub const y0l2_since_version = 1;
            pub const x0l2_since_version = 1;
            pub const yuv420_8bit_since_version = 1;
            pub const yuv420_10bit_since_version = 1;
            pub const xrgb8888_a8_since_version = 1;
            pub const xbgr8888_a8_since_version = 1;
            pub const rgbx8888_a8_since_version = 1;
            pub const bgrx8888_a8_since_version = 1;
            pub const rgb888_a8_since_version = 1;
            pub const bgr888_a8_since_version = 1;
            pub const rgb565_a8_since_version = 1;
            pub const bgr565_a8_since_version = 1;
            pub const nv24_since_version = 1;
            pub const nv42_since_version = 1;
            pub const p210_since_version = 1;
            pub const p010_since_version = 1;
            pub const p012_since_version = 1;
            pub const p016_since_version = 1;
            pub const axbxgxrx106106106106_since_version = 1;
            pub const nv15_since_version = 1;
            pub const q410_since_version = 1;
            pub const q401_since_version = 1;
            pub const xrgb16161616_since_version = 1;
            pub const xbgr16161616_since_version = 1;
            pub const argb16161616_since_version = 1;
            pub const abgr16161616_since_version = 1;
            pub const c1_since_version = 1;
            pub const c2_since_version = 1;
            pub const c4_since_version = 1;
            pub const d1_since_version = 1;
            pub const d2_since_version = 1;
            pub const d4_since_version = 1;
            pub const d8_since_version = 1;
            pub const r1_since_version = 1;
            pub const r2_since_version = 1;
            pub const r4_since_version = 1;
            pub const r10_since_version = 1;
            pub const r12_since_version = 1;
            pub const avuy8888_since_version = 1;
            pub const xvuy8888_since_version = 1;
            pub const p030_since_version = 1;

            argb8888 = 0,
            xrgb8888 = 1,
            c8 = 0x20203843,
            rgb332 = 0x38424752,
            bgr233 = 0x38524742,
            xrgb4444 = 0x32315258,
            xbgr4444 = 0x32314258,
            rgbx4444 = 0x32315852,
            bgrx4444 = 0x32315842,
            argb4444 = 0x32315241,
            abgr4444 = 0x32314241,
            rgba4444 = 0x32314152,
            bgra4444 = 0x32314142,
            xrgb1555 = 0x35315258,
            xbgr1555 = 0x35314258,
            rgbx5551 = 0x35315852,
            bgrx5551 = 0x35315842,
            argb1555 = 0x35315241,
            abgr1555 = 0x35314241,
            rgba5551 = 0x35314152,
            bgra5551 = 0x35314142,
            rgb565 = 0x36314752,
            bgr565 = 0x36314742,
            rgb888 = 0x34324752,
            bgr888 = 0x34324742,
            xbgr8888 = 0x34324258,
            rgbx8888 = 0x34325852,
            bgrx8888 = 0x34325842,
            abgr8888 = 0x34324241,
            rgba8888 = 0x34324152,
            bgra8888 = 0x34324142,
            xrgb2101010 = 0x30335258,
            xbgr2101010 = 0x30334258,
            rgbx1010102 = 0x30335852,
            bgrx1010102 = 0x30335842,
            argb2101010 = 0x30335241,
            abgr2101010 = 0x30334241,
            rgba1010102 = 0x30334152,
            bgra1010102 = 0x30334142,
            yuyv = 0x56595559,
            yvyu = 0x55595659,
            uyvy = 0x59565955,
            vyuy = 0x59555956,
            ayuv = 0x56555941,
            nv12 = 0x3231564e,
            nv21 = 0x3132564e,
            nv16 = 0x3631564e,
            nv61 = 0x3136564e,
            yuv410 = 0x39565559,
            yvu410 = 0x39555659,
            yuv411 = 0x31315559,
            yvu411 = 0x31315659,
            yuv420 = 0x32315559,
            yvu420 = 0x32315659,
            yuv422 = 0x36315559,
            yvu422 = 0x36315659,
            yuv444 = 0x34325559,
            yvu444 = 0x34325659,
            r8 = 0x20203852,
            r16 = 0x20363152,
            rg88 = 0x38384752,
            gr88 = 0x38385247,
            rg1616 = 0x32334752,
            gr1616 = 0x32335247,
            xrgb16161616f = 0x48345258,
            xbgr16161616f = 0x48344258,
            argb16161616f = 0x48345241,
            abgr16161616f = 0x48344241,
            xyuv8888 = 0x56555958,
            vuy888 = 0x34325556,
            vuy101010 = 0x30335556,
            y210 = 0x30313259,
            y212 = 0x32313259,
            y216 = 0x36313259,
            y410 = 0x30313459,
            y412 = 0x32313459,
            y416 = 0x36313459,
            xvyu2101010 = 0x30335658,
            xvyu12_16161616 = 0x36335658,
            xvyu16161616 = 0x38345658,
            y0l0 = 0x304c3059,
            x0l0 = 0x304c3058,
            y0l2 = 0x324c3059,
            x0l2 = 0x324c3058,
            yuv420_8bit = 0x38305559,
            yuv420_10bit = 0x30315559,
            xrgb8888_a8 = 0x38415258,
            xbgr8888_a8 = 0x38414258,
            rgbx8888_a8 = 0x38415852,
            bgrx8888_a8 = 0x38415842,
            rgb888_a8 = 0x38413852,
            bgr888_a8 = 0x38413842,
            rgb565_a8 = 0x38413552,
            bgr565_a8 = 0x38413542,
            nv24 = 0x3432564e,
            nv42 = 0x3234564e,
            p210 = 0x30313250,
            p010 = 0x30313050,
            p012 = 0x32313050,
            p016 = 0x36313050,
            axbxgxrx106106106106 = 0x30314241,
            nv15 = 0x3531564e,
            q410 = 0x30313451,
            q401 = 0x31303451,
            xrgb16161616 = 0x38345258,
            xbgr16161616 = 0x38344258,
            argb16161616 = 0x38345241,
            abgr16161616 = 0x38344241,
            c1 = 0x20203143,
            c2 = 0x20203243,
            c4 = 0x20203443,
            d1 = 0x20203144,
            d2 = 0x20203244,
            d4 = 0x20203444,
            d8 = 0x20203844,
            r1 = 0x20203152,
            r2 = 0x20203252,
            r4 = 0x20203452,
            r10 = 0x20303152,
            r12 = 0x20323152,
            avuy8888 = 0x59555641,
            xvuy8888 = 0x59555658,
            p030 = 0x30333050,
            _,
        };
    };

    pub const shm_pool = struct {
        pub const interface: Interface = .{
            .name = "wl_shm_pool",
            .version = 2,
            .method_count = 3,
            .methods = &.{
                .{
                    .name = "create_buffer",
                    .signature = "niiiiu",
                    .types = &.{
                        &wl.buffer.interface,
                        null,
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "resize",
                    .signature = "i",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };
    pub const data_device_manager = struct {
        pub const interface: Interface = .{
            .name = "wl_data_device_manager",
            .version = 3,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "create_data_source",
                    .signature = "n",
                    .types = &.{
                        &wl.data_source.interface,
                    },
                },
                .{
                    .name = "get_data_device",
                    .signature = "no",
                    .types = &.{
                        &wl.data_device.interface,
                        &wl.seat.interface,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };
    pub const data_source = struct {
        pub const interface: Interface = .{
            .name = "wl_data_source",
            .version = 3,
            .method_count = 3,
            .methods = &.{
                .{
                    .name = "offer",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_actions",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 6,
            .events = &.{
                .{
                    .name = "target",
                    .signature = "?s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "send",
                    .signature = "sh",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "cancelled",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "dnd_drop_performed",
                    .signature = "3",
                    .types = null,
                },
                .{
                    .name = "dnd_finished",
                    .signature = "3",
                    .types = null,
                },
                .{
                    .name = "action",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };
    pub const data_device = struct {
        pub const interface: Interface = .{
            .name = "wl_data_device",
            .version = 3,
            .method_count = 3,
            .methods = &.{
                .{
                    .name = "start_drag",
                    .signature = "?oo?ou",
                    .types = &.{
                        &wl.data_source.interface,
                        &wl.surface.interface,
                        &wl.surface.interface,
                        null,
                    },
                },
                .{
                    .name = "set_selection",
                    .signature = "?ou",
                    .types = &.{
                        &wl.data_source.interface,
                        null,
                    },
                },
                .{
                    .name = "release",
                    .signature = "2",
                    .types = null,
                },
            },
            .event_count = 6,
            .events = &.{
                .{
                    .name = "data_offer",
                    .signature = "n",
                    .types = &.{
                        &wl.data_offer.interface,
                    },
                },
                .{
                    .name = "enter",
                    .signature = "uoff?o",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                        null,
                        null,
                        &wl.data_offer.interface,
                    },
                },
                .{
                    .name = "leave",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "motion",
                    .signature = "uff",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "drop",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "selection",
                    .signature = "?o",
                    .types = &.{
                        &wl.data_offer.interface,
                    },
                },
            },
        };
    };
    pub const data_offer = struct {
        pub const interface: Interface = .{
            .name = "wl_data_offer",
            .version = 3,
            .method_count = 5,
            .methods = &.{
                .{
                    .name = "accept",
                    .signature = "u?s",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "receive",
                    .signature = "sh",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "finish",
                    .signature = "3",
                    .types = null,
                },
                .{
                    .name = "set_actions",
                    .signature = "3uu",
                    .types = &.{
                        null,
                        null,
                    },
                },
            },
            .event_count = 3,
            .events = &.{
                .{
                    .name = "offer",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "source_actions",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "action",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };

    pub const shell = struct {
        pub const interface: Interface = .{
            .name = "wl_shell",
            .version = 1,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "get_shell_surface",
                    .signature = "no",
                    .types = &.{
                        &wl.shell_surface.interface,
                        &wl.surface.interface,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };
    pub const shell_surface = struct {
        pub const interface: Interface = .{
            .name = "wl_shell_surface",
            .version = 1,
            .method_count = 10,
            .methods = &.{
                .{
                    .name = "pong",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "move",
                    .signature = "ou",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                    },
                },
                .{
                    .name = "resize",
                    .signature = "ouu",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_toplevel",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_transient",
                    .signature = "oiiu",
                    .types = &.{
                        &wl.surface.interface,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_fullscreen",
                    .signature = "uu?o",
                    .types = &.{
                        null,
                        null,
                        &wl.output.interface,
                    },
                },
                .{
                    .name = "set_popup",
                    .signature = "ouoiiu",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                        &wl.surface.interface,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_maximized",
                    .signature = "?o",
                    .types = &.{
                        &wl.output.interface,
                    },
                },
                .{
                    .name = "set_title",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_class",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 3,
            .events = &.{
                .{
                    .name = "ping",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "configure",
                    .signature = "uii",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "popup_done",
                    .signature = "",
                    .types = null,
                },
            },
        };
    };

    pub const seat = struct {
        pub const interface: Interface = .{
            .name = "wl_seat",
            .version = 10,
            .method_count = 4,
            .methods = &.{
                .{
                    .name = "get_pointer",
                    .signature = "n",
                    .types = &.{
                        &wl.pointer.interface,
                    },
                },
                .{
                    .name = "get_keyboard",
                    .signature = "n",
                    .types = &.{
                        &wl.keyboard.interface,
                    },
                },
                .{
                    .name = "get_touch",
                    .signature = "n",
                    .types = &.{
                        &wl.touch.interface,
                    },
                },
                .{
                    .name = "release",
                    .signature = "5",
                    .types = null,
                },
            },
            .event_count = 2,
            .events = &.{
                .{
                    .name = "capabilities",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "name",
                    .signature = "2s",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };

    pub const pointer = struct {
        pub const interface: Interface = .{
            .name = "wl_pointer",
            .version = 10,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "set_cursor",
                    .signature = "u?oii",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "release",
                    .signature = "3",
                    .types = null,
                },
            },
            .event_count = 11,
            .events = &.{
                .{
                    .name = "enter",
                    .signature = "uoff",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "leave",
                    .signature = "uo",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "motion",
                    .signature = "uff",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "button",
                    .signature = "uuuu",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "axis",
                    .signature = "uuf",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "frame",
                    .signature = "5",
                    .types = null,
                },
                .{
                    .name = "axis_source",
                    .signature = "5u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "axis_stop",
                    .signature = "5uu",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "axis_discrete",
                    .signature = "5ui",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "axis_value120",
                    .signature = "8ui",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "axis_relative_direction",
                    .signature = "9uu",
                    .types = &.{
                        null,
                        null,
                    },
                },
            },
        };
    };

    pub const keyboard = struct {
        pub const interface: Interface = .{
            .name = "wl_keyboard",
            .version = 10,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "release",
                    .signature = "3",
                    .types = null,
                },
            },
            .event_count = 6,
            .events = &.{
                .{
                    .name = "keymap",
                    .signature = "uhu",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "enter",
                    .signature = "uoa",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                        null,
                    },
                },
                .{
                    .name = "leave",
                    .signature = "uo",
                    .types = &.{
                        null,
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "key",
                    .signature = "uuuu",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "modifiers",
                    .signature = "uuuuu",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "repeat_info",
                    .signature = "4ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
            },
        };
    };

    pub const touch = struct {
        pub const interface: Interface = .{
            .name = "wl_touch",
            .version = 10,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "release",
                    .signature = "3",
                    .types = null,
                },
            },
            .event_count = 7,
            .events = &.{
                .{
                    .name = "down",
                    .signature = "uuoiff",
                    .types = &.{
                        null,
                        null,
                        &wl.surface.interface,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "up",
                    .signature = "uui",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "motion",
                    .signature = "uiff",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "frame",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "cancel",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "shape",
                    .signature = "6iff",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "orientation",
                    .signature = "6if",
                    .types = &.{
                        null,
                        null,
                    },
                },
            },
        };
    };

    pub const output = struct {
        pub const interface: Interface = .{
            .name = "wl_output",
            .version = 4,
            .method_count = 1,
            .methods = &.{
                .{
                    .name = "release",
                    .signature = "3",
                    .types = null,
                },
            },
            .event_count = 6,
            .events = &.{
                .{
                    .name = "geometry",
                    .signature = "iiiiissi",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "mode",
                    .signature = "uiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "done",
                    .signature = "2",
                    .types = null,
                },
                .{
                    .name = "scale",
                    .signature = "2i",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "name",
                    .signature = "4s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "description",
                    .signature = "4s",
                    .types = &.{
                        null,
                    },
                },
            },
        };
    };

    pub const subcompositor = struct {
        pub const interface: Interface = .{
            .name = "wl_subcompositor",
            .version = 1,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "get_subsurface",
                    .signature = "noo",
                    .types = &.{
                        &wl.subsurface.interface,
                        &wl.surface.interface,
                        &wl.surface.interface,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };

    pub const subsurface = struct {
        pub const interface: Interface = .{
            .name = "wl_subsurface",
            .version = 1,
            .method_count = 6,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_position",
                    .signature = "ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "place_above",
                    .signature = "o",
                    .types = &.{
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "place_below",
                    .signature = "o",
                    .types = &.{
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "set_sync",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_desync",
                    .signature = "",
                    .types = null,
                },
            },
            .event_count = 0,
            .events = null,
        };
    };

    pub const fixes = struct {
        pub const interface: Interface = .{
            .name = "wl_fixes",
            .version = 1,
            .method_count = 2,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "destroy_registry",
                    .signature = "o",
                    .types = &.{
                        &wl.registry.interface,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };
    };
};

pub const xdg = struct {
    pub const wm_base = struct {
        pub const interface: Interface = .{
            .name = "xdg_wm_base",
            .version = 7,
            .method_count = 4,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "create_positioner",
                    .signature = "n",
                    .types = &.{
                        &xdg.positioner.interface,
                    },
                },
                .{
                    .name = "get_xdg_surface",
                    .signature = "no",
                    .types = &.{
                        &xdg.surface.interface,
                        &wl.surface.interface,
                    },
                },
                .{
                    .name = "pong",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 1,
            .events = &.{
                .{
                    .name = "ping",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };

        pub const Error = enum(c_int) {
            pub const role_since_version = 1;
            pub const defunct_surfaces_since_version = 1;
            pub const not_the_topmost_popup_since_version = 1;
            pub const invalid_popup_parent_since_version = 1;
            pub const invalid_surface_state_since_version = 1;
            pub const invalid_positioner_since_version = 1;
            pub const unresponsive_since_version = 1;

            role = 0,
            defunct_surfaces = 1,
            not_the_topmost_popup = 2,
            invalid_popup_parent = 3,
            invalid_surface_state = 4,
            invalid_positioner = 5,
            unresponsive = 6,
            _,
        };
    };

    pub const positioner = struct {
        pub const interface: Interface = .{
            .name = "xdg_positioner",
            .version = 7,
            .method_count = 10,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_size",
                    .signature = "ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_anchor_rect",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_anchor",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_gravity",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_pub constraint_adjustment",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_offset",
                    .signature = "ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_reactive",
                    .signature = "3",
                    .types = null,
                },
                .{
                    .name = "set_parent_size",
                    .signature = "3ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_parent_configure",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 0,
            .events = null,
        };

        pub const Error = enum(c_int) {
            pub const invalid_input_since_version = 1;

            invalid_input = 0,
            _,
        };

        pub const Anchor = enum(c_int) {
            pub const none_since_version = 1;
            pub const top_since_version = 1;
            pub const bottom_since_version = 1;
            pub const left_since_version = 1;
            pub const right_since_version = 1;
            pub const top_left_since_version = 1;
            pub const bottom_left_since_version = 1;
            pub const top_right_since_version = 1;
            pub const bottom_right_since_version = 1;

            none = 0,
            top = 1,
            bottom = 2,
            left = 3,
            right = 4,
            top_left = 5,
            bottom_left = 6,
            top_right = 7,
            bottom_right = 8,
            _,
        };

        pub const Gravity = enum(c_int) {
            pub const none_since_version = 1;
            pub const top_since_version = 1;
            pub const bottom_since_version = 1;
            pub const left_since_version = 1;
            pub const right_since_version = 1;
            pub const top_left_since_version = 1;
            pub const bottom_left_since_version = 1;
            pub const top_right_since_version = 1;
            pub const bottom_right_since_version = 1;

            none = 0,
            top = 1,
            bottom = 2,
            left = 3,
            right = 4,
            top_left = 5,
            bottom_left = 6,
            top_right = 7,
            bottom_right = 8,
            _,
        };

        /// The pub constraint adjustment value define ways the compositor will adjust
        /// the position of the surface, if the unadjusted position would result
        /// in the surface being partly pub constrained.
        ///
        /// Whether a surface is considered 'pub constrained' is left to the compositor
        /// to determine. For example, the surface may be partly outside the
        /// compositor's defined 'work area', thus necessitating the child surface's
        /// position be adjusted until it is entirely inside the work area.
        ///
        /// The adjustments can be combined, according to a defined precedence: 1)
        /// Flip, 2) Slide, 3) Resize.
        pub const ConstraintAdjustment = packed struct(u32) {
            pub const none_since_version = 1;
            pub const slide_x_since_version = 1;
            pub const slide_y_since_version = 1;
            pub const flip_x_since_version = 1;
            pub const flip_y_since_version = 1;
            pub const resize_x_since_version = 1;
            pub const resize_y_since_version = 1;

            slide_x: bool = false,
            slide_y: bool = false,
            flip_x: bool = false,
            flip_y: bool = false,
            resize_x: bool = false,
            resize_y: bool = false,
            _padding6: bool = false,
            _padding7: bool = false,
            _padding8: bool = false,
            _padding9: bool = false,
            _padding10: bool = false,
            _padding11: bool = false,
            _padding12: bool = false,
            _padding13: bool = false,
            _padding14: bool = false,
            _padding15: bool = false,
            _padding16: bool = false,
            _padding17: bool = false,
            _padding18: bool = false,
            _padding19: bool = false,
            _padding20: bool = false,
            _padding21: bool = false,
            _padding22: bool = false,
            _padding23: bool = false,
            _padding24: bool = false,
            _padding25: bool = false,
            _padding26: bool = false,
            _padding27: bool = false,
            _padding28: bool = false,
            _padding29: bool = false,
            _padding30: bool = false,
            _padding31: bool = false,
            pub const Enum = enum(c_int) {
                pub const none_since_version = 1;
                pub const slide_x_since_version = 1;
                pub const slide_y_since_version = 1;
                pub const flip_x_since_version = 1;
                pub const flip_y_since_version = 1;
                pub const resize_x_since_version = 1;
                pub const resize_y_since_version = 1;

                none = 0,
                slide_x = 1,
                slide_y = 2,
                flip_x = 4,
                flip_y = 8,
                resize_x = 16,
                resize_y = 32,
                _,
            };
        };
    };

    pub const surface = struct {
        pub const interface: Interface = .{
            .name = "xdg_surface",
            .version = 7,
            .method_count = 5,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "get_toplevel",
                    .signature = "n",
                    .types = &.{
                        &xdg.toplevel.interface,
                    },
                },
                .{
                    .name = "get_popup",
                    .signature = "n?oo",
                    .types = &.{
                        &xdg.popup.interface,
                        &xdg.surface.interface,
                        &xdg.positioner.interface,
                    },
                },
                .{
                    .name = "set_window_geometry",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "ack_configure",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
            .event_count = 1,
            .events = &.{
                .{
                    .name = "configure",
                    .signature = "u",
                    .types = &.{
                        null,
                    },
                },
            },
        };

        pub const Error = enum(c_int) {
            pub const not_constructed_since_version = 1;
            pub const already_constructed_since_version = 1;
            pub const unconfigured_buffer_since_version = 1;
            pub const invalid_serial_since_version = 1;
            pub const invalid_size_since_version = 1;
            pub const defunct_role_object_since_version = 1;

            not_constructed = 1,
            already_constructed = 2,
            unconfigured_buffer = 3,
            invalid_serial = 4,
            invalid_size = 5,
            defunct_role_object = 6,
            _,
        };
    };

    pub const toplevel = struct {
        pub const interface: Interface = .{
            .name = "xdg_toplevel",
            .version = 7,
            .method_count = 14,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_parent",
                    .signature = "?o",
                    .types = &.{
                        &xdg.toplevel.interface,
                    },
                },
                .{
                    .name = "set_title",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "set_app_id",
                    .signature = "s",
                    .types = &.{
                        null,
                    },
                },
                .{
                    .name = "show_window_menu",
                    .signature = "ouii",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "move",
                    .signature = "ou",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                    },
                },
                .{
                    .name = "resize",
                    .signature = "ouu",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_max_size",
                    .signature = "ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_min_size",
                    .signature = "ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "set_maximized",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "unset_maximized",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_fullscreen",
                    .signature = "?o",
                    .types = &.{
                        &wl.output.interface,
                    },
                },
                .{
                    .name = "unset_fullscreen",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "set_minimized",
                    .signature = "",
                    .types = null,
                },
            },
            .event_count = 4,
            .events = &.{
                .{
                    .name = "configure",
                    .signature = "iia",
                    .types = &.{
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "close",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "configure_bounds",
                    .signature = "4ii",
                    .types = &.{
                        null,
                        null,
                    },
                },
                .{
                    .name = "wm_capabilities",
                    .signature = "5a",
                    .types = &.{
                        null,
                    },
                },
            },
        };

        pub const Error = enum(c_int) {
            pub const invalid_resize_edge_since_version = 1;
            pub const invalid_parent_since_version = 1;
            pub const invalid_size_since_version = 1;

            invalid_resize_edge = 0,
            invalid_parent = 1,
            invalid_size = 2,
            _,
        };

        /// These values are used to indicate which edge of a surface
        /// is being dragged in a resize operation.
        pub const ResizeEdge = enum(c_int) {
            pub const none_since_version = 1;
            pub const top_since_version = 1;
            pub const bottom_since_version = 1;
            pub const left_since_version = 1;
            pub const top_left_since_version = 1;
            pub const bottom_left_since_version = 1;
            pub const right_since_version = 1;
            pub const top_right_since_version = 1;
            pub const bottom_right_since_version = 1;

            none = 0,
            top = 1,
            bottom = 2,
            left = 4,
            top_left = 5,
            bottom_left = 6,
            right = 8,
            top_right = 9,
            bottom_right = 10,
            _,
        };

        /// The different state values used on the surface. This is designed for
        /// state values like maximized, fullscreen. It is paired with the
        /// configure event to ensure that both the client and the compositor
        /// setting the state can be synchronized.
        ///
        /// States set in this way are double-buffered, see wl_surface.commit.
        pub const State = enum(c_int) {
            pub const maximized_since_version = 1;
            pub const fullscreen_since_version = 1;
            pub const resizing_since_version = 1;
            pub const activated_since_version = 1;

            maximized = 1,
            fullscreen = 2,
            resizing = 3,
            activated = 4,
            _,
        };
    };

    pub const popup = struct {
        pub const interface: Interface = .{
            .name = "xdg_popup",
            .version = 7,
            .method_count = 3,
            .methods = &.{
                .{
                    .name = "destroy",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "grab",
                    .signature = "ou",
                    .types = &.{
                        &wl.seat.interface,
                        null,
                    },
                },
                .{
                    .name = "reposition",
                    .signature = "3ou",
                    .types = &.{
                        &xdg.positioner.interface,
                        null,
                    },
                },
            },
            .event_count = 3,
            .events = &.{
                .{
                    .name = "configure",
                    .signature = "iiii",
                    .types = &.{
                        null,
                        null,
                        null,
                        null,
                    },
                },
                .{
                    .name = "popup_done",
                    .signature = "",
                    .types = null,
                },
                .{
                    .name = "repositioned",
                    .signature = "3u",
                    .types = &.{
                        null,
                    },
                },
            },
        };
        pub const Error = enum(c_int) {
            pub const invalid_grab_since_version = 1;

            invalid_grab = 0,
            _,
        };
    };
};

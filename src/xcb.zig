const std = @import("std");
const c = std.c;
const base = @import("base.zig");
const Event = base.Event;
const Rect = base.Rect;
const Point = base.Point;
const Cursor = base.Cursor;
const Error = base.Error;

const xcb = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_cursor.h");
});

pub const Window = struct {
    width: u16,
    height: u16,
    flags: u3 = 0b1,

    // Platform specific
    connection: *xcb.xcb_connection_t,
    window: xcb.xcb_window_t,
    screen: *xcb.xcb_screen_t,
    delete_window_atom: xcb.xcb_atom_t,

    pub fn create(name: []const u8, width: u16, height: u16) !Window {
        const connection = xcb.xcb_connect(null, null).?;

        if (xcb.xcb_connection_has_error(connection) != 0) {
            return Error.FailedToCreateWindow;
        }

        const screen = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(connection)).data;

        const window = xcb.xcb_generate_id(connection);

        const mask = xcb.XCB_CW_BACK_PIXEL | xcb.XCB_CW_EVENT_MASK;
        const values = [2]u32{
            screen.*.white_pixel,

            xcb.XCB_EVENT_MASK_EXPOSURE | xcb.XCB_EVENT_MASK_STRUCTURE_NOTIFY |
                xcb.XCB_EVENT_MASK_ENTER_WINDOW | xcb.XCB_EVENT_MASK_LEAVE_WINDOW |
                xcb.XCB_EVENT_MASK_KEY_PRESS | xcb.XCB_EVENT_MASK_KEY_RELEASE |
                xcb.XCB_EVENT_MASK_BUTTON_PRESS | xcb.XCB_EVENT_MASK_BUTTON_RELEASE |
                xcb.XCB_EVENT_MASK_POINTER_MOTION | xcb.XCB_EVENT_MASK_FOCUS_CHANGE,
        };

        _ = xcb.xcb_create_window(
            connection,
            xcb.XCB_COPY_FROM_PARENT,
            window,
            screen.*.root,
            10,
            10,
            width,
            height,
            1,
            xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            mask,
            &values[0],
        );

        // Setup window destruction
        const protocols_reply = xcb.xcb_intern_atom_reply(
            connection,
            xcb.xcb_intern_atom(connection, 1, "WM_PROTOCOLS".len, "WM_PROTOCOLS"),
            null,
        );
        defer c.free(protocols_reply);

        const delete_window_reply = xcb.xcb_intern_atom_reply(
            connection,
            xcb.xcb_intern_atom(connection, 0, "WM_DELETE_WINDOW".len, "WM_DELETE_WINDOW"),
            null,
        );
        defer c.free(delete_window_reply);

        const delete_window_atom = delete_window_reply.*.atom;
        _ = xcb.xcb_change_property(
            connection,
            xcb.XCB_PROP_MODE_REPLACE,
            window,
            protocols_reply.*.atom,
            4,
            32,
            1,
            &delete_window_atom,
        );

        // Set window name
        _ = xcb.xcb_change_property(
            connection,
            xcb.XCB_PROP_MODE_REPLACE,
            window,
            xcb.XCB_ATOM_WM_NAME,
            xcb.XCB_ATOM_STRING,
            8,
            @intCast(u32, name.len),
            &name[0],
        );

        _ = xcb.xcb_map_window(connection, window);
        _ = xcb.xcb_flush(connection);

        return Window{
            .width = width,
            .height = height,
            .connection = connection,
            .window = window,
            .screen = screen,
            .delete_window_atom = delete_window_atom,
        };
    }

    pub fn destroy(self: Window) void {
        _ = xcb.xcb_destroy_window(self.connection, self.window);
        xcb.xcb_disconnect(self.connection);
    }

    pub fn isOpen(self: Window) bool {
        return 0b1 & self.flags == 0b1;
    }

    pub fn isFullscreen(self: Window) bool {
        return 0b10 & self.flags == 0b10;
    }

    pub fn isCursorLocked(self: Window) bool {
        return 0b100 & self.flags == 0b100;
    }

    pub fn getName(self: Window, allocator: *std.mem.Allocator) ![]const u8 {
        const reply = xcb.xcb_get_property_reply(
            self.connection,
            xcb.xcb_get_property(self.connection, 0, self.window, xcb.XCB_ATOM_WM_NAME, xcb.XCB_ATOM_STRING, 0, 100),
            null,
        );
        defer c.free(reply);
        const ptr = @ptrCast([*]u8, xcb.xcb_get_property_value(reply));
        const size = @intCast(usize, xcb.xcb_get_property_value_length(reply));
        var name = try allocator.alloc(u8, size);
        for (ptr[0..size], 0..) |b, i| name[i] = b;
        return name;
    }

    pub fn setName(self: Window, name: []const u8) void {
        _ = xcb.xcb_change_property(
            self.connection,
            xcb.XCB_PROP_MODE_REPLACE,
            self.window,
            xcb.XCB_ATOM_WM_NAME,
            xcb.XCB_ATOM_STRING,
            8,
            @intCast(u32, name.len),
            &name[0],
        );
        _ = xcb.xcb_flush(self.connection);
    }

    pub fn setSize(self: Window, width: u16, height: u16) void {
        if (self.is_fullscreen()) return;

        _ = xcb.xcb_unmap_window(self.connection, self.window);

        _ = xcb.xcb_configure_window(self.connection, self.window, xcb.XCB_CONFIG_WINDOW_WIDTH, &width);

        _ = xcb.xcb_configure_window(self.connection, self.window, xcb.XCB_CONFIG_WINDOW_HEIGHT, &height);

        _ = xcb.xcb_map_window(self.connection, self.window);
        _ = xcb.xcb_flush(self.connection);
    }

    pub fn setFullscreen(self: *Window, comptime fullscreen: bool) void {
        if (self.isFullscreen() == fullscreen) return;

        if (fullscreen) self.*.flags |= 0b10 else self.*.flags &= 0b101;

        _ = xcb.xcb_unmap_window(self.*.connection, self.*.window);

        if (fullscreen) {
            const atom_wm_state = xcb.xcb_intern_atom_reply(
                self.*.connection,
                xcb.xcb_intern_atom(self.*.connection, 0, "_NET_WM_STATE".len, "_NET_WM_STATE"),
                null,
            );
            defer c.free(atom_wm_state);

            const atom_wm_fullscreen = xcb.xcb_intern_atom_reply(
                self.*.connection,
                xcb.xcb_intern_atom(self.*.connection, 0, "_NET_WM_STATE_FULLSCREEN".len, "_NET_WM_STATE_FULLSCREEN"),
                null,
            );
            defer c.free(atom_wm_fullscreen);

            _ = xcb.xcb_change_property(
                self.*.connection,
                xcb.XCB_PROP_MODE_REPLACE,
                self.*.window,
                atom_wm_state.*.atom,
                xcb.XCB_ATOM_ATOM,
                32,
                1,
                &(atom_wm_fullscreen.*.atom),
            );
        }

        _ = xcb.xcb_map_window(self.*.connection, self.*.window);
        _ = xcb.xcb_flush(self.*.connection);

        // TODO: width and height struct members are currently not synced with actual height until resize event is handled
    }

    pub fn setCursorIcon(self: Window, cursor_icon: Cursor) void {
        var context: *allowzero xcb.xcb_cursor_context_t = undefined;

        // TODO: Handle error
        _ = xcb.xcb_cursor_context_new(self.connection, self.screen, &context);
        defer xcb.xcb_cursor_context_free(context);

        const cursor_image = switch (cursor_icon) {
            .Arrow => xcb.xcb_cursor_load_cursor(context, "arrow"),
            .Hand => xcb.xcb_cursor_load_cursor(context, "hand1"),
            .Text => xcb.xcb_cursor_load_cursor(context, "ibeam"),
            .ResizeAll => xcb.xcb_cursor_load_cursor(context, "size_all"),
            .ResizeEW => xcb.xcb_cursor_load_cursor(context, "size_hor"),
            .ResizeNS => xcb.xcb_cursor_load_cursor(context, "size_ver"),
            .ResizeNESW => xcb.xcb_cursor_load_cursor(context, "size_bdiag"),
            .ResizeNWSE => xcb.xcb_cursor_load_cursor(context, "size_fdiag"),
            .Loading => xcb.xcb_cursor_load_cursor(context, "wait"),
        };

        _ = xcb.xcb_change_window_attributes(self.connection, self.window, xcb.XCB_CW_CURSOR, &cursor_image);
        _ = xcb.xcb_flush(self.connection);
    }

    pub fn showCursor(self: Window) void {
        self.set_cursor_icon(.Arrow);
    }

    pub fn hideCursor(self: Window) void {
        const empty_cursor = xcb.xcb_generate_id(self.connection);
        defer _ = xcb.xcb_free_cursor(self.connection, empty_cursor);

        const pix = xcb.xcb_generate_id(self.connection);
        defer _ = xcb.xcb_free_pixmap(self.connection, pix);
        {
            const cookie = xcb.xcb_create_pixmap_checked(self.connection, 1, pix, self.screen.*.root, 1, 1);
            // TODO: handle error
            const err = xcb.xcb_request_check(self.connection, cookie);
            if (err != null) c.free(err);
        }

        {
            const cookie = xcb.xcb_create_cursor_checked(self.connection, empty_cursor, pix, pix, 0, 0, 0, 0, 0, 0, 0, 0);
            const err = xcb.xcb_request_check(self.connection, cookie);
            if (err != null) c.free(err);
        }

        _ = xcb.xcb_change_window_attributes(self.connection, self.window, xcb.XCB_CW_CURSOR, &empty_cursor);
        _ = xcb.xcb_flush(self.connection);
    }

    fn handleEvent(event_handler: anytype, event: Event) base.GetEventHandlerReturnType(@TypeOf(event_handler)) {
        return switch (@typeInfo(@TypeOf(event_handler))) {
            .Fn => event_handler(event),
            .Pointer => @field(event_handler, base.event_handler_name)(event),
            .Struct => @field(event_handler, base.event_handler_name)(event),
            // This branch will never be reached because GetEventHandlerReturnType would've already thrown a compiler error
            else => unreachable,
        };
    }

    pub fn handleEvents(self: *Window, event_handler: anytype) base.GetEventHandlerReturnType(@TypeOf(event_handler)) {
        var current = xcb.xcb_poll_for_event(self.*.connection);
        const event_handler_error = base.GetEventHandlerReturnType(@TypeOf(event_handler)) != void;

        if (current != null) {
            var previous: ?*xcb.xcb_generic_event_t = null;
            var next = xcb.xcb_poll_for_event(self.*.connection);

            while (current != null) {
                if (self.proccessEvent(
                    current,
                    next,
                    previous,
                )) |event| if (event_handler_error) try handleEvent(event_handler, event) else handleEvent(event_handler, event);

                if (previous != null) c.free(previous.?);
                previous = current;
                current = next;

                if (current != null) next = xcb.xcb_poll_for_event(self.*.connection);
            }
        }
    }

    fn proccessEvent(
        self: *Window,
        current: *xcb.xcb_generic_event_t,
        next: ?*xcb.xcb_generic_event_t,
        previous: ?*xcb.xcb_generic_event_t,
    ) ?Event {
        switch (@intCast(i16, current.*.response_type) & (-0x80 - 1)) {
            xcb.XCB_CLIENT_MESSAGE => {
                const client_event = @ptrCast([*c]xcb.xcb_client_message_event_t, current);
                if (client_event.*.data.data32[0] == self.delete_window_atom) {
                    self.*.flags &= 0b110;
                    return Event.Destroy;
                }
            },
            xcb.XCB_CONFIGURE_NOTIFY => {
                const config_event = @ptrCast([*c]xcb.xcb_configure_notify_event_t, current);
                if (config_event.*.width != self.width or config_event.*.height != self.height) {
                    self.width = config_event.*.width;
                    self.height = config_event.*.height;
                    return Event{ .Resize = Rect{ .width = self.width, .height = self.height } };
                }
            },
            xcb.XCB_LEAVE_NOTIFY => {},
            xcb.XCB_FOCUS_IN => return Event.FocusIn,
            xcb.XCB_FOCUS_OUT => return Event.FocusOut,
            xcb.XCB_KEY_PRESS => {
                const key_event = @ptrCast([*c]xcb.xcb_key_press_event_t, current);
                const prev_event = @ptrCast([*c]xcb.xcb_key_release_event_t, previous);
                if (!(previous != null and ((@intCast(i16, previous.?.*.response_type) & (-0x80 - 1)) == xcb.XCB_KEY_RELEASE) and
                    (prev_event.*.detail == key_event.*.detail) and
                    (prev_event.*.time == key_event.*.time)))
                {
                    return Event{ .KeyPress = base.keycodeToEnum(key_event.*.detail) };
                }
            },
            xcb.XCB_KEY_RELEASE => {
                const key_event = @ptrCast([*c]xcb.xcb_key_release_event_t, current);
                const next_event = @ptrCast([*c]xcb.xcb_key_press_event_t, next);
                if (!(next != null and ((@intCast(i16, next.?.*.response_type) & (-0x80 - 1)) == xcb.XCB_KEY_PRESS) and
                    (next_event.*.detail == key_event.*.detail) and
                    (next_event.*.time == key_event.*.time)))
                {
                    return Event{ .KeyRelease = base.keycodeToEnum(key_event.*.detail) };
                }
            },
            xcb.XCB_BUTTON_PRESS => {
                const button_event = @ptrCast([*c]xcb.xcb_button_press_event_t, current);
                switch (button_event.*.detail) {
                    4 => return Event{ .MouseScrollV = 1 },
                    5 => return Event{ .MouseScrollV = -1 },
                    6 => return Event{ .MouseScrollH = 1 },
                    7 => return Event{ .MouseScrollH = -1 },
                    else => return Event{ .MousePress = base.mousecodeToEnum(button_event.*.detail) },
                }
            },
            xcb.XCB_BUTTON_RELEASE => {
                const button_event = @ptrCast([*c]xcb.xcb_button_release_event_t, current);
                if (button_event.*.detail != 4 and button_event.*.detail != 5) {
                    return Event{
                        .MouseRelease = base.mousecodeToEnum(button_event.*.detail),
                    };
                }
            },
            xcb.XCB_MOTION_NOTIFY => {
                const motion_event = @ptrCast([*c]xcb.xcb_motion_notify_event_t, current);
                return Event{
                    .MouseMove = Point{
                        .x = motion_event.*.event_x,
                        .y = motion_event.*.event_y,
                    },
                };
            },
            else => {},
        }
        return null;
    }
};

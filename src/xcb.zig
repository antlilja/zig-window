const std = @import("std");
const c = std.c;
pub usingnamespace @import("base.zig");

usingnamespace @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_cursor.h");
});

pub const Window = struct {
    width: u16,
    height: u16,
    flags: u3 = 0b1,
    event_handler: fn (Event) void,

    // Platform specific
    connection: *xcb_connection_t,
    window: xcb_window_t,
    screen: *xcb_screen_t,
    delete_window_atom: xcb_atom_t,

    pub fn create(name: []const u8, width: u16, height: u16, event_handler: fn (Event) void) !Window {
        const connection = xcb_connect(null, null).?;

        if (xcb_connection_has_error(connection) != 0) {
            return Error.FailedToCreateWindow;
        }

        const screen = xcb_setup_roots_iterator(xcb_get_setup(connection)).data;

        const window = xcb_generate_id(connection);

        const mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
        const values = [2]u32{
            screen.*.white_pixel,

            XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_STRUCTURE_NOTIFY |
                XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_LEAVE_WINDOW |
                XCB_EVENT_MASK_KEY_PRESS | XCB_EVENT_MASK_KEY_RELEASE |
                XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE |
                XCB_EVENT_MASK_POINTER_MOTION | XCB_EVENT_MASK_FOCUS_CHANGE,
        };

        _ = xcb_create_window(
            connection,
            XCB_COPY_FROM_PARENT,
            window,
            screen.*.root,
            10,
            10,
            width,
            height,
            1,
            XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            mask,
            &values[0],
        );

        // Setup window destruction
        const protocols_reply = xcb_intern_atom_reply(
            connection,
            xcb_intern_atom(connection, 1, "WM_PROTOCOLS".len, "WM_PROTOCOLS"),
            null,
        );
        defer c.free(protocols_reply);

        const delete_window_reply = xcb_intern_atom_reply(
            connection,
            xcb_intern_atom(connection, 0, "WM_DELETE_WINDOW".len, "WM_DELETE_WINDOW"),
            null,
        );
        defer c.free(delete_window_reply);

        const delete_window_atom = delete_window_reply.*.atom;
        _ = xcb_change_property(
            connection,
            XCB_PROP_MODE_REPLACE,
            window,
            protocols_reply.*.atom,
            4,
            32,
            1,
            &delete_window_atom,
        );

        // Set window name
        _ = xcb_change_property(
            connection,
            XCB_PROP_MODE_REPLACE,
            window,
            XCB_ATOM_WM_NAME,
            XCB_ATOM_STRING,
            8,
            @intCast(u32, name.len),
            &name[0],
        );

        _ = xcb_map_window(connection, window);
        _ = xcb_flush(connection);

        return Window{
            .width = width,
            .height = height,
            .event_handler = event_handler,
            .connection = connection,
            .window = window,
            .screen = screen,
            .delete_window_atom = delete_window_atom,
        };
    }

    pub fn destroy(self: Window) void {
        _ = xcb_destroy_window(self.connection, self.window);
        xcb_disconnect(self.connection);
    }

    pub fn is_open(self: Window) bool {
        return 0b1 & self.flags == 0b1;
    }

    pub fn is_fullscreen(self: Window) bool {
        return 0b10 & self.flags == 0b10;
    }

    pub fn is_cursor_locked(self: Window) bool {
        return 0b100 & self.flags == 0b100;
    }

    pub fn get_name(self: Window, allocator: *std.mem.Allocator) ![]const u8 {
        const reply = xcb_get_property_reply(
            self.connection,
            xcb_get_property(self.connection, 0, self.window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 0, 100),
            null,
        );
        defer c.free(reply);
        const ptr = @ptrCast([*]u8, xcb_get_property_value(reply));
        const size = @intCast(usize, xcb_get_property_value_length(reply));
        var name = try allocator.alloc(u8, size);
        for (ptr[0..size]) |b, i| name[i] = b;
        return name;
    }

    pub fn set_name(self: Window, name: []const u8) void {
        _ = xcb_change_property(
            self.connection,
            XCB_PROP_MODE_REPLACE,
            self.window,
            XCB_ATOM_WM_NAME,
            XCB_ATOM_STRING,
            8,
            @intCast(u32, name.len),
            &name[0],
        );
        _ = xcb_flush(self.connection);
    }

    pub fn set_size(self: Window, width: u16, height: u16) void {
        if (self.is_fullscreen()) return;

        _ = xcb_unmap_window(self.connection, self.window);

        _ = xcb_configure_window(self.connection, self.window, XCB_CONFIG_WINDOW_WIDTH, &width);

        _ = xcb_configure_window(self.connection, self.window, XCB_CONFIG_WINDOW_HEIGHT, &height);

        _ = xcb_map_window(self.connection, self.window);
        _ = xcb_flush(self.connection);
    }

    pub fn set_fullscreen(self: *Window, comptime fullscreen: bool) void {
        if (self.is_fullscreen() == fullscreen) return;

        if (fullscreen) self.*.flags |= 0b10 else self.*.flags &= 0b101;

        _ = xcb_unmap_window(self.*.connection, self.*.window);

        if (fullscreen) {
            const atom_wm_state = xcb_intern_atom_reply(
                self.*.connection,
                xcb_intern_atom(self.*.connection, @boolToInt(false), "_NET_WM_STATE".len, "_NET_WM_STATE"),
                null,
            );
            defer c.free(atom_wm_state);

            const atom_wm_fullscreen = xcb_intern_atom_reply(
                self.*.connection,
                xcb_intern_atom(self.*.connection, @boolToInt(false), "_NET_WM_STATE_FULLSCREEN".len, "_NET_WM_STATE_FULLSCREEN"),
                null,
            );
            defer c.free(atom_wm_fullscreen);

            _ = xcb_change_property(
                self.*.connection,
                XCB_PROP_MODE_REPLACE,
                self.*.window,
                atom_wm_state.*.atom,
                XCB_ATOM_ATOM,
                32,
                1,
                &(atom_wm_fullscreen.*.atom),
            );
        }

        _ = xcb_map_window(self.*.connection, self.*.window);
        _ = xcb_flush(self.*.connection);

        // TODO: width and height struct members are currently not synced with actual height until resize event is handled
    }

    pub fn set_cursor_icon(self: Window, cursor_icon: Cursor) void {
        var context: *allowzero xcb_cursor_context_t = undefined;

        // TODO: Handle error
        _ = xcb_cursor_context_new(self.connection, self.screen, &context);
        defer xcb_cursor_context_free(context);

        const cursor_image = switch (cursor_icon) {
            .Arrow => xcb_cursor_load_cursor(context, "arrow"),
            .Hand => xcb_cursor_load_cursor(context, "hand1"),
            .Text => xcb_cursor_load_cursor(context, "ibeam"),
            .ResizeAll => xcb_cursor_load_cursor(context, "size_all"),
            .ResizeEW => xcb_cursor_load_cursor(context, "size_hor"),
            .ResizeNS => xcb_cursor_load_cursor(context, "size_ver"),
            .ResizeNESW => xcb_cursor_load_cursor(context, "size_bdiag"),
            .ResizeNWSE => xcb_cursor_load_cursor(context, "size_fdiag"),
            .Loading => xcb_cursor_load_cursor(context, "wait"),
        };

        _ = xcb_change_window_attributes(self.connection, self.window, XCB_CW_CURSOR, &cursor_image);
        _ = xcb_flush(self.connection);
    }

    pub fn show_cursor(self: Window) void {
        self.set_cursor_icon(.Arrow);
    }

    pub fn hide_cursor(self: Window) void {
        const empty_cursor = xcb_generate_id(self.connection);
        defer _ = xcb_free_cursor(self.connection, empty_cursor);

        const pix = xcb_generate_id(self.connection);
        defer _ = xcb_free_pixmap(self.connection, pix);
        {
            const cookie = xcb_create_pixmap_checked(self.connection, 1, pix, self.screen.*.root, 1, 1);
            // TODO: handle error
            const err = xcb_request_check(self.connection, cookie);
            if (err != null) c.free(err);
        }

        {
            const cookie = xcb_create_cursor_checked(self.connection, empty_cursor, pix, pix, 0, 0, 0, 0, 0, 0, 0, 0);
            const err = xcb_request_check(self.connection, cookie);
            if (err != null) c.free(err);
        }

        _ = xcb_change_window_attributes(self.connection, self.window, XCB_CW_CURSOR, &empty_cursor);
        _ = xcb_flush(self.connection);
    }

    pub fn handle_events(self: *Window) void {
        var current = xcb_poll_for_event(self.*.connection);

        if (current != null) {
            var previous: ?*xcb_generic_event_t = null;
            var next = xcb_poll_for_event(self.*.connection);
            while (next != null) {
                self.proccess_event(current, next, previous);

                if (previous != null) c.free(previous.?);
                previous = current;
                current = next;
                next = xcb_poll_for_event(self.*.connection);
            }
            self.proccess_event(current, next, previous);
        }
    }

    fn proccess_event(
        self: *Window,
        current: *xcb_generic_event_t,
        next: ?*xcb_generic_event_t,
        previous: ?*xcb_generic_event_t,
    ) void {
        switch (@intCast(i16, current.*.response_type) & (-0x80 - 1)) {
            XCB_CLIENT_MESSAGE => {
                const client_event = @ptrCast([*c]xcb_client_message_event_t, current);
                if (client_event.*.data.data32[0] == self.delete_window_atom) {
                    self.*.flags &= 0b110;
                    self.event_handler(Event.Destroy);
                }
            },
            XCB_CONFIGURE_NOTIFY => {
                const config_event = @ptrCast([*c]xcb_configure_notify_event_t, current);
                if (config_event.*.width != self.width or config_event.*.height != self.height) {
                    self.width = config_event.*.width;
                    self.height = config_event.*.height;
                    self.event_handler(Event{ .Resize = Rect{ .width = self.width, .height = self.height } });
                }
            },
            XCB_LEAVE_NOTIFY => {},
            XCB_FOCUS_IN => self.event_handler(Event.FocusIn),
            XCB_FOCUS_OUT => self.event_handler(Event.FocusOut),
            XCB_KEY_PRESS => {
                const key_event = @ptrCast([*c]xcb_key_press_event_t, current);
                const prev_event = @ptrCast([*c]xcb_key_release_event_t, previous);
                if (!(previous != null and ((@intCast(i16, previous.?.*.response_type) & (-0x80 - 1)) == XCB_KEY_RELEASE) and
                    (prev_event.*.detail == key_event.*.detail) and
                    (prev_event.*.time == key_event.*.time)))
                {
                    self.event_handler(Event{ .KeyPress = keycode_to_enum(key_event.*.detail) });
                }
            },
            XCB_KEY_RELEASE => {
                const key_event = @ptrCast([*c]xcb_key_release_event_t, current);
                const next_event = @ptrCast([*c]xcb_key_press_event_t, next);
                if (!(next != null and ((@intCast(i16, next.?.*.response_type) & (-0x80 - 1)) == XCB_KEY_PRESS) and
                    (next_event.*.detail == key_event.*.detail) and
                    (next_event.*.time == key_event.*.time)))
                {
                    self.event_handler(Event{ .KeyRelease = keycode_to_enum(key_event.*.detail) });
                }
            },
            XCB_BUTTON_PRESS => {
                const button_event = @ptrCast([*c]xcb_button_press_event_t, current);
                switch (button_event.*.detail) {
                    4 => self.event_handler(Event{ .MouseScrollV = 1 }),
                    5 => self.event_handler(Event{ .MouseScrollV = -1 }),
                    6 => self.event_handler(Event{ .MouseScrollH = 1 }),
                    7 => self.event_handler(Event{ .MouseScrollH = -1 }),
                    else => self.event_handler(Event{ .MousePress = mousecode_to_enum(button_event.*.detail) }),
                }
            },
            XCB_BUTTON_RELEASE => {
                const button_event = @ptrCast([*c]xcb_button_release_event_t, current);
                if (button_event.*.detail != 4 and button_event.*.detail != 5) {
                    self.event_handler(Event{
                        .MouseRelease = mousecode_to_enum(button_event.*.detail),
                    });
                }
            },
            XCB_MOTION_NOTIFY => {
                const motion_event = @ptrCast([*c]xcb_motion_notify_event_t, current);
                self.event_handler(Event{
                    .MouseMove = Point{
                        .x = motion_event.*.event_x,
                        .y = motion_event.*.event_y,
                    },
                });
            },
            else => {},
        }
    }
};

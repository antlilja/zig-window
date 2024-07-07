const Event = @import("base.zig").Event;

const Self = @This();

handle: ?*anyopaque,

handle_event_fn: *const fn (?*anyopaque, Event) void,

pub fn handleEvent(self: Self, event: Event) void {
    self.handle_event_fn(self.handle, event);
}

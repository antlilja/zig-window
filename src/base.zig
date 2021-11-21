const std = @import("std");

pub const Key = enum {
    Zero,
    One,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Numpad0,
    Numpad1,
    Numpad2,
    Numpad3,
    Numpad4,
    Numpad5,
    Numpad6,
    Numpad7,
    Numpad8,
    Numpad9,
    NumpadDecimal,
    NumpadAdd,
    NumpadSubtract,
    NumpadMultiply,
    NumpadDivide,
    NumpadLock,
    NumpadEnter,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    Up,
    Down,
    Right,
    Left,
    Period,
    Comma,
    LeftShift,
    RightShift,
    LeftCtrl,
    RightCtrl,
    LeftAlt,
    RightAlt,
    Insert,
    Delete,
    Home,
    End,
    PageUp,
    PageDown,
    PrintScreen,
    ScrollLock,
    Pause,
    Escape,
    Tab,
    CapsLock,
    LeftSuper,
    RightSuper,
    Space,
    Backspace,
    Enter,
    Menu,
    Slash,
    Backslash,
    Minus,
    Equal,
    Apostrophe,
    Semicolon,
    LeftBracket,
    RightBracket,
    Tilde,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    OEM1,
    OEM2,
    MAX,
    NONE,
};

pub const Mouse = enum {
    Left,
    Middle,
    Right,
    One,
    Two,
    MAX,
    NONE,
};

pub const Point = struct {
    x: i16,
    y: i16,
};

pub const Rect = struct {
    width: u16,
    height: u16,
};

pub const Event = union(enum) {
    Destroy: void,
    Resize: Rect,
    Move: Point,
    KeyPress: Key,
    KeyRelease: Key,
    MousePress: Mouse,
    MouseRelease: Mouse,
    MouseScrollV: i8,
    MouseScrollH: i8,
    MouseMove: Point,
    FocusIn: void,
    FocusOut: void,
};

pub const Cursor = enum {
    Arrow,
    Hand,
    Text,
    ResizeAll,
    ResizeEW,
    ResizeNS,
    ResizeNESW,
    ResizeNWSE,
    Loading,
};

pub fn keycodeToEnum(code: u8) Key {
    switch (code) {
        19 => return Key.Zero,
        10 => return Key.One,
        11 => return Key.Two,
        12 => return Key.Three,
        13 => return Key.Four,
        14 => return Key.Five,
        15 => return Key.Six,
        16 => return Key.Seven,
        17 => return Key.Eight,
        18 => return Key.Nine,
        90 => return Key.Numpad0,
        87 => return Key.Numpad1,
        88 => return Key.Numpad2,
        89 => return Key.Numpad3,
        83 => return Key.Numpad4,
        84 => return Key.Numpad5,
        85 => return Key.Numpad6,
        79 => return Key.Numpad7,
        80 => return Key.Numpad8,
        81 => return Key.Numpad9,
        91 => return Key.NumpadDecimal,
        86 => return Key.NumpadAdd,
        82 => return Key.NumpadSubtract,
        63 => return Key.NumpadMultiply,
        106 => return Key.NumpadDivide,
        77 => return Key.NumpadLock,
        104 => return Key.NumpadEnter,
        38 => return Key.A,
        56 => return Key.B,
        54 => return Key.C,
        40 => return Key.D,
        26 => return Key.E,
        41 => return Key.F,
        42 => return Key.G,
        43 => return Key.H,
        31 => return Key.I,
        44 => return Key.J,
        45 => return Key.K,
        46 => return Key.L,
        58 => return Key.M,
        57 => return Key.N,
        32 => return Key.O,
        33 => return Key.P,
        24 => return Key.Q,
        27 => return Key.R,
        39 => return Key.S,
        28 => return Key.T,
        30 => return Key.U,
        55 => return Key.V,
        25 => return Key.W,
        53 => return Key.X,
        29 => return Key.Y,
        52 => return Key.Z,
        111 => return Key.Up,
        116 => return Key.Down,
        114 => return Key.Right,
        113 => return Key.Left,
        60 => return Key.Period,
        59 => return Key.Comma,
        50 => return Key.LeftShift,
        62 => return Key.RightShift,
        37 => return Key.LeftCtrl,
        105 => return Key.RightCtrl,
        64 => return Key.LeftAlt,
        108 => return Key.RightAlt,
        118 => return Key.Insert,
        119 => return Key.Delete,
        110 => return Key.Home,
        115 => return Key.End,
        112 => return Key.PageUp,
        117 => return Key.PageDown,
        107 => return Key.PrintScreen,
        78 => return Key.ScrollLock,
        127 => return Key.Pause,
        9 => return Key.Escape,
        23 => return Key.Tab,
        66 => return Key.CapsLock,
        133 => return Key.LeftSuper,
        65 => return Key.Space,
        22 => return Key.Backspace,
        36 => return Key.Enter,
        135 => return Key.Menu,
        61 => return Key.Slash,
        51 => return Key.Backslash,
        20 => return Key.Minus,
        21 => return Key.Equal,
        48 => return Key.Apostrophe,
        47 => return Key.Semicolon,
        34 => return Key.LeftBracket,
        35 => return Key.RightBracket,
        49 => return Key.Tilde,
        67 => return Key.F1,
        68 => return Key.F2,
        69 => return Key.F3,
        70 => return Key.F4,
        71 => return Key.F5,
        72 => return Key.F6,
        73 => return Key.F7,
        74 => return Key.F8,
        75 => return Key.F9,
        76 => return Key.F10,
        95 => return Key.F11,
        96 => return Key.F12,
        94 => return Key.OEM1,
        else => return Key.NONE,
    }
}

pub fn mousecodeToEnum(code: u8) Mouse {
    switch (code) {
        1 => return Mouse.Left,
        2 => return Mouse.Middle,
        3 => return Mouse.Right,
        8 => return Mouse.One,
        9 => return Mouse.Two,
        else => return Mouse.NONE,
    }
}

pub const Error = error{FailedToCreateWindow};

const event_handler_name = "handleEvent";

pub fn getEventHandlerFuncReturnType(comptime InnerType: type) type {
    switch (@typeInfo(InnerType)) {
        .ErrorUnion => |err| if (err.payload == void) return InnerType,
        .Void => return void,
        else => {},
    }

    @compileError("Unsupported event handler return type, only void or void error unions is supported");
}

pub fn getEventHandlerReturnType(comptime EventHandler: type) type {
    switch (@typeInfo(EventHandler)) {
        .Fn => |func| return getEventHandlerFuncReturnType(func.return_type.?),
        .Pointer => |ptr| switch (@typeInfo(ptr.child)) {
            .Struct => |strct| {
                inline for (strct.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, event_handler_name)) {
                        switch (decl.data) {
                            .Fn => |func| return getEventHandlerFuncReturnType(@typeInfo(func.fn_type).Fn.return_type.?),
                            else => @compileError("Type of '" ++ event_handler_name ++ "' declaration in type '" ++ @typeName(ptr.child) ++ "' is not a function"),
                        }
                    }
                }
            },
            else => {},
        },
        else => {},
    }

    @compileError("Unsupported event handler type: " ++ @typeName(EventHandler));
}

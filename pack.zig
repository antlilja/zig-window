const std = @import("std");
const fs = std.fs;
const CrossTarget = std.zig.CrossTarget;

const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

const File = fs.File;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const Hasher = std.crypto.hash.Sha1;

pub const Error = error{
    UnexpectedCharacter,
    UnexpectedToken,
    UnexpectedEOF,
    FailedToAddSystemPackage,
    FailedToAddDirPackage,
    FailedToAddGitPackage,
};

const Tokens = struct {
    data: Data,
    index: usize,

    const Data = std.SegmentedList(Token, 0);

    pub const Token = struct {
        ty: Type,
        slice: ?[]const u8 = null,

        pub const Type = enum {
            System,
            Dir,
            Git,
            Platform,
            Name,
            Url,
            Tag,
            SrcRoot,
            Path,
            String,
            Colon,
            SemiColon,
        };
    };

    pub fn fromText(allocator: *Allocator, text: []const u8) !Tokens {
        const keywords = std.ComptimeStringMap(Token.Type, .{
            .{ "system", .System },
            .{ "dir", .Dir },
            .{ "git", .Git },
            .{ "platform", .Platform },
            .{ "name", .Name },
            .{ "url", .Url },
            .{ "tag", .Tag },
            .{ "src_root", .SrcRoot },
            .{ "path", .Path },
        });

        var data = Data.init(allocator);
        errdefer data.deinit();

        var index: usize = 0;
        while (index < text.len) : (index += 1) {
            switch (text[index]) {
                ' ', '\n', '\r', '\t' => {},
                ':' => try data.push(.{ .ty = .Colon }),
                ';' => try data.push(.{ .ty = .SemiColon }),
                '"' => {
                    index += 1;
                    const start = index;
                    while (index < text.len) {
                        switch (text[index]) {
                            '"' => break,
                            else => index += 1,
                        }
                    }
                    try data.push(.{ .ty = .String, .slice = text[start..index] });
                },
                'a'...'z', '_' => {
                    const start = index;
                    index += 1;
                    while (index < text.len) {
                        switch (text[index]) {
                            'a'...'z', '_' => index += 1,
                            else => break,
                        }
                    }

                    const slice = text[start..index];
                    if (keywords.get(slice)) |ty| {
                        try data.push(.{ .ty = ty, .slice = slice });
                    } else {
                        return Error.UnexpectedCharacter;
                    }
                    index -= 1;
                },
                else => {
                    return Error.UnexpectedCharacter;
                },
            }
        }

        return Tokens{
            .data = data,
            .index = 0,
        };
    }

    pub fn eat(self: *Tokens, ty: Token.Type) !void {
        if (self.index < self.data.len) {
            if (self.data.uncheckedAt(self.index).ty == ty) {
                self.index += 1;
                return;
            }
            return Error.UnexpectedToken;
        }
        return Error.UnexpectedEOF;
    }

    pub fn nextSlice(self: *Tokens, ty: Token.Type) ![]const u8 {
        if (self.index < self.data.len) {
            if (self.data.uncheckedAt(self.index).ty == ty) {
                const slice = self.data.uncheckedAt(self.index).slice.?;
                self.index += 1;
                return slice;
            }
            return Error.UnexpectedToken;
        }
        return Error.UnexpectedEOF;
    }

    pub fn next(self: *Tokens) ?Token {
        if (self.index < self.data.len) {
            const tok = self.data.uncheckedAt(self.index).*;
            self.index += 1;
            return tok;
        }
        return null;
    }
};

fn fileAndHashMatch(path: []const u8, hash: []const u8) !bool {
    const file = try fs.openFileAbsolute(path, .{
        .read = true,
        .write = false,
    });
    defer file.close();

    var hasher = Hasher.init(.{});

    while (true) {
        var buffer: [256]u8 = undefined;
        const len = try file.read(&buffer);

        hasher.update(buffer[0..len]);

        if (len < 256) {
            break;
        }
    }

    var buffer: [20]u8 = undefined;
    hasher.final(&buffer);

    var real_hash: [40]u8 = undefined;
    _ = try std.fmt.bufPrint(&real_hash, "{x}", .{buffer});
    return std.mem.eql(u8, &real_hash, hash);
}

fn cacheAndManifestUpToDate(
    builder: *Builder,
    step: *LibExeObjStep,
    cache_file_path: []const u8,
    manifest_file_path: []const u8,
) !bool {
    {
        const cache = fs.openFileAbsolute(cache_file_path, .{
            .read = true,
            .write = false,
        }) catch {
            return false;
        };
        defer cache.close();

        var reader = cache.reader();
        var buffer: [256]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |hash| {
            if (hash.len == 1) {
                break;
            }

            var path_buffer: [256]u8 = undefined;
            const path = (try reader.readUntilDelimiterOrEof(&path_buffer, '\n')) orelse return false;
            if (path.len == 0 or !(try fileAndHashMatch(path, hash))) {
                return false;
            }
        }
    }

    {
        const manifest = fs.openFileAbsolute(
            manifest_file_path,
            .{
                .read = true,
                .write = false,
            },
        ) catch {
            return false;
        };

        var reader = manifest.reader();
        var buffer: [256]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |dep| {
            if (dep.len == 1) {
                break;
            }

            switch (dep[0]) {
                's' => step.linkSystemLibrary(dep[1..]),
                'p' => {
                    var it = std.mem.split(dep[1..], " ");
                    const name = it.next() orelse return false;
                    const path = it.next() orelse return false;

                    step.addPackagePath(name, path);
                },
                else => return false,
            }
        }
    }
    return true;
}

pub fn addPackages(builder: *Builder, step: *LibExeObjStep) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const cache_pack_path = try fs.path.join(allocator, &[_][]const u8{
        builder.build_root,
        builder.cache_root,
        "pack",
    });

    fs.makeDirAbsolute(cache_pack_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const cache_file_path = try fs.path.join(allocator, &[_][]const u8{ cache_pack_path, "cache" });
    const manifest_file_path = try fs.path.join(allocator, &[_][]const u8{ cache_pack_path, "manifest" });
    if (try cacheAndManifestUpToDate(
        builder,
        step,
        cache_file_path,
        manifest_file_path,
    )) {
        // Everything is up to date
        return;
    }

    const root_path = std.os.getenv("ZIG_PACK_PATH") orelse cache_pack_path;
    const offline = builder.option(bool, "zpack-offline", "Force zpack to only use offline packages") orelse false;

    var pack = Pack.init(
        allocator,
        step,
        root_path,
        offline,
        try fs.createFileAbsolute(cache_file_path, .{}),
        try fs.createFileAbsolute(manifest_file_path, .{}),
    );

    pack.addPackages(builder.build_root) catch |err| {
        try fs.deleteFileAbsolute(cache_file_path);
        try fs.deleteFileAbsolute(manifest_file_path);
        return err;
    };
}

const Pack = struct {
    allocator: *Allocator,
    step: *LibExeObjStep,
    root: []const u8,
    offline: bool,
    cache_file: File,
    manifest_file: File,

    fn init(
        allocator: *Allocator,
        step: *LibExeObjStep,
        root: []const u8,
        offline: bool,
        cache_file: File,
        manifest_file: File,
    ) Pack {
        return Pack{
            .allocator = allocator,
            .step = step,
            .root = root,
            .offline = offline,
            .cache_file = cache_file,
            .manifest_file = manifest_file,
        };
    }

    fn join_paths(self: *Pack, a: []const u8, b: []const u8) ![]const u8 {
        return fs.path.join(self.allocator, &[_][]const u8{ a, b });
    }

    fn addPackages(self: *Pack, path: []const u8) !void {
        const file_path = try self.join_paths(path, "packages");

        const file = fs.openFileAbsolute(file_path, .{}) catch |err| switch (err) {
            File.OpenError.FileNotFound => return,
            else => return err,
        };
        defer file.close();
        const stat = try file.stat();
        const text = try self.allocator.alloc(u8, stat.size);
        _ = try file.read(text);

        // Write packages file to cache
        {
            var buffer: [20]u8 = undefined;
            Hasher.hash(text, &buffer, .{});
            self.cache_file.writer().print("{x}\n{}\n", .{ buffer, file_path }) catch unreachable;
        }

        var tokens = try Tokens.fromText(self.allocator, text);

        while (tokens.next()) |token| {
            switch (token.ty) {
                .Platform => {
                    try tokens.eat(.Colon);
                    const platform = try tokens.nextSlice(.String);
                    const real_platform = @tagName(self.step.target.getOsTag());
                    if (std.mem.eql(u8, platform, real_platform)) {
                        while (tokens.next()) |token2| {
                            switch (token2.ty) {
                                .SemiColon => break,
                                else => try self.addPackage(path, token2.ty, &tokens),
                            }
                        }
                    } else {
                        while (tokens.next()) |token2| {
                            switch (token2.ty) {
                                .SemiColon => break,
                                else => {},
                            }
                        }
                    }
                },
                else => try self.addPackage(path, token.ty, &tokens),
            }
        }
    }

    fn addPackage(
        self: *Pack,
        parent_path: []const u8,
        ty: Tokens.Token.Type,
        tokens: *Tokens,
    ) Error!void {
        try tokens.eat(.Colon);
        switch (ty) {
            .System => {
                self.addSystemPackage(try tokens.nextSlice(.String)) catch {
                    return Error.FailedToAddSystemPackage;
                };
            },
            .Dir => {
                try tokens.eat(.Name);
                try tokens.eat(.Colon);
                const name = try tokens.nextSlice(.String);

                try tokens.eat(.Path);
                try tokens.eat(.Colon);
                const path = try tokens.nextSlice(.String);

                try tokens.eat(.SrcRoot);
                try tokens.eat(.Colon);
                const src_root = try tokens.nextSlice(.String);

                self.addDirPackage(parent_path, name, path, src_root) catch {
                    return Error.FailedToAddDirPackage;
                };
            },
            .Git => {
                try tokens.eat(.Name);
                try tokens.eat(.Colon);
                const name = try tokens.nextSlice(.String);

                try tokens.eat(.Url);
                try tokens.eat(.Colon);
                const url = try tokens.nextSlice(.String);

                try tokens.eat(.Tag);
                try tokens.eat(.Colon);
                const tag = try tokens.nextSlice(.String);

                try tokens.eat(.SrcRoot);
                try tokens.eat(.Colon);
                const src_root = try tokens.nextSlice(.String);

                self.addGitPackage(name, url, tag, src_root) catch {
                    return Error.FailedToAddGitPackage;
                };
            },
            else => return Error.UnexpectedToken,
        }
    }

    fn addSystemPackage(self: *Pack, name: []const u8) !void {
        self.step.linkSystemLibrary(name);
        try self.manifest_file.writer().print("s{}\n", .{name});
    }

    fn addDirPackage(
        self: *Pack,
        parent_path: []const u8,
        name: []const u8,
        path: []const u8,
        src_root: []const u8,
    ) !void {
        const full_path = try self.join_paths(parent_path, path);
        const src_root_full_path = try self.join_paths(path, src_root);

        self.step.addPackagePath(name, src_root_full_path);

        try self.manifest_file.writer().print("p{} {}\n", .{ name, src_root_full_path });
        try self.addPackages(full_path);
    }

    fn addGitPackage(
        self: *Pack,
        name: []const u8,
        url: []const u8,
        tag: []const u8,
        src_root: []const u8,
    ) !void {
        const dir_name = dir: {
            var hasher = Hasher.init(.{});
            hasher.update(url);
            hasher.update(tag);

            var buffer: [20]u8 = undefined;
            hasher.final(&buffer);

            var out: [40]u8 = undefined;
            _ = try std.fmt.bufPrint(&out, "{x}", .{buffer});
            break :dir out;
        };

        const repo_path = try self.join_paths(self.root, &dir_name);

        if (!self.offline) {
            const result = try std.ChildProcess.exec(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{
                    "git",
                    "clone",
                    "--recursive",
                    "--depth",
                    "1",
                    "--branch",
                    tag,
                    url,
                    &dir_name,
                },
                .cwd = self.root,
            });

            if (result.term.Exited != 0) {
                const str = try std.mem.concat(self.allocator, u8, &[_][]const u8{
                    "fatal: destination path '",
                    &dir_name,
                    "' already exists and is not an empty directory.\n",
                });

                if (std.mem.eql(u8, str, result.stderr)) {
                    const result2 = try std.ChildProcess.exec(.{
                        .allocator = self.allocator,
                        .argv = &[_][]const u8{
                            "git",
                            "fetch",
                            "origin",
                            tag,
                        },
                        .cwd = repo_path,
                    });

                    if (result2.term.Exited != 0) {
                        return Error.FailedToAddGitPackage;
                    }
                } else {
                    return Error.FailedToAddGitPackage;
                }
            }
        }

        const src_root_full_path = try self.join_paths(repo_path, src_root);

        self.step.addPackagePath(name, src_root_full_path);
        try self.manifest_file.writer().print("p{} {}\n", .{ name, src_root_full_path });
        try self.addPackages(repo_path);
    }
};

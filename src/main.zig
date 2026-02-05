const std = @import("std");
const re = @cImport({
    @cInclude("regex.h");
    @cInclude("regex_init.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    var envmap = try std.process.getEnvMap(alloc);
    defer envmap.deinit();
    var args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len <= 1) {
        return;
    }

    const xdg_config_home = envmap.get("XDG_CONFIG_HOME") orelse res: {
        const home = envmap.get("HOME") orelse {
            @panic("HOME not set!");
        };
        break :res try std.fs.path.join(alloc, &.{ home, ".config" });
    };
    defer alloc.free(xdg_config_home);

    const xiki_home = envmap.get("XIKI_HOME") orelse res: {
        break :res try std.fs.path.join(alloc, &.{ xdg_config_home, "xiki" });
    };
    defer alloc.free(xiki_home);

    std.fs.makeDirAbsolute(xiki_home) catch |err|
        switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    var xiki_dir = try std.fs.openDirAbsolute(xiki_home, .{ .iterate = true });
    defer xiki_dir.close();
    var scripts_dir = try xiki_dir.openDir("scripts", .{ .iterate = true });
    defer scripts_dir.close();

    var walker = try scripts_dir.walk(alloc);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .sym_link => {
                // walker.name_buffer already contains the path
                // So we don't need to push it
                // See `std.fs.Dir.Walker.next`
                const dir = try scripts_dir.openDir(entry.path, .{ .iterate = true });
                try walker.stack.append(alloc, .{
                    .iter = dir.iterateAssumeFirstIteration(),
                    .dirname_len = walker.name_buffer.items.len - 1,
                });
                continue;
            },
            .file => {},
            else => continue,
        }
        const preg = re.init_regex_t();
        defer {
            re.regfree(preg);
            re.cleanup_regex_t(preg);
        }

        const comp_res = re.regcomp(preg, entry.basename, re.REG_EXTENDED);
        if (comp_res != 0) {
            const error_buffer = try alloc.alloc(u8, 256);
            _ = re.regerror(comp_res, preg, error_buffer.ptr, error_buffer.len);
            std.log.err("Failed to compile regex {s}: {s}", .{ entry.basename, error_buffer });
            std.process.exit(1);
        }

        const arg1 = args[1];

        const matches = try alloc.alloc(re.regmatch_t, re.regex_nsub(preg) + 1);
        defer alloc.free(matches);
        const match_res = re.regexec(preg, arg1, matches.len, matches.ptr, 0);
        if (match_res != 0 or matches[0].rm_so != 0 or matches[0].rm_eo != arg1.len) {
            continue;
        }

        for (matches, 0..) |m, i| {
            if (m.rm_so == -1 or m.rm_eo == -1) {
                continue;
            }

            const name = try std.fmt.allocPrint(alloc, "ARG{d}", .{i});
            defer alloc.free(name);
            const value = arg1[@intCast(m.rm_so)..@intCast(m.rm_eo)];
            try envmap.put(name, value);
        }
        args[0] = try std.fs.path.joinZ(alloc, &.{ xiki_home, "scripts", entry.path });
        const err = std.process.execve(alloc, args, &envmap);
        std.log.err("Failed to exec! {s} {any}", .{ args[0], err });
        std.process.exit(2);
    }

    // nothing has matched
    args[0] = try std.fs.path.joinZ(alloc, &.{ xiki_home, "default" });
    const err = std.process.execve(alloc, args, &envmap);
    std.log.err("Failed to exec! {s} {any}", .{ args[0], err });
    std.process.exit(2);
}

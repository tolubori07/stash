const std = @import("std");
const posix = std.posix;
const io = std.io;
const stdout = io.getStdOut().writer();

pub fn cd(dir: []const u8) !void {
    if (dir.len == 0 or (dir.len == 1 and dir[0] == '~')) {
        const home_dir = posix.getenv("HOME") orelse {
            try stdout.print("cd: HOME environment variable not set\n", .{});
            return;
        };
        posix.chdir(home_dir) catch |err| {
            switch (err) {
                error.FileNotFound => try stdout.print("cd: HOME: No such file or directory\n", .{}),
                error.AccessDenied => try stdout.print("cd: HOME: Permission denied\n", .{}),
                error.NotDir => try stdout.print("cd: HOME: Not a directory\n", .{}),
                else => try stdout.print("cd: HOME: Unknown error\n", .{}),
            }
            return;
        };
        return;
    }

    posix.chdir(dir) catch |err| {
        switch (err) {
            error.FileNotFound => try stdout.print("cd: {s}: No such file or directory\n", .{dir}),
            error.AccessDenied => try stdout.print("cd: {s}: Permission denied\n", .{dir}),
            error.NotDir => try stdout.print("cd: {s}: Not a directory\n", .{dir}),
            else => try stdout.print("cd: {s}: Unknown error\n", .{dir}),
        }
        return;
    };
}

const std = @import("std");
const mem = std.mem;
const posix = std.posix;
const fs = std.fs;

const ShellError = error{
    PathNotFound,
    CommandNotFound,
    InvalidCommand,
    PermissionDenied,
};

/// Checks if a command exists in PATH and returns its full path
pub fn parsePATH(allocator: mem.Allocator, name: []const u8) !?[]const u8 {
    const path_env = posix.getenv("PATH") orelse return ShellError.PathNotFound;

    var iter = mem.splitScalar(u8, path_env, ':');
    while (iter.next()) |dir| {
        const full_path = try fs.path.join(allocator, &[_][]const u8{ dir, name });
        errdefer allocator.free(full_path);

        const file = fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch |err| {
            allocator.free(full_path);
            if (err == error.FileNotFound) continue;
            if (err == error.PermissionDenied) return ShellError.PermissionDenied;
            continue;
        };
        defer file.close();

        const stat = file.stat() catch |err| {
            allocator.free(full_path);
            if (err == error.PermissionDenied) return ShellError.PermissionDenied;
            continue;
        };

        // Check if file is executable
        if (stat.mode & 0o111 != 0) {
            return full_path;
        }

        allocator.free(full_path);
    }
    return null;
}

const std = @import("std");
const posix = std.posix;
const io = std.io;
const mem = std.mem;
const stdout = io.getStdOut().writer();
const parsePATH = @import("../utils/parsePATH.zig").parsePATH;
/// Implementation of the type builtin command
pub fn typeFn(allocator: mem.Allocator, command: []const u8, builtins: []const []const u8) !void {
    // First check if it's a builtin command
    for (builtins) |builtin| {
        if (mem.eql(u8, command, builtin)) {
            try stdout.print("{s} is a shell builtin\n", .{command});
            return;
        }
    }

    // Then check if it exists in PATH
    const path = try parsePATH(allocator, command) orelse {
        try stdout.print("{s} not found\n", .{command});
        return;
    };
    defer allocator.free(path);

    try stdout.print("{s} is {s}\n", .{ command, path });
}

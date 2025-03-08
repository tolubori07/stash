const std = @import("std");
const posix = std.posix;
const io = std.io;
const mem = std.mem;
const stdout = io.getStdOut().writer();

pub fn echo(str: []const u8) !void {
    _ = try stdout.write(str);
    _ = try stdout.write("\n");
}

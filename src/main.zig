const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("$ ", .{});

    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

    // TODO: Handle user input
    try stdout.print("{s}: command not found\n", .{user_input});
}

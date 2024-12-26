const std = @import("std");

const io = std.io;

const mem = std.mem;

const process = std.process;
const fmt = std.fmt;

pub fn main() !void {
    while (true) {
        const stdout = io.getStdOut().writer();
        try stdout.print("$ ", .{});

        const stdin = io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        var tokens = mem.splitScalar(u8, user_input, ' ');
        const command = tokens.first();
        const args = tokens.rest();
        if (mem.eql(u8, command, "exit")) {
            //example '5'(ASCII value of 53) - '0'(ASCII value of 48) = 5
            process.exit(args[0] - '0');
        } else if (std.mem.eql(u8, command, "echo")) {
            _ = try stdout.write(args);
            _ = try stdout.write("\n");
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}

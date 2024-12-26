const std = @import("std");

const io = std.io;

const mem = std.mem;

const process = std.process;
const fmt = std.fmt;

pub fn main() !void {
    const builtins = [_][]const u8{ "echo", "exit", "type" };
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
            if (args.len > 0) {
                process.exit(args[0] - '0');
            } else {
                process.exit(0);
            }
        } else if (std.mem.eql(u8, command, "echo")) {
            _ = try stdout.write(args);
            _ = try stdout.write("\n");
        } else if (std.mem.eql(u8, command, "type")) {
            var found = false;
            for (builtins) |value| {
                if (mem.eql(u8, args, value)) {
                    try stdout.print("{s} is a shell builtin\n", .{args});
                    found = true;
                    break;
                }
            }
            if (!found)
                try stdout.print("{s}: not found\n", .{args});
        } else {
            try stdout.print("{s}: command not found\n", .{user_input});
        }
    }
}

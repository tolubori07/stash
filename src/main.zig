const std = @import("std");
const cd = @import("./builtins/cd.zig").cd;
const echo = @import("./builtins/echo.zig").echo;
const printWD = @import("./builtins/pwd.zig").printWD;
const exit = @import("./builtins/exit.zig").exit;
const typeFn = @import("./builtins/type.zig").typeFn;
const parsePATH = @import("./utils/parsePATH.zig").parsePATH;
const io = std.io;
const mem = std.mem;
const process = std.process;
const fs = std.fs;
const stdout = io.getStdOut().writer();
const posix = std.posix;
const ArrayList = std.ArrayList;

// Custom error set for shell operations
const ShellError = error{
    PathNotFound,
    CommandNotFound,
    InvalidCommand,
    PermissionDenied,
};

//TODO: Handle double quotes
pub fn handleQuotes(args: []u8, allocator: mem.Allocator) []u8 {
    if (args[0] == '\'') {
        return args[1 .. args.len - 1];
    } else {
        const newArgs = ArrayList(u8).init(allocator);
        defer newArgs.deinit();
        for (args, 0..) |arg, i| {
            while (args[i + 1] == ' ') {
                continue;
            }
            newArgs.append(arg);
        }
    }
}

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define builtin commands
    const builtins = [_][]const u8{ "echo", "exit", "type", "cd", "pwd" };

    // Main shell loop
    while (true) {
        try stdout.print("$ ", .{});

        // Read user input
        const stdin = io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = stdin.readUntilDelimiter(&buffer, '\n') catch |err| {
            if (err == error.EndOfStream) break;
            continue;
        };
        // Parse input into command and arguments
        var tokens = mem.splitScalar(u8, user_input, ' ');
        const command = tokens.first();
        const temp_args = tokens.rest();
        //const args = std.ArrayList(u8).init(allocator);
        //defer args.deinit();
        //for (temp_args) |value| {
        //    try args.append(value);
        //    while (value) {}
        // }
        const args = if (temp_args[0] == '\'') temp_args[1 .. temp_args.len - 1] else temp_args;

        // Handle empty input
        if (command.len == 0) continue;

        // Handle commands
        if (mem.eql(u8, command, "exit")) {
            try exit(args);
        } else if (mem.eql(u8, command, "type")) {
            if (args.len == 0) {
                try stdout.print("type: missing argument\n", .{});
                continue;
            }
            typeFn(allocator, args, &builtins) catch |err| {
                switch (err) {
                    ShellError.PathNotFound => try stdout.print("PATH environment variable not set\n", .{}),
                    ShellError.PermissionDenied => try stdout.print("Permission denied\n", .{}),
                    else => try stdout.print("Error: {any}\n", .{err}),
                }
            };
        } else if (mem.eql(u8, command, "echo")) {
            try echo(args);
        } else if (mem.eql(u8, command, "pwd")) {
            try printWD();
        } else if (mem.eql(u8, command, "cd")) {
            try cd(args);
        } else {
            // Handle external commands
            const path = try parsePATH(allocator, command) orelse {
                try stdout.print("{s}: command not found\n", .{command});
                continue;
            };
            defer allocator.free(path);
            var xargs = std.ArrayList([]const u8).init(allocator);
            defer xargs.deinit();
            try xargs.append(command);
            while (tokens.next()) |arg| {
                try xargs.append(arg);
            }
            var child = process.Child.init(xargs.items, allocator);
            _ = try child.spawnAndWait();
        }
    }
}

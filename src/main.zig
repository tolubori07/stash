const std = @import("std");
const io = std.io;
const mem = std.mem;
const process = std.process;
const fs = std.fs;
const stdout = io.getStdOut().writer();
const posix = std.posix;

// Custom error set for shell operations
const ShellError = error{
    PathNotFound,
    CommandNotFound,
    InvalidCommand,
    PermissionDenied,
};

/// Checks if a command exists in PATH and returns its full path
fn parsePATH(allocator: mem.Allocator, name: []const u8) !?[]const u8 {
    const path_env = posix.getenv("PATH") orelse return ShellError.PathNotFound;

    var iter = mem.split(u8, path_env, ":");
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

/// Implementation of the type builtin command
fn typeFn(allocator: mem.Allocator, command: []const u8, builtins: []const []const u8) !void {
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

fn exit(args: []const u8) !void {
    //example '5'(ASCII value of 53) - '0'(ASCII value of 48) = 5
    if (args.len > 0) {
        process.exit(args[0] - '0');
    } else {
        process.exit(0);
    }
}

fn echo(str: []const u8) !void {
    _ = try stdout.write(str);
    _ = try stdout.write("\n");
}

fn printWD() !void {
    //const buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pwd = try std.process.getCwdAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(pwd);
    try stdout.print("{s}\n", .{pwd});
}

fn cd(dir: []const u8) !void {
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

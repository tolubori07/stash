const std = @import("std");
const process = std.process;

pub fn exit(args: []const u8) !void {
    //example '5'(ASCII value of 53) - '0'(ASCII value of 48) = 5
    if (args.len > 0) {
        process.exit(args[0] - '0');
    } else {
        process.exit(0);
    }
}

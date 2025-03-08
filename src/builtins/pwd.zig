const std = @import("std");
const process = std.process;
const mem = std.mem;
const stdout = std.io.getStdOut().writer();

pub fn printWD() !void {
    //const buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pwd = try process.getCwdAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(pwd);
    try stdout.print("{s}\n", .{pwd});
}

const std = @import("std");
const Server = @import("Server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var server = try Server.init(allocator, .{ .port = 8080 });
    defer server.deinit();

    std.debug.print("Listening on 127.0.0.1:8080\n", .{});

    try server.listen();
}

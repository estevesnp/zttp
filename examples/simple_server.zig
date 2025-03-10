const std = @import("std");
const zttp = @import("zttp");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var server: zttp.Server = try .init(allocator, .{ .port = 8080 });
    defer server.deinit();

    try server.registerHandle("/", printHeadersAndBody);
    try server.registerHandle("/ping", pingHandle);

    std.debug.print("Listening on 127.0.0.1:8080\n", .{});

    try server.listen();
}

fn pingHandle(_: *zttp.Request, resp: *zttp.Response) !void {
    resp.body = "pong\n";
}

fn printHeadersAndBody(req: *zttp.Request, resp: *zttp.Response) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\Method: {s}
        \\Url: {s}
        \\Version: {s}
        \\Headers:
        \\
    ,
        .{
            @tagName(req.method),
            req.url,
            req.version,
        },
    );

    var header_iter = req.headers.iterator();
    while (header_iter.next()) |entry| {
        try stdout.print("  {s}: ", .{entry.key_ptr.*});

        const header_len = entry.value_ptr.items.len;
        for (entry.value_ptr.items, 0..) |val, idx| {
            try stdout.print("{s}", .{val});
            if (idx < header_len - 1) {
                try stdout.print(", ", .{});
            }
        }

        try stdout.print("\n", .{});
    }

    const body = try req.parseBody();

    if (body.len > 0) {
        try stdout.print("Body: {s}\n", .{body});
    }

    try stdout.print("\n", .{});

    try resp.addHeader("Test-Header", "First");
    try resp.addHeader("Test-Header", "Second");
    resp.body = "my little message";
    resp.status_code = .{ .code = 201, .msg = "Created" };
}

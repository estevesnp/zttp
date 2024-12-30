const std = @import("std");
const net = std.net;
const mem = std.mem;

const req = @import("request.zig");
const resp = @import("response.zig");

const Server = @This();

listener: net.Server,
pool: *std.Thread.Pool,
allocator: std.mem.Allocator,

const Config = struct {
    addr: []const u8 = "127.0.0.1",
    port: u16,
    n_jobs: ?u32 = null,
};

pub fn init(allocator: mem.Allocator, config: Config) !Server {
    const address = try net.Address.resolveIp(config.addr, config.port);
    const listener = try address.listen(.{ .reuse_address = true });

    const pool = try allocator.create(std.Thread.Pool);
    errdefer allocator.destroy(pool);

    try pool.init(.{ .allocator = allocator, .n_jobs = config.n_jobs });
    return .{
        .listener = listener,
        .pool = pool,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Server) void {
    self.pool.deinit();
    self.allocator.destroy(self.pool);
    self.listener.deinit();
}

pub fn listen(self: *Server) !void {
    while (true) {
        const conn = try self.listener.accept();
        try self.pool.spawn(handleConn, .{ self.allocator, conn.stream });
    }
}

// TODO - create handle registering
fn handleConn(allocator: mem.Allocator, stream: net.Stream) void {
    defer stream.close();

    var request = req.parseRequest(allocator, stream) catch |err| {
        std.debug.print("Error parsing request: {s}\n", .{@errorName(err)});
        return;
    };
    defer request.deinit();

    std.io.getStdOut().writer().print(
        \\Method: {s}
        \\Url: {s}
        \\Version: {s}
        \\
    ,
        .{
            @tagName(request.method),
            request.url,
            request.version,
        },
    ) catch {};

    resp.write(stream, resp.Status.SC_OK) catch |err| {
        std.debug.print("Error writing response: {s}\n", .{@errorName(err)});
        return;
    };
}

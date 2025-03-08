const std = @import("std");
const net = std.net;
const mem = std.mem;

const Request = @import("Request.zig");
const Response = @import("Response.zig");

const HandlerFn = *const fn (*Request, *Response) anyerror!void;
const HandleMap = std.StringHashMapUnmanaged(HandlerFn);

const Server = @This();

// TODO - add middleware
listener: net.Server,
pool: *std.Thread.Pool,
allocator: std.mem.Allocator,
handles: HandleMap = .empty,

const Config = struct {
    addr: []const u8 = "127.0.0.1",
    port: u16,
    n_jobs: ?usize = null,
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
    self.handles.deinit(self.allocator);
    self.listener.deinit();
}

pub fn registerHandle(self: *Server, path: []const u8, handler: HandlerFn) !void {
    const gop = try self.handles.getOrPut(self.allocator, path);
    if (gop.found_existing) {
        std.debug.panic("A handler has already been registered for '{s}'", .{path});
    }
    gop.value_ptr.* = handler;
}

pub fn listen(self: *Server) !void {
    while (true) {
        const conn = try self.listener.accept();
        try self.pool.spawn(handleConn, .{ self.allocator, &self.handles, conn.stream });
    }
}

fn handleConn(allocator: mem.Allocator, handles: *HandleMap, stream: net.Stream) void {
    defer stream.close();

    var request = Request.parse(allocator, stream) catch |err| {
        std.debug.print("Error parsing request: {s}\n", .{@errorName(err)});
        return;
    };
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    const action = handles.get(request.url) orelse {
        response.status_code = Response.StatusCode.SC_NOT_FOUND;
        response.body = "404 page not found\n";

        response.write(stream) catch |err| {
            std.debug.print("Error writing response: {s}\n", .{@errorName(err)});
        };
        return;
    };

    action(&request, &response) catch |err| {
        std.debug.print("Error handling request for {s}: {}", .{ request.url, err });
    };

    response.write(stream) catch |err| {
        std.debug.print("Error writing response: {s}\n", .{@errorName(err)});
        return;
    };
}

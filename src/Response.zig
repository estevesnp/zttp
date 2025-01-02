const std = @import("std");
const net = std.net;
const io = std.io;

const Headers = std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8));
const StreamWriter = io.Writer(net.Stream, net.Stream.WriteError, net.Stream.write);

const Response = @This();

status_code: StatusCode = StatusCode.SC_OK,
headers: Headers = Headers{},
body: []const u8 = "",
written: bool = false,
arena: std.heap.ArenaAllocator,

pub const StatusCode = struct {
    code: u16,
    msg: []const u8,

    pub const SC_OK: StatusCode = .{ .code = 200, .msg = "OK" };
    pub const SC_NOT_FOUND: StatusCode = .{ .code = 404, .msg = "Not Found" };
    pub const SC_INTERNAL_SERVER_ERROR: StatusCode = .{ .code = 500, .msg = "Internal Server Error" };
};

pub fn init(parent_allocator: std.mem.Allocator) Response {
    return .{ .arena = std.heap.ArenaAllocator.init(parent_allocator) };
}

pub fn deinit(self: *Response) void {
    self.arena.deinit();
}

pub fn addHeader(self: *Response, key: []const u8, value: []const u8) !void {
    const allocator = self.arena.allocator();

    const gop = try self.headers.getOrPut(allocator, key);
    if (!gop.found_existing) {
        gop.value_ptr.* = std.ArrayListUnmanaged([]const u8){};
    }

    try gop.value_ptr.append(allocator, value);
}

pub fn write(self: *Response, stream: net.Stream) !void {
    if (self.written) return;

    self.written = true;

    var buf_writer = io.bufferedWriter(stream.writer());
    const writer = buf_writer.writer();

    try writer.print("HTTP/1.1 {d} {s}\r\n", .{ self.status_code.code, self.status_code.msg });

    var header_it = self.headers.iterator();
    while (header_it.next()) |entry| {
        try writer.print("{s}: ", .{entry.key_ptr.*});
        for (entry.value_ptr.items, 0..) |value, idx| {
            if (idx < entry.value_ptr.items.len - 1) {
                try writer.print("{s}, ", .{value});
                continue;
            }
            try writer.print("{s}\r\n", .{value});
        }
    }

    if (self.headers.get("Content-Length") == null) {
        try writer.print("Content-Length: {d}\r\n", .{self.body.len});
    }

    try writer.writeAll("\r\n");

    if (self.body.len > 0) {
        try writer.writeAll(self.body);
    }

    try buf_writer.flush();
}

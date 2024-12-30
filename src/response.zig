const std = @import("std");
const net = std.net;
const io = std.io;

pub const Status = struct {
    code: u32,
    msg: []const u8,

    pub const SC_OK: Status = .{ .code = 200, .msg = "OK" };
    pub const SC_NOT_FOUND: Status = .{ .code = 404, .msg = "Not Found" };
};

// TODO - implement Response struct and properly write to stream
pub fn write(stream: net.Stream, status: Status) !void {
    var buf_writer = io.bufferedWriter(stream.writer());
    const writer = buf_writer.writer();

    try writer.print(
        "HTTP/1.1 {d} {s}\r\nConnection: close\r\n\r\n",
        .{ status.code, status.msg },
    );
    try buf_writer.flush();
}

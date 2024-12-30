const std = @import("std");
const net = std.net;
const io = std.io;
const mem = std.mem;
const StreamReader = io.Reader(net.Stream, net.Stream.ReadError, net.Stream.read);
const BodyReader = io.BufferedReader(4096, StreamReader);
const Headers = std.StringHashMapUnmanaged([]const u8);

const req_line_limit = 8192;

const RequestParseError = error{
    BadStartLine,
    BadMethod,
    BadUrl,
    BadVersion,
};

const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
};

const Request = struct {
    method: Method,
    url: []const u8,
    version: []const u8,
    headers: Headers,
    body_reader: BodyReader,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Request) void {
        self.arena.deinit();
    }

    pub fn parseBody(self: *Request) ![]const u8 {
        _ = self; // autofix
        // TODO - implement
        return error.NotImplemented;
    }
};

pub fn parseRequest(parent_allocator: mem.Allocator, stream: net.Stream) !Request {
    var arena = std.heap.ArenaAllocator.init(parent_allocator);

    const allocator = arena.allocator();

    var buf_reader = io.bufferedReader(stream.reader());
    const reader = buf_reader.reader();

    const start_line = try reader.readUntilDelimiterAlloc(allocator, '\n', req_line_limit);

    if (start_line.len == 0 or start_line[start_line.len - 1] != '\r') return RequestParseError.BadStartLine;

    var star_iter = mem.tokenizeAny(u8, start_line, " \r");
    const method_string = star_iter.next() orelse return RequestParseError.BadMethod;
    const method = std.meta.stringToEnum(Method, method_string) orelse return RequestParseError.BadMethod;

    const url = star_iter.next() orelse return RequestParseError.BadUrl;
    const version = star_iter.next() orelse return RequestParseError.BadVersion;

    // TODO - parse headers

    return Request{
        .method = method,
        .url = url,
        .version = version,
        .headers = Headers{},
        .body_reader = buf_reader,
        .arena = arena,
    };
}

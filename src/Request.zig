const std = @import("std");
const net = std.net;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;

const StreamReader = io.Reader(net.Stream, net.Stream.ReadError, net.Stream.read);
const BodyReader = io.BufferedReader(4096, StreamReader);
const Headers = std.StringHashMapUnmanaged(std.ArrayListUnmanaged([]const u8));

const Request = @This();

// TODO - parse form and path params
method: Method,
url: []const u8,
version: []const u8,
headers: Headers,
body_reader: BodyReader,
arena: std.heap.ArenaAllocator,

const req_line_limit = 8192;

const RequestParseError = error{
    BadStartLine,
    BadMethod,
    BadUrl,
    BadVersion,
    BadHeader,
};

const ParseBodyError = error{
    TooSmall,
    BadLengthHeader,
};

const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
};

pub fn deinit(self: *Request) void {
    self.arena.deinit();
}

pub fn parse(parent_allocator: mem.Allocator, stream: net.Stream) !Request {
    var arena = std.heap.ArenaAllocator.init(parent_allocator);

    const allocator = arena.allocator();

    var buf_reader = io.bufferedReader(stream.reader());
    const reader = buf_reader.reader();

    const start_line = try reader.readUntilDelimiterAlloc(allocator, '\n', req_line_limit);

    if (start_line.len <= 1 or start_line[start_line.len - 1] != '\r') return RequestParseError.BadStartLine;

    var star_iter = mem.tokenizeAny(u8, start_line, " \r");
    const method_string = star_iter.next() orelse return RequestParseError.BadMethod;
    const method = std.meta.stringToEnum(Method, method_string) orelse return RequestParseError.BadMethod;

    const url = star_iter.next() orelse return RequestParseError.BadUrl;
    const version = star_iter.next() orelse return RequestParseError.BadVersion;

    var headers = Headers{};

    var header_line = try reader.readUntilDelimiterAlloc(allocator, '\n', req_line_limit);
    while (header_line.len > 1) {
        if (header_line[header_line.len - 1] != '\r') return RequestParseError.BadHeader;
        const sep = mem.indexOf(u8, header_line, ": ") orelse return RequestParseError.BadHeader;
        const key = header_line[0..sep];
        const val = header_line[sep + ": ".len .. header_line.len - 1];

        const gop = try headers.getOrPut(allocator, key);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayListUnmanaged([]const u8){};
        }
        try gop.value_ptr.append(allocator, val);

        header_line = try reader.readUntilDelimiterAlloc(allocator, '\n', req_line_limit);
    }

    return Request{
        .method = method,
        .url = url,
        .version = version,
        .headers = headers,
        .body_reader = buf_reader,
        .arena = arena,
    };
}

pub fn parseBody(self: *Request) ![]const u8 {
    const allocator = self.arena.allocator();
    const reader = self.body_reader.reader();

    const content_length = blk: {
        const cont_list = self.headers.get("Content-Length") orelse return "";
        if (cont_list.items.len != 1) return ParseBodyError.BadLengthHeader;
        break :blk fmt.parseInt(usize, cont_list.items[0], 10) catch
            return ParseBodyError.BadLengthHeader;
    };

    var buf = try allocator.alloc(u8, content_length);
    var total_read: usize = 0;

    while (total_read < content_length) {
        const bytes_read = try reader.read(buf[total_read..]);
        if (bytes_read == 0) {
            return ParseBodyError.TooSmall;
        }
        total_read += bytes_read;
    }

    return buf;
}

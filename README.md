# `zttp`

a simple HTTP server implemented in zig

## Installation

1. Add to your `build.zig.zon` with the following command:

```bash
zig fetch --save git+https://github.com/estevesnp/zttp#main
```

2. Add the following to your `build.zig`:

```zig
b.installArtifact(exe);
const zttp = b.dependency("zttp", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zttp", zttp.module("zttp"));
```

## Example

For more examples, check `examples`

```zig
pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var server: zttp.Server = try .init(allocator, .{ .port = 8080 });
    defer server.deinit();

    try server.registerHandle("/ping", pingHandle);

    std.debug.print("Listening on 127.0.0.1:8080\n", .{});

    try server.listen();
}

fn pingHandle(_: *zttp.Request, resp: *zttp.Response) !void {
    resp.body = "pong\n";
}
```

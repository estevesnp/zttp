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

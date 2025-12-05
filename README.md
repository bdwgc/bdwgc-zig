# bdwgc-zig

> Zig language bindings for the [Boehm-Demers-Weiser Garbage Collector](https://github.com/bdwgc/bdwgc) (bdwgc).

![CI](https://github.com/bdwgc/bdwgc-zig/actions/workflows/ci.yml/badge.svg)
[![Zig](https://img.shields.io/badge/Zig-0.15-f7a41d)](https://ziglang.org/download/)
[![License](https://img.shields.io/badge/License-MIT-d63e97)](https://github.com/bdwgc/bdwgc-zig/blob/main/LICENSE)

## Installation

Zig 0.15 is required.

```console
zig fetch --save git+https://github.com/bdwgc/bdwgc-zig
```

```zig
// build.zig
const bdwgc = b.dependency("bdwgc_zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("bdwgc", bdwgc.module("bdwgc"));
```

## Usage

```zig
const std = @import("std");
const bdwgc = @import("bdwgc");

pub fn main() !void {
    bdwgc.init();
    defer bdwgc.deinit();

    // TODO: Implement allocator interface
    const ptr = try bdwgc.malloc(100);
    std.debug.print("ptr: {*}\n", .{ptr});
}
```

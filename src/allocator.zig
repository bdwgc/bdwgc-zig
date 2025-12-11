//! Implementation of the `std.mem.Allocator` interface using bdwgc.

const std = @import("std");

const build_options = @import("build_options");

const c = @import("./c.zig").c;

const Options = struct {
    atomic: bool,
    uncollectable: bool,
};

pub const allocator: std.mem.Allocator = .{
    .ptr = blk: {
        const options: Options = .{
            .atomic = false,
            .uncollectable = false,
        };
        break :blk @constCast(&options);
    },
    .vtable = &vtable,
};

pub const allocator_uncollectable: std.mem.Allocator = .{
    .ptr = blk: {
        const options: Options = .{
            .atomic = false,
            .uncollectable = true,
        };
        break :blk @constCast(&options);
    },
    .vtable = &vtable,
};

pub const allocator_atomic: std.mem.Allocator = .{
    .ptr = blk: {
        const options: Options = .{
            .atomic = true,
            .uncollectable = false,
        };
        break :blk @constCast(&options);
    },
    .vtable = &vtable,
};

pub const allocator_atomic_uncollectable: std.mem.Allocator = if (build_options.enable_atomic_uncollectable) .{
    .ptr = blk: {
        const options: Options = .{
            .atomic = true,
            .uncollectable = true,
        };
        break :blk @constCast(&options);
    },
    .vtable = &vtable,
} else @compileError("Requires enable_atomic_uncollectable option");

// NOTE: This is largely adapted from `std.heap.c_allocator`, excluding the `posix_memalign`
//       code paths because bdwgc does not offer an atomic variant of it.

const vtable: std.mem.Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn allocStrat(need_align: std.mem.Alignment) union(enum) {
    raw,
    manual_align,
} {
    if (std.mem.Alignment.compare(need_align, .lte, .of(std.c.max_align_t))) {
        return .raw;
    }
    return .manual_align;
}

fn manualAlignHeader(aligned_ptr: [*]u8) *[*]u8 {
    return @ptrCast(@alignCast(aligned_ptr - @sizeOf(usize)));
}

fn alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    return_address: usize,
) ?[*]u8 {
    _ = return_address;
    std.debug.assert(len > 0);
    const options: *const Options = @ptrCast(ctx);
    const malloc = switch (options.atomic) {
        false => switch (options.uncollectable) {
            false => &c.GC_malloc,
            true => &c.GC_malloc_uncollectable,
        },
        true => switch (options.uncollectable) {
            false => &c.GC_malloc_atomic,
            true => if (build_options.enable_atomic_uncollectable) &c.GC_malloc_atomic_uncollectable else unreachable,
        },
    };
    switch (allocStrat(alignment)) {
        .raw => {
            const actual_len = @max(len, @alignOf(std.c.max_align_t));
            const ptr = malloc(actual_len) orelse return null;
            std.debug.assert(alignment.check(@intFromPtr(ptr)));
            return @ptrCast(ptr);
        },
        .manual_align => {
            const padded_len = len + @sizeOf(usize) + alignment.toByteUnits() - 1;
            const unaligned_ptr: [*]u8 = @ptrCast(malloc(padded_len) orelse return null);
            const unaligned_addr = @intFromPtr(unaligned_ptr);
            const aligned_addr = alignment.forward(unaligned_addr + @sizeOf(usize));
            const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
            manualAlignHeader(aligned_ptr).* = unaligned_ptr;
            return aligned_ptr;
        },
    }
}

fn resize(
    _: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    return_address: usize,
) bool {
    _ = return_address;
    std.debug.assert(new_len > 0);
    if (new_len <= memory.len) {
        return true;
    }
    const usable_len: usize = switch (allocStrat(alignment)) {
        .raw => c.GC_size(memory.ptr),
        .manual_align => usable_len: {
            const unaligned_ptr = manualAlignHeader(memory.ptr).*;
            const full_len = c.GC_size(unaligned_ptr);
            const padding = @intFromPtr(memory.ptr) - @intFromPtr(unaligned_ptr);
            break :usable_len full_len - padding;
        },
    };
    return new_len <= usable_len;
}

fn remap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    return_address: usize,
) ?[*]u8 {
    std.debug.assert(new_len > 0);
    if (resize(ctx, memory, alignment, new_len, return_address)) {
        return memory.ptr;
    }
    switch (allocStrat(alignment)) {
        .raw => {
            const actual_len = @max(new_len, @alignOf(std.c.max_align_t));
            const new_ptr = c.GC_realloc(memory.ptr, actual_len) orelse return null;
            std.debug.assert(alignment.check(@intFromPtr(new_ptr)));
            return @ptrCast(new_ptr);
        },
        .manual_align => {
            return null;
        },
    }
}

fn free(
    _: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    return_address: usize,
) void {
    _ = return_address;
    switch (allocStrat(alignment)) {
        .raw => c.GC_free(memory.ptr),
        .manual_align => c.GC_free(manualAlignHeader(memory.ptr).*),
    }
}

test allocator {
    c.GC_init();
    try std.heap.testAllocator(allocator);
    try std.heap.testAllocatorAligned(allocator);
    try std.heap.testAllocatorAlignedShrink(allocator);
    try std.heap.testAllocatorLargeAlignment(allocator);
}

test allocator_uncollectable {
    c.GC_init();
    try std.heap.testAllocator(allocator_uncollectable);
    try std.heap.testAllocatorAligned(allocator_uncollectable);
    try std.heap.testAllocatorAlignedShrink(allocator_uncollectable);
    try std.heap.testAllocatorLargeAlignment(allocator_uncollectable);
}

test allocator_atomic {
    c.GC_init();
    try std.heap.testAllocator(allocator_atomic);
    try std.heap.testAllocatorAligned(allocator_atomic);
    try std.heap.testAllocatorAlignedShrink(allocator_atomic);
    try std.heap.testAllocatorLargeAlignment(allocator_atomic);
}

test allocator_atomic_uncollectable {
    if (!build_options.enable_atomic_uncollectable) return error.SkipZigTest;
    c.GC_init();
    try std.heap.testAllocator(allocator_atomic_uncollectable);
    try std.heap.testAllocatorAligned(allocator_atomic_uncollectable);
    try std.heap.testAllocatorAlignedShrink(allocator_atomic_uncollectable);
    try std.heap.testAllocatorLargeAlignment(allocator_atomic_uncollectable);
}

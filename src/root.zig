//! Zig language bindings for the [Boehm-Demers-Weiser Garbage Collector](https://github.com/bdwgc/bdwgc) (bdwgc).
//!
//! See [`gc.h`](https://github.com/bdwgc/bdwgc/blob/master/include/gc/gc.h) for documentation of the functions.

const std = @import("std");

const build_options = @import("build_options");

pub const c = @import("./c.zig").c;

comptime {
    // Ensure we can use `usize` in place of `GC_word` for Zig wrappers.
    std.debug.assert(@sizeOf(c.GC_word) == @sizeOf(usize));
}

pub const allocator = @import("./allocator.zig").allocator;
pub const allocator_uncollectable = @import("./allocator.zig").allocator_uncollectable;
pub const allocator_atomic = @import("./allocator.zig").allocator_atomic;
pub const allocator_atomic_uncollectable = @import("./allocator.zig").allocator_atomic_uncollectable;

pub const version: std.SemanticVersion = .{
    .major = c.GC_VERSION_MAJOR,
    .minor = c.GC_VERSION_MINOR,
    .patch = c.GC_VERSION_MICRO,
};

pub fn init() void {
    c.GC_init();
}

pub fn isInitCalled() bool {
    return c.GC_is_init_called() != 0;
}

pub fn deinit() void {
    c.GC_deinit();
}

pub fn disableWarnings() void {
    c.GC_set_warn_proc(c.GC_ignore_warn_proc);
}

pub fn malloc(size_in_bytes: usize) error{OutOfMemory}!*anyopaque {
    return c.GC_malloc(size_in_bytes) orelse return error.OutOfMemory;
}

pub fn mallocAtomic(size_in_bytes: usize) error{OutOfMemory}!*anyopaque {
    return c.GC_malloc_atomic(size_in_bytes) orelse return error.OutOfMemory;
}

pub fn mallocUncollectable(size_in_bytes: usize) error{OutOfMemory}!*anyopaque {
    return c.GC_malloc_uncollectable(size_in_bytes) orelse return error.OutOfMemory;
}

pub fn free(ptr: *anyopaque) void {
    c.GC_free(ptr);
}

pub fn strdup(str: [*:0]const u8) error{OutOfMemory}![*:0]u8 {
    return c.GC_strdup(str) orelse return error.OutOfMemory;
}

pub fn strndup(str: [*:0]const u8, len: usize) error{OutOfMemory}![*:0]u8 {
    return c.GC_strndup(str, len) orelse return error.OutOfMemory;
}

pub fn memalign(alignment: std.mem.Alignment, size_in_bytes: usize) error{OutOfMemory}!*anyopaque {
    return c.GC_memalign(alignment.toByteUnits(), size_in_bytes) orelse return error.OutOfMemory;
}

pub fn base(ptr: *const anyopaque) ?*anyopaque {
    // TODO: Fix const-correctness in the C API
    return c.GC_base(@constCast(ptr));
}

pub fn isHeapPointer(ptr: *const anyopaque) bool {
    return c.GC_is_heap_ptr(ptr) != 0;
}

pub fn size(ptr: *const anyopaque) usize {
    return c.GC_size(ptr);
}

pub const HeapSize = enum(usize) {
    unbounded = 0,
    _,
};

pub fn setMaxHeapSize(heap_size: HeapSize) void {
    c.GC_set_max_heap_size(@intFromEnum(heap_size));
}

pub fn gcollect() void {
    c.GC_gcollect();
}

pub fn gcollectAndUnmap() void {
    c.GC_gcollect_and_unmap();
}

pub const ProfStats = struct {
    heapsize_full: usize,
    free_bytes_full: usize,
    unmapped_bytes: usize,
    bytes_allocd_since_gc: usize,
    allocd_bytes_before_gc: usize,
    non_gc_bytes: usize,
    gc_no: usize,
    markers_m1: usize,
    bytes_reclaimed_since_gc: usize,
    reclaimed_bytes_before_gc: usize,
    expl_freed_bytes_since_gc: usize,
    obtained_from_os_bytes: usize,
};

pub fn getProfStats() ProfStats {
    var prof_stats: c.GC_prof_stats_s = undefined;
    _ = c.GC_get_prof_stats(&prof_stats, @sizeOf(c.GC_prof_stats_s));
    return .{
        .heapsize_full = prof_stats.heapsize_full,
        .free_bytes_full = prof_stats.free_bytes_full,
        .unmapped_bytes = prof_stats.unmapped_bytes,
        .bytes_allocd_since_gc = prof_stats.bytes_allocd_since_gc,
        .allocd_bytes_before_gc = prof_stats.allocd_bytes_before_gc,
        .non_gc_bytes = prof_stats.non_gc_bytes,
        .gc_no = prof_stats.gc_no,
        .markers_m1 = prof_stats.markers_m1,
        .bytes_reclaimed_since_gc = prof_stats.bytes_reclaimed_since_gc,
        .reclaimed_bytes_before_gc = prof_stats.reclaimed_bytes_before_gc,
        .expl_freed_bytes_since_gc = prof_stats.expl_freed_bytes_since_gc,
        .obtained_from_os_bytes = prof_stats.obtained_from_os_bytes,
    };
}

pub fn getMemoryUse() usize {
    return c.GC_get_memory_use();
}

pub fn disable() void {
    c.GC_disable();
}

pub fn isDisabled() bool {
    return c.GC_is_disabled() != 0;
}

pub fn enable() void {
    c.GC_enable();
}

pub fn enableIncremental() void {
    c.GC_enable_incremental();
}

pub fn isIncrementalMode() bool {
    return c.GC_is_incremental_mode() != 0;
}

pub fn startMarkThreads() void {
    c.GC_start_mark_threads();
}

pub fn setPointerMask(value: usize) void {
    if (!build_options.enable_dynamic_pointer_mask) {
        @compileError("Requires enable_dynamic_pointer_mask option");
    }
    c.GC_set_pointer_mask(value);
}

pub fn getPointerMask() usize {
    if (!build_options.enable_dynamic_pointer_mask) {
        @compileError("Requires enable_dynamic_pointer_mask option");
    }
    return c.GC_get_pointer_mask();
}

const ShiftType = std.math.Log2Int(usize);

pub fn setPointerShift(value: ShiftType) void {
    if (!build_options.enable_dynamic_pointer_mask) {
        @compileError("Requires enable_dynamic_pointer_mask option");
    }
    c.GC_set_pointer_shift(value);
}

pub fn getPointerShift() ShiftType {
    if (!build_options.enable_dynamic_pointer_mask) {
        @compileError("Requires enable_dynamic_pointer_mask option");
    }
    return @intCast(c.GC_get_pointer_shift());
}

pub const Finalizer = *const fn (object: *anyopaque, data: ?*anyopaque) callconv(.c) void;

pub const FinalizerAndData = struct {
    finalizer: Finalizer,
    data: ?*anyopaque,
};

pub fn registerFinalizer(
    object: *anyopaque,
    finalizer: Finalizer,
    data: ?*anyopaque,
) ?FinalizerAndData {
    var old_finalizer: ?Finalizer = null;
    var old_data: ?*anyopaque = null;
    // @ptrCast() to allow typing the `object` parameter as non-null. Not 100% sure if this is safe.
    c.GC_register_finalizer(object, @ptrCast(finalizer), data, &old_finalizer, &old_data);
    if (old_finalizer != null) {
        return .{ .finalizer = old_finalizer.?, .data = old_data };
    }
    return null;
}

pub fn unregisterFinalizer(object: *anyopaque) ?FinalizerAndData {
    var old_finalizer: ?Finalizer = null;
    var old_data: ?*anyopaque = null;
    c.GC_register_finalizer(object, null, null, &old_finalizer, &old_data);
    if (old_finalizer != null) {
        return .{ .finalizer = old_finalizer.?, .data = old_data };
    }
    return null;
}

pub const RegisterDisappearingLinkError = error{ OutOfMemory, DuplicateLink };

pub fn registerDisappearingLink(link: *?*anyopaque, object: *const anyopaque) RegisterDisappearingLinkError!void {
    // `GC_register_disappearing_link` only exists for backwards compatibility and suggests to use
    // `GC_general_register_disappearing_link` instead, hence the naming mismatch.
    const status = c.GC_general_register_disappearing_link(link, object);
    switch (status) {
        // No-op in find-leak mode
        c.GC_SUCCESS, c.GC_UNIMPLEMENTED => {},
        c.GC_DUPLICATE => return error.DuplicateLink,
        c.GC_NO_MEMORY => return error.OutOfMemory,
        else => unreachable,
    }
}

pub fn unregisterDisappearingLink(link: *?*anyopaque) bool {
    return c.GC_unregister_disappearing_link(link) != 0;
}

// NOTE: Because re-initializing the GC after `deinit()` is not guaranteed to work none of these tests call it.

test {
    _ = @import("./allocator.zig");
}

test version {
    const expected_version: std.SemanticVersion = .{
        .major = 8,
        .minor = 3,
        .patch = 0,
    };
    try std.testing.expectEqual(expected_version, version);
}

test malloc {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);
    try std.testing.expect(@intFromPtr(ptr) != 0);
}

test mallocAtomic {
    init();
    disableWarnings();
    const ptr = try mallocAtomic(100);
    defer free(ptr);
    try std.testing.expect(@intFromPtr(ptr) != 0);
}

test mallocUncollectable {
    init();
    disableWarnings();
    const ptr = try mallocUncollectable(100);
    defer free(ptr);
    try std.testing.expect(@intFromPtr(ptr) != 0);
}

test strdup {
    init();
    disableWarnings();
    const original = "Hello, World!";
    const duplicated = try strdup(original);
    defer free(duplicated);
    try std.testing.expectEqualStrings(original, std.mem.sliceTo(duplicated, 0));
}

test strndup {
    init();
    disableWarnings();
    const original = "Hello, World!";
    const duplicated = try strndup(original, 5);
    defer free(duplicated);
    try std.testing.expectEqualStrings("Hello", std.mem.sliceTo(duplicated, 0));
}

test memalign {
    init();
    disableWarnings();
    const alignment: std.mem.Alignment = .@"16";
    const ptr = try memalign(alignment, 100);
    defer free(ptr);
    try std.testing.expect(std.mem.isAligned(@intFromPtr(ptr), alignment.toByteUnits()));
}

test base {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);
    try std.testing.expectEqual(ptr, base(ptr));
    try std.testing.expectEqual(ptr, base(@ptrFromInt(@intFromPtr(ptr) + 10)));
    try std.testing.expectEqual(@as(?*anyopaque, null), base(@ptrFromInt(42)));
}

test isHeapPointer {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);
    try std.testing.expect(isHeapPointer(ptr));
    try std.testing.expect(!isHeapPointer(@ptrFromInt(42)));
    var foo: u8 = 123;
    try std.testing.expect(!isHeapPointer(&foo));
}

test size {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);
    try std.testing.expect(size(ptr) >= 100);
}

test setMaxHeapSize {
    init();
    disableWarnings();
    // Needs to be bigger than the current heap size
    setMaxHeapSize(@enumFromInt(100_000));
    defer setMaxHeapSize(.unbounded);
    try std.testing.expectError(error.OutOfMemory, malloc(1_000_000));
}

test gcollect {
    init();
    disableWarnings();
    gcollect();
}

test gcollectAndUnmap {
    init();
    disableWarnings();
    gcollectAndUnmap();
}

test getProfStats {
    init();
    disableWarnings();
    const ptr = try malloc(1000);
    gcollect();
    free(ptr);

    const stats = getProfStats();
    try std.testing.expect(stats.heapsize_full >= 1000);
    try std.testing.expect(stats.free_bytes_full >= 0);
    try std.testing.expect(stats.bytes_allocd_since_gc == 0);
    try std.testing.expect(stats.allocd_bytes_before_gc >= 1000);
    try std.testing.expect(stats.non_gc_bytes >= 1000);
    try std.testing.expect(stats.gc_no >= 1);
    try std.testing.expect(stats.markers_m1 >= 0);
    try std.testing.expect(stats.bytes_reclaimed_since_gc >= 0);
    try std.testing.expect(stats.reclaimed_bytes_before_gc >= 0);
    try std.testing.expect(stats.expl_freed_bytes_since_gc >= 1000);
    try std.testing.expect(stats.obtained_from_os_bytes >= 1000);
}

test getMemoryUse {
    init();
    disableWarnings();
    const ptr = try malloc(1000);
    defer free(ptr);
    const memory_use = getMemoryUse();
    try std.testing.expect(memory_use >= 1000);
}

test disable {
    init();
    disableWarnings();
    try std.testing.expect(!isDisabled());
    disable();
    try std.testing.expect(isDisabled());
    enable();
    try std.testing.expect(!isDisabled());
}

test setPointerMask {
    if (!build_options.enable_dynamic_pointer_mask) return error.SkipZigTest;
    init();
    try std.testing.expectEqual(std.math.maxInt(usize), getPointerMask());
    setPointerMask(0xffff);
    try std.testing.expectEqual(0xffff, getPointerMask());
    setPointerMask(std.math.maxInt(usize));
    try std.testing.expectEqual(std.math.maxInt(usize), getPointerMask());
}

test setPointerShift {
    if (!build_options.enable_dynamic_pointer_mask) return error.SkipZigTest;
    init();
    try std.testing.expectEqual(0, getPointerShift());
    setPointerShift(4);
    try std.testing.expectEqual(4, getPointerShift());
    setPointerShift(0);
    try std.testing.expectEqual(0, getPointerShift());
}

test registerFinalizer {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);

    const finalizer = struct {
        fn finalizer(_: *anyopaque, _: ?*anyopaque) callconv(.c) void {}
    }.finalizer;

    {
        const old = registerFinalizer(ptr, finalizer, null);
        try std.testing.expect(old == null);
    }
    {
        const old = registerFinalizer(ptr, finalizer, null);
        try std.testing.expect(old.?.finalizer == finalizer);
        try std.testing.expect(old.?.data == null);
    }

    // Not unregistering the finalizer may cause the next test to fail if the same `ptr` is reused
    _ = unregisterFinalizer(ptr);
}

test unregisterFinalizer {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);

    const finalizer = struct {
        fn finalizer(_: *anyopaque, _: ?*anyopaque) callconv(.c) void {}
    }.finalizer;

    _ = registerFinalizer(ptr, finalizer, null);
    {
        const old = unregisterFinalizer(ptr);
        try std.testing.expect(old.?.finalizer == finalizer);
        try std.testing.expect(old.?.data == null);
    }
    {
        const old = unregisterFinalizer(ptr);
        try std.testing.expect(old == null);
    }
}

test registerDisappearingLink {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);

    var weak_ptr: ?*anyopaque = ptr;
    try registerDisappearingLink(&weak_ptr, ptr);
    try std.testing.expect(weak_ptr != null);
    // We can not test the unlink behavior:
    // "Explicit deallocation of `obj` may or may not cause `link` to eventually be cleared."

    // Weird: This segfaults when inlining the call into expectError() but works fine like this. Zig bug?
    const err = registerDisappearingLink(&weak_ptr, ptr);
    try std.testing.expectError(error.DuplicateLink, err);

    // Not unregistering the disappearing link may cause the next test to fail if the same `ptr` is reused
    _ = unregisterDisappearingLink(&weak_ptr);
}

test unregisterDisappearingLink {
    init();
    disableWarnings();
    const ptr = try malloc(100);
    defer free(ptr);

    var weak_ptr: ?*anyopaque = ptr;
    try std.testing.expect(!unregisterDisappearingLink(&weak_ptr));
    try registerDisappearingLink(&weak_ptr, ptr);
    try std.testing.expect(unregisterDisappearingLink(&weak_ptr));
    try std.testing.expect(!unregisterDisappearingLink(&weak_ptr));
}

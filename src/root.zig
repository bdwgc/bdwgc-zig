const std = @import("std");

const c = @import("./c.zig").c;

pub const version: std.SemanticVersion = .{
    .major = c.GC_VERSION_MAJOR,
    .minor = c.GC_VERSION_MINOR,
    .patch = c.GC_VERSION_MICRO,
};

test version {
    const expected_version: std.SemanticVersion = .{
        .major = 8,
        .minor = 3,
        .patch = 0,
    };
    try std.testing.expectEqual(expected_version, version);
}

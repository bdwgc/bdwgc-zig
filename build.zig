const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Copied from https://github.com/bdwgc/bdwgc/blob/master/build.zig
    const default_enable_threads = !target.result.cpu.arch.isWasm();
    const enable_cplusplus = b.option(bool, "enable_cplusplus", "C++ support") orelse false;
    const linkage = b.option(std.builtin.LinkMode, "linkage", "Build shared libraries (otherwise static ones)") orelse .dynamic;
    const build_cord = b.option(bool, "build_cord", "Build cord library") orelse true;
    const cflags_extra = b.option([]const u8, "CFLAGS_EXTRA", "Extra user-defined cflags") orelse "";
    const enable_threads = b.option(bool, "enable_threads", "Support threads") orelse default_enable_threads;
    const enable_parallel_mark = b.option(bool, "enable_parallel_mark", "Parallelize marking and free list construction") orelse true;
    const enable_thread_local_alloc = b.option(bool, "enable_thread_local_alloc", "Turn on thread-local allocation optimization") orelse true;
    const enable_threads_discovery = b.option(bool, "enable_threads_discovery", "Enable threads discovery in GC") orelse true;
    const enable_rwlock = b.option(bool, "enable_rwlock", "Enable reader mode of the allocator lock") orelse false;
    const enable_throw_bad_alloc_library = b.option(bool, "enable_throw_bad_alloc_library", "Turn on C++ gctba library build") orelse true;
    const enable_gcj_support = b.option(bool, "enable_gcj_support", "Support for gcj") orelse true;
    const enable_sigrt_signals = b.option(bool, "enable_sigrt_signals", "Use SIGRTMIN-based signals for thread suspend/resume") orelse false;
    const enable_valgrind_tracking = b.option(bool, "enable_valgrind_tracking", "Support tracking GC_malloc and friends for heap profiling tools") orelse false;
    const enable_gc_debug = b.option(bool, "enable_gc_debug", "Support for pointer back-tracing") orelse false;
    const enable_gc_dump = b.option(bool, "enable_gc_dump", "Enable GC_dump and similar debugging facility") orelse true;
    const enable_java_finalization = b.option(bool, "enable_java_finalization", "Support for java finalization") orelse true;
    const enable_atomic_uncollectable = b.option(bool, "enable_atomic_uncollectable", "Support for atomic uncollectible allocation") orelse true;
    const enable_redirect_malloc = b.option(bool, "enable_redirect_malloc", "Redirect malloc and friend to GC routines") orelse false;
    const enable_uncollectable_redirection = b.option(bool, "enable_uncollectable_redirection", "Redirect to uncollectible malloc instead of garbage-collected one") orelse false;
    const enable_disclaim = b.option(bool, "enable_disclaim", "Support alternative finalization interface") orelse true;
    const enable_dynamic_pointer_mask = b.option(bool, "enable_dynamic_pointer_mask", "Support pointer mask/shift set at runtime") orelse false;
    const enable_large_config = b.option(bool, "enable_large_config", "Optimize for large heap or root set") orelse false;
    const enable_gc_assertions = b.option(bool, "enable_gc_assertions", "Enable collector-internal assertion checking") orelse false;
    const enable_mmap = b.option(bool, "enable_mmap", "Use mmap instead of sbrk to expand the heap") orelse false;
    const enable_munmap = b.option(bool, "enable_munmap", "Return page to the OS if empty for N collections") orelse true;
    const enable_dynamic_loading = b.option(bool, "enable_dynamic_loading", "Enable tracing of dynamic library data roots") orelse true;
    const enable_register_main_static_data = b.option(bool, "enable_register_main_static_data", "Perform the initial guess of data root sets") orelse true;
    const enable_checksums = b.option(bool, "enable_checksums", "Report erroneously cleared dirty bits") orelse false;
    const enable_werror = b.option(bool, "enable_werror", "Pass -Werror to the C compiler (treat warnings as errors)") orelse false;
    const enable_single_obj_compilation = b.option(bool, "enable_single_obj_compilation", "Compile all libgc source files into single .o") orelse false;
    const disable_single_obj_compilation = b.option(bool, "disable_single_obj_compilation", "Compile each libgc source file independently") orelse false;
    const enable_handle_fork = b.option(bool, "enable_handle_fork", "Attempt to ensure a usable collector after fork()") orelse true;
    const disable_handle_fork = b.option(bool, "disable_handle_fork", "Prohibit installation of pthread_atfork() handlers") orelse false;
    const install_headers = b.option(bool, "install_headers", "Install header and pkg-config metadata files") orelse true;

    const bdwgc = b.dependency("bdwgc", .{
        .target = target,
        .optimize = optimize,
        .enable_cplusplus = enable_cplusplus,
        .linkage = linkage,
        .build_cord = build_cord,
        .CFLAGS_EXTRA = cflags_extra,
        .enable_threads = enable_threads,
        .enable_parallel_mark = enable_parallel_mark,
        .enable_thread_local_alloc = enable_thread_local_alloc,
        .enable_threads_discovery = enable_threads_discovery,
        .enable_rwlock = enable_rwlock,
        .enable_throw_bad_alloc_library = enable_throw_bad_alloc_library,
        .enable_gcj_support = enable_gcj_support,
        .enable_sigrt_signals = enable_sigrt_signals,
        .enable_valgrind_tracking = enable_valgrind_tracking,
        .enable_gc_debug = enable_gc_debug,
        .enable_gc_dump = enable_gc_dump,
        .enable_java_finalization = enable_java_finalization,
        .enable_atomic_uncollectable = enable_atomic_uncollectable,
        .enable_redirect_malloc = enable_redirect_malloc,
        .enable_uncollectable_redirection = enable_uncollectable_redirection,
        .enable_disclaim = enable_disclaim,
        .enable_dynamic_pointer_mask = enable_dynamic_pointer_mask,
        .enable_large_config = enable_large_config,
        .enable_gc_assertions = enable_gc_assertions,
        .enable_mmap = enable_mmap,
        .enable_munmap = enable_munmap,
        .enable_dynamic_loading = enable_dynamic_loading,
        .enable_register_main_static_data = enable_register_main_static_data,
        .enable_checksums = enable_checksums,
        .enable_werror = enable_werror,
        .enable_single_obj_compilation = enable_single_obj_compilation,
        .disable_single_obj_compilation = disable_single_obj_compilation,
        .enable_handle_fork = enable_handle_fork,
        .disable_handle_fork = disable_handle_fork,
        .install_headers = install_headers,
    });

    // Ensure options declared above stay in sync with bdwgc's build.zig
    for (bdwgc.builder.available_options_list.items) |option| {
        if (!b.available_options_map.contains(option.name)) {
            std.debug.panic("Option missing: {s}", .{option.name});
        }
    }

    const options = b.addOptions();
    options.addOption(bool, "enable_atomic_uncollectable", enable_atomic_uncollectable);
    options.addOption(bool, "enable_dynamic_pointer_mask", enable_dynamic_pointer_mask);

    const module = b.addModule("bdwgc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = options.createModule() },
        },
    });
    module.linkLibrary(bdwgc.artifact("gc"));

    const tests = b.addTest(.{
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    const docs = b.addObject(.{
        .name = "bdwgc-zig",
        .root_module = module,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Build and install documentation");
    docs_step.dependOn(&install_docs.step);
}

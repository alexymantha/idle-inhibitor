const std = @import("std");
pub const c = @cImport({
    @cInclude("wayland-client-protocol.h");
    @cInclude("wayland-idle-inhibit-unstable-v1-client-protocol.h");
});

const Self = @This();
pub var instance: ?*Self = null;

display: ?*c.wl_display,
compositor: ?*c.wl_compositor,
surface: ?*c.wl_surface,

idle_inhibit_manager: ?*c.zwp_idle_inhibit_manager_v1,
idle_inhibitor: ?*c.zwp_idle_inhibitor_v1,

pub fn init() !Self {
    return Self{
        .display = c.wl_display_connect(null),
        .compositor = null,
        .surface = null,
        .idle_inhibit_manager = null,
        .idle_inhibitor = null,
    };
}

pub fn start(self: *Self) !void {
    if (instance == null) {
        @panic("instance must be initialized before calling start");
    }

    const registry = c.wl_display_get_registry(self.display) orelse return error.FailedToGetDisplayRegistry;
    std.log.info("wayland: registering listener", .{});
    if (c.wl_registry_add_listener(registry, &registry_listener.listener, null) != 0) {
        return error.ListenerHasAlreadyBeenSet;
    }

    std.log.info("wayland: round trip", .{});
    _ = c.wl_display_roundtrip(self.display);

    std.log.info("wayland: creating surface", .{});
    self.surface = c.wl_compositor_create_surface(self.compositor) orelse return error.UnableToCreateSurface;
}

pub fn deinit(self: *Self) void {
    std.log.info("wayland: cleaning up", .{});
    c.wl_display_disconnect(self.display);
    if (self.surface != null) c.wl_surface_destroy(self.surface);
    if (self.idle_inhibitor != null) c.zwp_idle_inhibitor_v1_destroy(self.idle_inhibitor);
}

pub fn disable(self: *Self) void {
    if (self.idle_inhibitor == null) return;
    _ = c.zwp_idle_inhibitor_v1_destroy(self.idle_inhibitor);
}

pub fn enable(self: *Self) void {
    if (self.idle_inhibitor != null) return;
    if (self.idle_inhibit_manager == null) {
        @panic("tried to enable idle inhibitor without idle inhibit manager");
    }
    _ = c.zwp_idle_inhibit_manager_v1_create_inhibitor(self.idle_inhibit_manager, self.surface);
}

const registry_listener = struct {
    fn registryHandleGlobal(_: u64, registry: ?*c.struct_wl_registry, name: u32, interface_ptr: [*:0]const u8, version: u32) callconv(.C) void {
        const interface = std.mem.span(interface_ptr);

        if (std.mem.eql(u8, "wl_compositor", interface)) {
            instance.?.compositor = @ptrCast(c.wl_registry_bind(
                registry,
                name,
                &c.wl_compositor_interface,
                @min(3, version),
            ) orelse @panic("uh idk how to proceed"));
        } else if (std.mem.eql(u8, "zwp_idle_inhibit_manager_v1", interface)) {
            instance.?.idle_inhibit_manager = @ptrCast(c.wl_registry_bind(
                registry,
                name,
                &c.zwp_idle_inhibit_manager_v1_interface,
                @min(1, version),
            ) orelse @panic("uh idk how to proceed"));
        } else {
            // No changes made to `wl`, so exit function
            return;
        }
    }

    fn registryHandleGlobalRemove(window_id: u64, registry: ?*c.struct_wl_registry, name: u32) callconv(.C) void {
        _ = window_id;
        _ = registry;
        _ = name;
    }

    const listener = c.wl_registry_listener{
        // ptrcast is for the [*:0] -> [*c] conversion, silly yes
        .global = @ptrCast(&registryHandleGlobal),
        // ptrcast is for the wl param, which is guarenteed to be our type (and if its not, it should be caught by safety checks)
        .global_remove = @ptrCast(&registryHandleGlobalRemove),
    };
};

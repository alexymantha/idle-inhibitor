const std = @import("std");
const Idler = @import("Idler.zig");

pub const Monitor = struct {
    running: bool = false,
    allocator: std.mem.Allocator,
    idler: *Idler,

    pub fn init(allocator: std.mem.Allocator, idler: *Idler) Monitor {
        return Monitor{
            .allocator = allocator,
            .idler = idler,
        };
    }

    pub fn start(self: *Monitor) !void {
        self.running = true;
        _ = try std.Thread.spawn(.{}, Monitor.loop, .{self});
    }

    pub fn stop(self: *Monitor) void {
        self.running = false;
    }

    fn loop(self: *Monitor) !void {
        while (true) {
            if (!self.running) {
                std.log.info("monitor: stopping", .{});
                break;
            }
            try self.tick();
            std.time.sleep(std.time.ns_per_s * 10);
        }
    }

    fn tick(self: *Monitor) !void {
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{"who"},
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);
        // If pts is in the output we assume there is a remote session
        // it could be an SSH or Telnet session
        const i = std.mem.indexOf(u8, result.stdout, "pts");
        if (i == null) {
            std.log.info("monitor: no remote session, disabling inhibitor", .{});
            self.idler.disable();
        } else {
            std.log.info("monitor: found remote session, enabling inhibitor", .{});
            self.idler.enable();
        }
    }
};

const std = @import("std");
const Idler = @import("Idler.zig");
const ssh = @import("ssh.zig");

pub fn main() !void {
    var idler = try Idler.init();
    defer idler.deinit();
    Idler.instance = &idler;
    try idler.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var ssh_mon = ssh.Monitor.init(allocator, &idler);
    try ssh_mon.start();
    ssh_mon.stop();

    idler.enable();

    while (true) {}
}

const std = @import("std");
const war_zig = @import("war_zig");

pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch break :blk 0;
        break :blk seed;
    });
    const random = prng.random();

    var deck = war_zig.Deck.init();
    deck.shuffle(random);

    std.debug.print("Shuffled deck:\n", .{});
    for (deck.cards, 0..) |card, i| {
        std.debug.print("{d:2}: {f}\n", .{ i + 1, card });
    }
}

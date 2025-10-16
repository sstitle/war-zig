//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const Suit = enum {
    hearts,
    diamonds,
    clubs,
    spades,
};

pub const Rank = enum(u8) {
    two = 2,
    three = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
    eight = 8,
    nine = 9,
    ten = 10,
    jack = 11,
    queen = 12,
    king = 13,
    ace = 14,

    pub fn value(self: Rank) u8 {
        return @intFromEnum(self);
    }
};

pub const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn init(suit: Suit, rank: Rank) Card {
        return Card{
            .suit = suit,
            .rank = rank,
        };
    }
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "Card initialization" {
    const card = Card.init(.hearts, .ace);
    try std.testing.expectEqual(Suit.hearts, card.suit);
    try std.testing.expectEqual(Rank.ace, card.rank);
}

test "Rank values" {
    try std.testing.expectEqual(@as(u8, 2), Rank.two.value());
    try std.testing.expectEqual(@as(u8, 10), Rank.ten.value());
    try std.testing.expectEqual(@as(u8, 11), Rank.jack.value());
    try std.testing.expectEqual(@as(u8, 14), Rank.ace.value());
}

test "Rank comparison" {
    try std.testing.expect(Rank.ace.value() > Rank.king.value());
    try std.testing.expect(Rank.two.value() < Rank.three.value());
    try std.testing.expect(Rank.queen.value() == Rank.queen.value());
}

test "All suits defined" {
    const suits = [_]Suit{ .hearts, .diamonds, .clubs, .spades };
    try std.testing.expectEqual(@as(usize, 4), suits.len);
}

test "All ranks defined" {
    const ranks = [_]Rank{
        .two,  .three, .four, .five,  .six,  .seven, .eight,
        .nine, .ten,   .jack, .queen, .king, .ace,
    };
    try std.testing.expectEqual(@as(usize, 13), ranks.len);
}

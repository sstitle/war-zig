//! Card game primitives: suits, ranks, and card representation.
//!
//! This module provides the fundamental types for representing playing cards.
//! All types are value types with no dynamic allocation.

const std = @import("std");

/// The four standard playing card suits.
pub const Suit = enum {
    hearts,
    diamonds,
    clubs,
    spades,

    /// Returns the string representation of the suit.
    pub fn toString(self: Suit) []const u8 {
        return switch (self) {
            .hearts => "Hearts",
            .diamonds => "Diamonds",
            .clubs => "Clubs",
            .spades => "Spades",
        };
    }
};

/// Card ranks from 2 to Ace with their comparative values.
/// Backed by u8 for efficient comparisons (2=lowest, 14=Ace=highest).
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

    /// Returns the numeric value of the rank (2-14).
    pub fn value(self: Rank) u8 {
        return @intFromEnum(self);
    }

    /// Returns the string representation of the rank.
    pub fn toString(self: Rank) []const u8 {
        return switch (self) {
            .two => "2",
            .three => "3",
            .four => "4",
            .five => "5",
            .six => "6",
            .seven => "7",
            .eight => "8",
            .nine => "9",
            .ten => "10",
            .jack => "Jack",
            .queen => "Queen",
            .king => "King",
            .ace => "Ace",
        };
    }
};

/// A standard playing card with a suit and rank.
pub const Card = struct {
    suit: Suit,
    rank: Rank,

    /// Creates a new card with the given suit and rank.
    pub fn init(suit: Suit, rank: Rank) Card {
        return Card{
            .suit = suit,
            .rank = rank,
        };
    }

    /// Formats the card for printing (e.g., "Ace of Spades").
    pub fn format(self: Card, writer: anytype) !void {
        try writer.print("{s} of {s}", .{ self.rank.toString(), self.suit.toString() });
    }
};

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

test "Suit toString" {
    try std.testing.expectEqualStrings("Hearts", Suit.hearts.toString());
    try std.testing.expectEqualStrings("Diamonds", Suit.diamonds.toString());
    try std.testing.expectEqualStrings("Clubs", Suit.clubs.toString());
    try std.testing.expectEqualStrings("Spades", Suit.spades.toString());
}

test "Rank toString" {
    try std.testing.expectEqualStrings("2", Rank.two.toString());
    try std.testing.expectEqualStrings("10", Rank.ten.toString());
    try std.testing.expectEqualStrings("Jack", Rank.jack.toString());
    try std.testing.expectEqualStrings("Ace", Rank.ace.toString());
}

test "Card format" {
    const card = Card.init(.hearts, .ace);
    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{card});
    try std.testing.expectEqualStrings("Ace of Hearts", result);
}

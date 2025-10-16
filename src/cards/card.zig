//! Playing card representation.
//!
//! Combines a suit and rank to represent a standard playing card.

const std = @import("std");

// Re-export Suit and Rank for convenience
pub const Suit = @import("suit.zig").Suit;
pub const Rank = @import("rank.zig").Rank;

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

test "Card format" {
    const card = Card.init(.hearts, .ace);
    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{card});
    try std.testing.expectEqualStrings("Ace of Hearts", result);
}

//! Playing card suits.
//!
//! Defines the four standard playing card suits.

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

test "All suits defined" {
    const suits = [_]Suit{ .hearts, .diamonds, .clubs, .spades };
    try std.testing.expectEqual(@as(usize, 4), suits.len);
}

test "Suit toString" {
    try std.testing.expectEqualStrings("Hearts", Suit.hearts.toString());
    try std.testing.expectEqualStrings("Diamonds", Suit.diamonds.toString());
    try std.testing.expectEqualStrings("Clubs", Suit.clubs.toString());
    try std.testing.expectEqualStrings("Spades", Suit.spades.toString());
}

//! Playing card ranks.
//!
//! Defines card ranks from 2 to Ace with their comparative values.

const std = @import("std");

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

test "All ranks defined" {
    const ranks = [_]Rank{
        .two,  .three, .four, .five,  .six,  .seven, .eight,
        .nine, .ten,   .jack, .queen, .king, .ace,
    };
    try std.testing.expectEqual(@as(usize, 13), ranks.len);
}

test "Rank toString" {
    try std.testing.expectEqualStrings("2", Rank.two.toString());
    try std.testing.expectEqualStrings("10", Rank.ten.toString());
    try std.testing.expectEqualStrings("Jack", Rank.jack.toString());
    try std.testing.expectEqualStrings("Ace", Rank.ace.toString());
}

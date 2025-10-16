//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const Suit = enum {
    hearts,
    diamonds,
    clubs,
    spades,

    pub fn toString(self: Suit) []const u8 {
        return switch (self) {
            .hearts => "Hearts",
            .diamonds => "Diamonds",
            .clubs => "Clubs",
            .spades => "Spades",
        };
    }
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

pub const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn init(suit: Suit, rank: Rank) Card {
        return Card{
            .suit = suit,
            .rank = rank,
        };
    }

    pub fn format(self: Card, writer: anytype) !void {
        try writer.print("{s} of {s}", .{ self.rank.toString(), self.suit.toString() });
    }
};

pub const Deck = struct {
    cards: [52]Card,

    pub fn init() Deck {
        var deck: Deck = undefined;
        var index: usize = 0;

        const suits = [_]Suit{ .hearts, .diamonds, .clubs, .spades };
        const ranks = [_]Rank{
            .two,  .three, .four, .five,  .six,  .seven, .eight,
            .nine, .ten,   .jack, .queen, .king, .ace,
        };

        for (suits) |suit| {
            for (ranks) |rank| {
                deck.cards[index] = Card.init(suit, rank);
                index += 1;
            }
        }

        return deck;
    }

    pub fn shuffle(self: *Deck, random: std.Random) void {
        var i: usize = self.cards.len - 1;
        while (i > 0) : (i -= 1) {
            const j = random.intRangeLessThan(usize, 0, i + 1);
            const temp = self.cards[i];
            self.cards[i] = self.cards[j];
            self.cards[j] = temp;
        }
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

test "Deck initialization" {
    const deck = Deck.init();
    try std.testing.expectEqual(@as(usize, 52), deck.cards.len);

    // Verify first card (hearts, two)
    try std.testing.expectEqual(Suit.hearts, deck.cards[0].suit);
    try std.testing.expectEqual(Rank.two, deck.cards[0].rank);

    // Verify last card (spades, ace)
    try std.testing.expectEqual(Suit.spades, deck.cards[51].suit);
    try std.testing.expectEqual(Rank.ace, deck.cards[51].rank);
}

test "Deck shuffle changes order" {
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    var deck1 = Deck.init();
    const deck2 = Deck.init();

    deck1.shuffle(random);

    // After shuffle, at least some cards should be in different positions
    var differences: usize = 0;
    for (deck1.cards, deck2.cards) |card1, card2| {
        if (card1.suit != card2.suit or card1.rank != card2.rank) {
            differences += 1;
        }
    }

    // Expect significant reordering (at least 40 out of 52 cards moved)
    try std.testing.expect(differences > 40);
}

test "Deck contains all unique cards" {
    const deck = Deck.init();

    // Check that we have exactly 13 cards of each suit
    var hearts_count: usize = 0;
    var diamonds_count: usize = 0;
    var clubs_count: usize = 0;
    var spades_count: usize = 0;

    for (deck.cards) |card| {
        switch (card.suit) {
            .hearts => hearts_count += 1,
            .diamonds => diamonds_count += 1,
            .clubs => clubs_count += 1,
            .spades => spades_count += 1,
        }
    }

    try std.testing.expectEqual(@as(usize, 13), hearts_count);
    try std.testing.expectEqual(@as(usize, 13), diamonds_count);
    try std.testing.expectEqual(@as(usize, 13), clubs_count);
    try std.testing.expectEqual(@as(usize, 13), spades_count);
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

//! Standard 52-card deck implementation with shuffling support.

const std = @import("std");
const card = @import("card.zig");

/// A standard 52-card deck (13 ranks × 4 suits).
pub const Deck = struct {
    cards: [52]card.Card,

    /// Initializes a deck in standard order: Hearts, Diamonds, Clubs, Spades,
    /// with ranks from 2 to Ace in each suit.
    pub fn init() Deck {
        var deck: Deck = undefined;
        var index: usize = 0;

        const suits = [_]card.Suit{ .hearts, .diamonds, .clubs, .spades };
        const ranks = [_]card.Rank{
            .two,  .three, .four, .five,  .six,  .seven, .eight,
            .nine, .ten,   .jack, .queen, .king, .ace,
        };

        for (suits) |suit| {
            for (ranks) |rank| {
                deck.cards[index] = card.Card{ .suit = suit, .rank = rank };
                index += 1;
            }
        }

        return deck;
    }

    /// Shuffles the deck using the Fisher-Yates algorithm.
    pub fn shuffle(self: *Deck, random: std.Random) void {
        var i: usize = self.cards.len - 1;
        while (i > 0) : (i -= 1) {
            const j = random.intRangeLessThan(usize, 0, i + 1);
            std.mem.swap(card.Card, &self.cards[i], &self.cards[j]);
        }
    }
};

test "Deck initialization" {
    const deck = Deck.init();
    try std.testing.expectEqual(@as(usize, 52), deck.cards.len);

    // Verify first card (hearts, two)
    try std.testing.expectEqual(card.Suit.hearts, deck.cards[0].suit);
    try std.testing.expectEqual(card.Rank.two, deck.cards[0].rank);

    // Verify last card (spades, ace)
    try std.testing.expectEqual(card.Suit.spades, deck.cards[51].suit);
    try std.testing.expectEqual(card.Rank.ace, deck.cards[51].rank);
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

    for (deck.cards) |c| {
        switch (c.suit) {
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

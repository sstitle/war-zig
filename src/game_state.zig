const std = @import("std");
const card_module = @import("card.zig");
const Card = card_module.Card;
const Rank = card_module.Rank;
const Suit = card_module.Suit;

pub const Player = enum {
    player1,
    player2,

    pub fn other(self: Player) Player {
        return switch (self) {
            .player1 => .player2,
            .player2 => .player1,
        };
    }
};

pub const GamePhase = enum {
    not_started,
    playing,
    war,
    game_over,
};

/// War game state using arena-based card storage.
/// Cards are stored in a fixed array and players have slices pointing into it.
/// This avoids copying cards - we only manipulate slice boundaries.
pub const GameState = struct {
    /// All 52 cards stored in a single arena. Cards never move in memory.
    /// The array is partitioned into regions for each player and the war pile.
    cards: [52]Card,

    /// Player 1's hand (slice into cards array)
    p1_start: u8,
    p1_end: u8,

    /// Player 2's hand (slice into cards array)
    p2_start: u8,
    p2_end: u8,

    /// War pile (cards currently in play)
    war_start: u8,
    war_end: u8,

    /// Current game phase
    phase: GamePhase,

    /// Round counter for statistics
    round: u32,

    pub fn init(shuffled_deck: [52]Card) GameState {
        return GameState{
            .cards = shuffled_deck,
            .p1_start = 0,
            .p1_end = 26,
            .p2_start = 26,
            .p2_end = 52,
            .war_start = 0,
            .war_end = 0,
            .phase = .playing,
            .round = 0,
        };
    }

    /// Get player 1's hand as a slice
    pub fn p1Hand(self: *const GameState) []const Card {
        return self.cards[self.p1_start..self.p1_end];
    }

    /// Get player 2's hand as a slice
    pub fn p2Hand(self: *const GameState) []const Card {
        return self.cards[self.p2_start..self.p2_end];
    }

    /// Get war pile as a slice
    pub fn warPile(self: *const GameState) []const Card {
        return self.cards[self.war_start..self.war_end];
    }

    /// Get a player's hand size
    pub fn handSize(self: *const GameState, player: Player) u8 {
        return switch (player) {
            .player1 => self.p1_end - self.p1_start,
            .player2 => self.p2_end - self.p2_start,
        };
    }

    /// Check if a player has enough cards for an action
    pub fn hasCards(self: *const GameState, player: Player, count: u8) bool {
        return self.handSize(player) >= count;
    }

    /// Check if the game is over
    pub fn isGameOver(self: *const GameState) bool {
        return self.handSize(.player1) == 0 or self.handSize(.player2) == 0;
    }

    /// Get the winner (only valid if game is over)
    pub fn winner(self: *const GameState) ?Player {
        if (!self.isGameOver()) return null;
        return if (self.handSize(.player1) > 0) .player1 else .player2;
    }
};

test "GameState initialization" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    const state = GameState.init(deck.cards);

    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.warPile().len);
    try std.testing.expectEqual(GamePhase.playing, state.phase);
    try std.testing.expect(!state.isGameOver());
}

test "GameState hand slices" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    const state = GameState.init(deck.cards);

    const p1 = state.p1Hand();
    const p2 = state.p2Hand();

    try std.testing.expectEqual(@as(usize, 26), p1.len);
    try std.testing.expectEqual(@as(usize, 26), p2.len);

    // First card of p1 should be first card of deck
    try std.testing.expectEqual(deck.cards[0].suit, p1[0].suit);
    try std.testing.expectEqual(deck.cards[0].rank, p1[0].rank);

    // First card of p2 should be 27th card of deck
    try std.testing.expectEqual(deck.cards[26].suit, p2[0].suit);
    try std.testing.expectEqual(deck.cards[26].rank, p2[0].rank);
}

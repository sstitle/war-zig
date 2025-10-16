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

/// War game state using ArrayLists for dynamic card management.
/// Cards can be efficiently moved between hands and the war pile.
pub const GameState = struct {
    allocator: std.mem.Allocator,

    /// Player 1's hand
    p1_hand: std.ArrayList(Card),

    /// Player 2's hand
    p2_hand: std.ArrayList(Card),

    /// Cards currently in play (war pile)
    war_pile: std.ArrayList(Card),

    /// Current game phase
    phase: GamePhase,

    /// Round counter for statistics
    round: u32,

    pub fn init(allocator: std.mem.Allocator, shuffled_deck: [52]Card) !GameState {
        var p1_hand: std.ArrayList(Card) = .{};
        var p2_hand: std.ArrayList(Card) = .{};
        const war_pile: std.ArrayList(Card) = .{};

        // Deal cards: P1 gets first 26, P2 gets last 26
        try p1_hand.appendSlice(allocator, shuffled_deck[0..26]);
        try p2_hand.appendSlice(allocator, shuffled_deck[26..52]);

        return GameState{
            .allocator = allocator,
            .p1_hand = p1_hand,
            .p2_hand = p2_hand,
            .war_pile = war_pile,
            .phase = .playing,
            .round = 0,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.p1_hand.deinit(self.allocator);
        self.p2_hand.deinit(self.allocator);
        self.war_pile.deinit(self.allocator);
    }

    /// Get a player's hand size
    pub fn handSize(self: *const GameState, player: Player) usize {
        return switch (player) {
            .player1 => self.p1_hand.items.len,
            .player2 => self.p2_hand.items.len,
        };
    }

    /// Get mutable reference to a player's hand
    pub fn getHand(self: *GameState, player: Player) *std.ArrayList(Card) {
        return switch (player) {
            .player1 => &self.p1_hand,
            .player2 => &self.p2_hand,
        };
    }

    /// Check if a player has enough cards for an action
    pub fn hasCards(self: *const GameState, player: Player, count: usize) bool {
        return self.handSize(player) >= count;
    }

    /// Check if the game is over
    pub fn isGameOver(self: *const GameState) bool {
        return self.p1_hand.items.len == 0 or self.p2_hand.items.len == 0;
    }

    /// Get the winner (only valid if game is over)
    pub fn winner(self: *const GameState) ?Player {
        if (!self.isGameOver()) return null;
        return if (self.p1_hand.items.len > 0) .player1 else .player2;
    }
};

test "GameState initialization" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    var state = try GameState.init(std.testing.allocator, deck.cards);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.war_pile.items.len);
    try std.testing.expectEqual(GamePhase.playing, state.phase);
    try std.testing.expect(!state.isGameOver());
}

test "GameState hand contents" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    var state = try GameState.init(std.testing.allocator, deck.cards);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 26), state.p1_hand.items.len);
    try std.testing.expectEqual(@as(usize, 26), state.p2_hand.items.len);

    // First card of p1 should be first card of deck
    try std.testing.expectEqual(deck.cards[0].suit, state.p1_hand.items[0].suit);
    try std.testing.expectEqual(deck.cards[0].rank, state.p1_hand.items[0].rank);

    // First card of p2 should be 27th card of deck
    try std.testing.expectEqual(deck.cards[26].suit, state.p2_hand.items[0].suit);
    try std.testing.expectEqual(deck.cards[26].rank, state.p2_hand.items[0].rank);
}

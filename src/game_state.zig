const std = @import("std");
const card_module = @import("card.zig");
const Card = card_module.Card;
const Rank = card_module.Rank;
const Suit = card_module.Suit;
const CardQueue = @import("card_queue.zig").CardQueue;

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

/// Fixed-size war pile for zero-allocation card storage during rounds.
/// Maximum size is 52 (entire deck) but typical wars use 6-12 cards.
pub const FixedWarPile = struct {
    buffer: [52]Card = undefined,
    len: usize = 0,

    pub fn append(self: *FixedWarPile, card: Card) !void {
        if (self.len >= 52) return error.WarPileFull;
        self.buffer[self.len] = card;
        self.len += 1;
    }

    pub fn items(self: *const FixedWarPile) []const Card {
        return self.buffer[0..self.len];
    }

    pub fn pop(self: *FixedWarPile) Card {
        self.len -= 1;
        return self.buffer[self.len];
    }

    pub fn clearRetainingCapacity(self: *FixedWarPile) void {
        self.len = 0;
    }

    pub fn appendSlice(self: *FixedWarPile, cards: []const Card) !void {
        if (self.len + cards.len > 52) return error.WarPileFull;
        @memcpy(self.buffer[self.len..][0..cards.len], cards);
        self.len += cards.len;
    }
};

/// War game state using CardQueues for O(1) card operations.
/// CardQueues provide efficient O(1) removal from front and addition to back.
pub const GameState = struct {
    /// Player 1's hand (ring buffer for O(1) operations)
    p1_hand: CardQueue,

    /// Player 2's hand (ring buffer for O(1) operations)
    p2_hand: CardQueue,

    /// Current game phase
    phase: GamePhase,

    /// Round counter for statistics
    round: u32,

    /// Cards currently in play (war pile) - fixed buffer for zero allocations
    war_pile: FixedWarPile,

    /// Allocator (kept for compatibility, rarely used now)
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, shuffled_deck: [52]Card) !GameState {
        var p1_hand = CardQueue.init();
        var p2_hand = CardQueue.init();
        const war_pile = FixedWarPile{};

        // Deal cards: P1 gets first 26, P2 gets last 26
        try p1_hand.pushBackSlice(shuffled_deck[0..26]);
        try p2_hand.pushBackSlice(shuffled_deck[26..52]);

        return GameState{
            .p1_hand = p1_hand,
            .p2_hand = p2_hand,
            .phase = .playing,
            .round = 0,
            .war_pile = war_pile,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GameState) void {
        // All fields are now fixed-size buffers, no deallocation needed
        _ = self;
    }

    /// Get a player's hand size
    pub fn handSize(self: *const GameState, player: Player) usize {
        return switch (player) {
            .player1 => self.p1_hand.size(),
            .player2 => self.p2_hand.size(),
        };
    }

    /// Get mutable reference to a player's hand
    pub fn getHand(self: *GameState, player: Player) *CardQueue {
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
        return self.p1_hand.isEmpty() or self.p2_hand.isEmpty();
    }

    /// Get the winner (only valid if game is over)
    pub fn winner(self: *const GameState) ?Player {
        if (!self.isGameOver()) return null;
        return if (self.p1_hand.size() > 0) .player1 else .player2;
    }
};

test "GameState initialization" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    var state = try GameState.init(std.testing.allocator, deck.cards);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.war_pile.len);
    try std.testing.expectEqual(GamePhase.playing, state.phase);
    try std.testing.expect(!state.isGameOver());
}

test "GameState hand contents" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();

    var state = try GameState.init(std.testing.allocator, deck.cards);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 26), state.p1_hand.size());
    try std.testing.expectEqual(@as(usize, 26), state.p2_hand.size());

    // First card of p1 should be first card of deck
    const p1_first = try state.p1_hand.getAt(0);
    try std.testing.expectEqual(deck.cards[0].suit, p1_first.suit);
    try std.testing.expectEqual(deck.cards[0].rank, p1_first.rank);

    // First card of p2 should be 27th card of deck
    const p2_first = try state.p2_hand.getAt(0);
    try std.testing.expectEqual(deck.cards[26].suit, p2_first.suit);
    try std.testing.expectEqual(deck.cards[26].rank, p2_first.rank);
}

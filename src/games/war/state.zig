const std = @import("std");
const Card = @import("../../cards/card.zig").Card;
const CardQueue = @import("../../cards/structures/card_queue.zig").CardQueue;
const WarPile = @import("../../cards/structures/war_pile.zig").WarPile;
const ActionHistory = @import("../../data_structures/action_history.zig").ActionHistory;
const GameCommand = @import("commands.zig").GameCommand;
const Config = @import("config.zig").Config;
const GameError = @import("errors.zig").GameError;

pub const Player = enum {
    player1,
    player2,

    /// Returns the opposite player.
    /// Uses explicit switch for clarity; compiler optimizes to xor operation.
    pub inline fn other(self: Player) Player {
        return switch (self) {
            .player1 => .player2,
            .player2 => .player1,
        };
    }

    /// Returns short display name (e.g., "P1", "P2")
    pub inline fn shortName(self: Player) []const u8 {
        return switch (self) {
            .player1 => "P1",
            .player2 => "P2",
        };
    }

    /// Returns full display name (e.g., "Player 1", "Player 2")
    pub inline fn longName(self: Player) []const u8 {
        return switch (self) {
            .player1 => "Player 1",
            .player2 => "Player 2",
        };
    }
};

pub const GamePhase = enum {
    not_started,
    playing,
    war,
    game_over,
};

/// War game state using CardQueues for O(1) card operations.
/// CardQueues provide efficient O(1) removal from front and addition to back.
/// This struct uses only fixed-size buffers for zero-allocation gameplay.
pub const GameState = struct {
    /// Player 1's hand (ring buffer for O(1) operations)
    p1_hand: CardQueue,

    /// Player 2's hand (ring buffer for O(1) operations)
    p2_hand: CardQueue,

    /// Current game phase
    phase: GamePhase,

    /// Round counter for statistics.
    /// Note: Incremented only when a round is resolved, not during war setup.
    /// A "war" scenario still counts as part of the same round until resolution.
    round: u32,

    /// Cards currently in play (war pile) - fixed buffer for zero allocations
    war_pile: WarPile,

    /// Command history for undo/redo support
    history: ActionHistory(GameCommand, Config.max_history),

    pub fn init(shuffled_deck: [Config.deck_size]Card) GameError!GameState {
        var p1_hand = CardQueue.init();
        var p2_hand = CardQueue.init();
        const war_pile = WarPile.init();
        const history = ActionHistory(GameCommand, Config.max_history).init();

        // Deal cards: P1 gets first half, P2 gets second half
        try p1_hand.pushBackSlice(shuffled_deck[0..Config.cards_per_player]);
        try p2_hand.pushBackSlice(shuffled_deck[Config.cards_per_player..Config.deck_size]);

        return GameState{
            .p1_hand = p1_hand,
            .p2_hand = p2_hand,
            .phase = .playing,
            .round = 0,
            .war_pile = war_pile,
            .history = history,
        };
    }

    /// Get a player's hand size
    pub inline fn handSize(self: *const GameState, player: Player) usize {
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
    pub inline fn isGameOver(self: *const GameState) bool {
        return self.p1_hand.isEmpty() or self.p2_hand.isEmpty();
    }

    /// Get the winner (only valid if game is over)
    pub fn winner(self: *const GameState) ?Player {
        if (!self.isGameOver()) return null;
        return if (self.p1_hand.size() > 0) .player1 else .player2;
    }
};

test "GameState initialization" {
    const deck_lib = @import("../../cards/deck.zig");
    const deck = deck_lib.Deck.init();

    var state = try GameState.init(deck.cards);

    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.war_pile.len);
    try std.testing.expectEqual(GamePhase.playing, state.phase);
    try std.testing.expect(!state.isGameOver());
}

test "GameState hand contents" {
    const deck_lib = @import("../../cards/deck.zig");
    const deck = deck_lib.Deck.init();

    var state = try GameState.init(deck.cards);

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

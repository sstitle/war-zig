const std = @import("std");
const game_state = @import("state.zig");
const GameState = game_state.GameState;
const Player = game_state.Player;
const GamePhase = game_state.GamePhase;
const Card = @import("../../cards/card.zig").Card;

/// Tagged union of all game commands for efficient dispatch.
/// Uses compile-time switch dispatch instead of virtual function pointers.
pub const GameCommand = union(enum) {
    play_cards: PlayCardsCommand,
    resolve_round: ResolveRoundCommand,
    war: WarCommand,

    pub fn do(self: *GameCommand, state: *GameState) !void {
        return switch (self.*) {
            inline else => |*cmd| cmd.do(state),
        };
    }

    pub fn undo(self: *GameCommand, state: *GameState) !void {
        return switch (self.*) {
            inline else => |*cmd| cmd.undo(state),
        };
    }

    pub fn redo(self: *GameCommand, state: *GameState) !void {
        return switch (self.*) {
            inline else => |*cmd| cmd.redo(state),
        };
    }
};

/// PlayCardsCommand - Both players play one card from the top of their deck
pub const PlayCardsCommand = struct {
    // Captured cards for undo
    p1_card: Card = undefined,
    p2_card: Card = undefined,

    pub fn do(self: *PlayCardsCommand, state: *GameState) !void {
        if (state.p1_hand.isEmpty() or state.p2_hand.isEmpty()) {
            return error.InsufficientCards;
        }

        // Remove cards from front of each hand (O(1) operation with CardQueue)
        self.p1_card = try state.p1_hand.popFront();
        self.p2_card = try state.p2_hand.popFront();

        try self.applyToWarPile(state);
    }

    pub fn undo(self: *PlayCardsCommand, state: *GameState) !void {
        // Remove from war pile (last two cards)
        _ = state.war_pile.pop();
        _ = state.war_pile.pop();

        // Return to front of hands (O(1) operation with CardQueue)
        try state.p1_hand.pushFront(self.p1_card);
        try state.p2_hand.pushFront(self.p2_card);
    }

    pub fn redo(self: *PlayCardsCommand, state: *GameState) !void {
        // Cards already captured, just remove from hands and apply to war pile
        _ = try state.p1_hand.popFront();
        _ = try state.p2_hand.popFront();
        try self.applyToWarPile(state);
    }

    /// Shared logic for adding captured cards to war pile
    inline fn applyToWarPile(self: *const PlayCardsCommand, state: *GameState) !void {
        try state.war_pile.append(self.p1_card);
        try state.war_pile.append(self.p2_card);
    }
};

/// ResolveRoundCommand - Compare cards in war pile and award to winner
///
/// Note on memory copies: This command copies the war pile for undo/redo support.
/// While this adds some overhead (~52 cards × 16 bytes = 832 bytes max), it's
/// necessary for the command pattern. If undo/redo is not needed in your use case,
/// this snapshot could be eliminated to improve performance.
pub const ResolveRoundCommand = struct {
    winner: Player = undefined,
    war_pile_snapshot: [52]Card = undefined,
    war_pile_len: usize = 0,
    prev_phase: GamePhase = undefined,
    prev_round: u32 = undefined,
    was_war: bool = false,

    pub fn do(self: *ResolveRoundCommand, state: *GameState) !void {
        if (state.war_pile.len < 2) {
            return error.InsufficientCardsInWarPile;
        }

        // Capture state for undo
        self.prev_phase = state.phase;
        self.prev_round = state.round;
        self.war_pile_len = state.war_pile.len;
        // Copy war pile to enable undo (tradeoff: memory copy for undo capability)
        @memcpy(self.war_pile_snapshot[0..self.war_pile_len], state.war_pile.items());

        // Get the last two cards played (P1's card is second-to-last, P2's is last)
        const pile_items = state.war_pile.items();
        const p1_card = pile_items[pile_items.len - 2];
        const p2_card = pile_items[pile_items.len - 1];

        // Determine winner by comparing rank values
        const p1_value = p1_card.rank.value();
        const p2_value = p2_card.rank.value();

        if (p1_value > p2_value) {
            self.winner = .player1;
            self.was_war = false;
        } else if (p1_value < p2_value) {
            self.winner = .player2;
            self.was_war = false;
        } else {
            // War! Cards are equal
            self.was_war = true;
            state.phase = .war;
            state.round += 1;
            return;
        }

        try self.applyWinner(state);
    }

    pub fn undo(self: *ResolveRoundCommand, state: *GameState) !void {
        // If this was a war, just restore state
        if (self.was_war) {
            state.phase = self.prev_phase;
            state.round = self.prev_round;
            return;
        }

        // Remove cards from winner's hand (O(1) operation with CardQueue)
        const winner_hand = state.getHand(self.winner);
        try winner_hand.removeFromBack(self.war_pile_len);

        // Restore war pile from snapshot
        state.war_pile.clearRetainingCapacity();
        try state.war_pile.appendSlice(self.war_pile_snapshot[0..self.war_pile_len]);

        state.phase = self.prev_phase;
        state.round = self.prev_round;
    }

    pub fn redo(self: *ResolveRoundCommand, state: *GameState) !void {
        // If this was a war, just update state
        if (self.was_war) {
            state.phase = .war;
            state.round = self.prev_round + 1;
            return;
        }

        try self.applyWinner(state);
    }

    /// Shared logic for awarding cards to winner
    inline fn applyWinner(self: *const ResolveRoundCommand, state: *GameState) !void {
        // Award cards to winner from snapshot (O(n) but unavoidable)
        const winner_hand = state.getHand(self.winner);
        try winner_hand.pushBackSlice(self.war_pile_snapshot[0..self.war_pile_len]);

        state.war_pile.clearRetainingCapacity();

        if (state.isGameOver()) {
            state.phase = .game_over;
        }

        state.round = self.prev_round + 1;
    }
};

/// WarCommand - Handle the "war" scenario when cards are equal
/// Each player puts down cards (traditionally 3 face-down + 1 face-up)
pub const WarCommand = struct {
    cards_per_player: usize = 4,

    // Captured cards for undo (fixed buffers, max 4 cards each)
    p1_cards: [4]Card = undefined,
    p2_cards: [4]Card = undefined,
    p1_count: usize = 0,
    p2_count: usize = 0,
    prev_phase: GamePhase = undefined,

    pub fn do(self: *WarCommand, state: *GameState) !void {
        self.prev_phase = state.phase;

        // Determine how many cards each player can contribute
        self.p1_count = @min(self.cards_per_player, state.p1_hand.size());
        self.p2_count = @min(self.cards_per_player, state.p2_hand.size());

        if (self.p1_count == 0 or self.p2_count == 0) {
            // Player ran out of cards during war - they lose
            state.phase = .game_over;
            return;
        }

        // Remove cards from each player and add to war pile
        try self.captureAndRemoveCards(state);
        try self.applyToWarPile(state);

        // Return to playing phase to resolve the war
        state.phase = .playing;
    }

    pub fn undo(self: *WarCommand, state: *GameState) !void {
        // Remove cards from war pile (p1 and p2 cards in one optimized loop)
        const total_to_pop = self.p1_count + self.p2_count;
        var i = total_to_pop;
        while (i > 0) : (i -= 1) {
            _ = state.war_pile.pop();
        }

        // Return cards to front of hands (O(1) per card with CardQueue, in reverse order)
        i = self.p2_count;
        while (i > 0) {
            i -= 1;
            try state.p2_hand.pushFront(self.p2_cards[i]);
        }

        i = self.p1_count;
        while (i > 0) {
            i -= 1;
            try state.p1_hand.pushFront(self.p1_cards[i]);
        }

        state.phase = self.prev_phase;
    }

    pub fn redo(self: *WarCommand, state: *GameState) !void {
        // Remove from hands (cards already captured)
        var i: usize = 0;
        while (i < self.p1_count) : (i += 1) {
            _ = try state.p1_hand.popFront();
        }
        i = 0;
        while (i < self.p2_count) : (i += 1) {
            _ = try state.p2_hand.popFront();
        }

        try self.applyToWarPile(state);

        if (state.p1_hand.isEmpty() or state.p2_hand.isEmpty()) {
            state.phase = .game_over;
        } else {
            state.phase = .playing;
        }
    }

    /// Capture cards from hands during initial do()
    inline fn captureAndRemoveCards(self: *WarCommand, state: *GameState) !void {
        var i: usize = 0;
        while (i < self.p1_count) : (i += 1) {
            self.p1_cards[i] = try state.p1_hand.popFront();
        }
        i = 0;
        while (i < self.p2_count) : (i += 1) {
            self.p2_cards[i] = try state.p2_hand.popFront();
        }
    }

    /// Shared logic for adding captured cards to war pile
    inline fn applyToWarPile(self: *const WarCommand, state: *GameState) !void {
        try state.war_pile.appendSlice(self.p1_cards[0..self.p1_count]);
        try state.war_pile.appendSlice(self.p2_cards[0..self.p2_count]);
    }
};

test "PlayCardsCommand basic usage" {
    const deck_lib = @import("../../cards/deck.zig");
    const deck = deck_lib.Deck.init();
    var state = try GameState.init(deck.cards);
    defer state.deinit();

    var cmd = PlayCardsCommand{};

    // Initial state
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));

    // Do: play cards
    try cmd.do(&state);
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 2), state.war_pile.len);

    // Undo
    try cmd.undo(&state);
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.war_pile.len);

    // Redo
    try cmd.redo(&state);
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 2), state.war_pile.len);
}

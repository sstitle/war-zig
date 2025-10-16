const std = @import("std");
const game_state = @import("../state.zig");
const GameState = game_state.GameState;
const GamePhase = game_state.GamePhase;
const Card = @import("../../../cards/card.zig").Card;

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
        // Remove cards from war pile using bulk operation
        const total_to_pop = self.p1_count + self.p2_count;
        try state.war_pile.popMultiple(total_to_pop);

        // Return cards to front of hands (O(1) per card with CardQueue, in reverse order)
        var i = self.p2_count;
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

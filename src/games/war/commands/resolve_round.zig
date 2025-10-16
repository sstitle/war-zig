const std = @import("std");
const game_state = @import("../state.zig");
const GameState = game_state.GameState;
const Player = game_state.Player;
const GamePhase = game_state.GamePhase;
const Card = @import("../../../cards/card.zig").Card;

/// ResolveRoundCommand - Compare cards in war pile and award to winner
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

        // Copy war pile to enable undo
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

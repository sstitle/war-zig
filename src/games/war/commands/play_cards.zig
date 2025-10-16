const std = @import("std");
const game_state = @import("../state.zig");
const GameState = game_state.GameState;
const Card = @import("../../../cards/card.zig").Card;
const Config = @import("../config.zig").Config;
const GameError = @import("../errors.zig").GameError;

/// PlayCardsCommand - Both players play one card from the top of their deck
pub const PlayCardsCommand = struct {
    // Captured cards for undo
    p1_card: Card = undefined,
    p2_card: Card = undefined,

    pub fn do(self: *PlayCardsCommand, state: *GameState) GameError!void {
        if (state.p1_hand.isEmpty() or state.p2_hand.isEmpty()) {
            return GameError.InsufficientCards;
        }

        // Remove cards from front of each hand (O(1) operation with CardQueue)
        self.p1_card = try state.p1_hand.popFront();
        self.p2_card = try state.p2_hand.popFront();

        try self.applyToWarPile(state);
    }

    pub fn undo(self: *PlayCardsCommand, state: *GameState) GameError!void {
        // Remove from war pile (last cards played) - single operation
        try state.war_pile.popMultiple(Config.cards_per_regular_round);

        // Return to front of hands (O(1) operation with CardQueue)
        try state.p1_hand.pushFront(self.p1_card);
        try state.p2_hand.pushFront(self.p2_card);
    }

    pub fn redo(self: *PlayCardsCommand, state: *GameState) GameError!void {
        // Cards already captured, just remove from hands and apply to war pile
        _ = try state.p1_hand.popFront();
        _ = try state.p2_hand.popFront();
        try self.applyToWarPile(state);
    }

    /// Shared logic for adding captured cards to war pile
    inline fn applyToWarPile(self: *const PlayCardsCommand, state: *GameState) GameError!void {
        try state.war_pile.append(self.p1_card);
        try state.war_pile.append(self.p2_card);
    }
};

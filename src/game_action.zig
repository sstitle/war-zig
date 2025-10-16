const std = @import("std");
const game_state = @import("game_state.zig");
const GameState = game_state.GameState;
const Player = game_state.Player;
const GamePhase = game_state.GamePhase;
const Card = @import("card.zig").Card;

/// PlayCardsCommand - Both players play one card from the top of their deck
/// This is the most common action in War
pub const PlayCardsCommand = struct {
    // Captured state for undo
    prev_p1_start: u8 = undefined,
    prev_p2_start: u8 = undefined,
    prev_war_end: u8 = undefined,
    prev_phase: GamePhase = undefined,

    pub fn do(self: *PlayCardsCommand, state: *GameState) !void {
        if (state.handSize(.player1) == 0 or state.handSize(.player2) == 0) {
            return error.InsufficientCards;
        }

        // Capture current state for undo
        self.prev_p1_start = state.p1_start;
        self.prev_p2_start = state.p2_start;
        self.prev_war_end = state.war_end;
        self.prev_phase = state.phase;

        // Move cards from player hands to war pile
        // In our arena model, we just adjust indices
        state.p1_start += 1;
        state.p2_start += 1;
        state.war_end += 2;
    }

    pub fn undo(self: *PlayCardsCommand, state: *GameState) !void {
        state.p1_start = self.prev_p1_start;
        state.p2_start = self.prev_p2_start;
        state.war_end = self.prev_war_end;
        state.phase = self.prev_phase;
    }

    pub fn redo(self: *PlayCardsCommand, state: *GameState) !void {
        // Redo is just reapplying the same changes
        state.p1_start = self.prev_p1_start + 1;
        state.p2_start = self.prev_p2_start + 1;
        state.war_end = self.prev_war_end + 2;
    }
};

/// ResolveRoundCommand - Compare cards in war pile and award to winner
pub const ResolveRoundCommand = struct {
    winner: Player = undefined,

    // Captured state for undo
    prev_p1_end: u8 = undefined,
    prev_p2_end: u8 = undefined,
    prev_war_start: u8 = undefined,
    prev_war_end: u8 = undefined,
    prev_phase: GamePhase = undefined,
    prev_round: u32 = undefined,

    pub fn do(self: *ResolveRoundCommand, state: *GameState) !void {
        if (state.war_end - state.war_start < 2) {
            return error.InsufficientCardsInWarPile;
        }

        // Capture state
        self.prev_p1_end = state.p1_end;
        self.prev_p2_end = state.p2_end;
        self.prev_war_start = state.war_start;
        self.prev_war_end = state.war_end;
        self.prev_phase = state.phase;
        self.prev_round = state.round;

        // Get the last two cards played
        const p1_card = state.cards[state.war_end - 2];
        const p2_card = state.cards[state.war_end - 1];

        // Determine winner
        if (p1_card.rank.value() > p2_card.rank.value()) {
            self.winner = .player1;
        } else if (p2_card.rank.value() > p1_card.rank.value()) {
            self.winner = .player2;
        } else {
            // War! Cards are equal
            state.phase = .war;
            state.round += 1;
            return;
        }

        // Award all cards in war pile to winner
        const war_pile_size = state.war_end - state.war_start;
        switch (self.winner) {
            .player1 => state.p1_end += war_pile_size,
            .player2 => state.p2_end += war_pile_size,
        }

        // Clear war pile
        state.war_start = state.war_end;

        // Check for game over
        if (state.isGameOver()) {
            state.phase = .game_over;
        }

        state.round += 1;
    }

    pub fn undo(self: *ResolveRoundCommand, state: *GameState) !void {
        state.p1_end = self.prev_p1_end;
        state.p2_end = self.prev_p2_end;
        state.war_start = self.prev_war_start;
        state.war_end = self.prev_war_end;
        state.phase = self.prev_phase;
        state.round = self.prev_round;
    }

    pub fn redo(self: *ResolveRoundCommand, state: *GameState) !void {
        // Apply the same changes
        const war_pile_size = self.prev_war_end - self.prev_war_start;

        switch (self.winner) {
            .player1 => state.p1_end = self.prev_p1_end + war_pile_size,
            .player2 => state.p2_end = self.prev_p2_end + war_pile_size,
        }

        state.war_start = self.prev_war_end;
        state.war_end = self.prev_war_end;
        state.round = self.prev_round + 1;

        if (state.isGameOver()) {
            state.phase = .game_over;
        }
    }
};

/// WarCommand - Handle the "war" scenario when cards are equal
/// Each player puts down 3 face-down cards and 1 face-up card
pub const WarCommand = struct {
    cards_per_player: u8 = 4, // 3 face-down + 1 face-up

    // Captured state for undo
    prev_p1_start: u8 = undefined,
    prev_p2_start: u8 = undefined,
    prev_war_end: u8 = undefined,
    prev_phase: GamePhase = undefined,

    pub fn do(self: *WarCommand, state: *GameState) !void {
        // Check if players have enough cards
        const p1_cards = @min(self.cards_per_player, state.handSize(.player1));
        const p2_cards = @min(self.cards_per_player, state.handSize(.player2));

        if (p1_cards == 0 or p2_cards == 0) {
            // Player ran out of cards during war - they lose
            state.phase = .game_over;
            return error.InsufficientCardsForWar;
        }

        // Capture state
        self.prev_p1_start = state.p1_start;
        self.prev_p2_start = state.p2_start;
        self.prev_war_end = state.war_end;
        self.prev_phase = state.phase;

        // Add cards to war pile
        state.p1_start += p1_cards;
        state.p2_start += p2_cards;
        state.war_end += p1_cards + p2_cards;

        // Return to playing phase to resolve
        state.phase = .playing;
    }

    pub fn undo(self: *WarCommand, state: *GameState) !void {
        state.p1_start = self.prev_p1_start;
        state.p2_start = self.prev_p2_start;
        state.war_end = self.prev_war_end;
        state.phase = self.prev_phase;
    }

    pub fn redo(self: *WarCommand, state: *GameState) !void {
        const p1_cards = @min(self.cards_per_player, self.prev_p1_start - state.p1_start);
        const p2_cards = @min(self.cards_per_player, self.prev_p2_start - state.p2_start);

        state.p1_start = self.prev_p1_start + p1_cards;
        state.p2_start = self.prev_p2_start + p2_cards;
        state.war_end = self.prev_war_end + p1_cards + p2_cards;
        state.phase = .playing;
    }
};

test "PlayCardsCommand basic usage" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();
    var state = GameState.init(deck.cards);

    var cmd = PlayCardsCommand{};

    // Initial state
    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player2));

    // Do: play cards
    try cmd.do(&state);
    try std.testing.expectEqual(@as(u8, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(u8, 25), state.handSize(.player2));

    // Undo
    try cmd.undo(&state);
    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(u8, 26), state.handSize(.player2));

    // Redo
    try cmd.redo(&state);
    try std.testing.expectEqual(@as(u8, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(u8, 25), state.handSize(.player2));
}

const std = @import("std");
const game_state = @import("game_state.zig");
const GameState = game_state.GameState;
const Player = game_state.Player;
const GamePhase = game_state.GamePhase;
const Card = @import("card.zig").Card;

/// PlayCardsCommand - Both players play one card from the top of their deck
pub const PlayCardsCommand = struct {
    // Captured cards for undo
    p1_card: Card = undefined,
    p2_card: Card = undefined,

    pub fn do(self: *PlayCardsCommand, state: *GameState) !void {
        if (state.p1_hand.items.len == 0 or state.p2_hand.items.len == 0) {
            return error.InsufficientCards;
        }

        // Remove cards from front of each hand and add to war pile
        self.p1_card = state.p1_hand.orderedRemove(0);
        self.p2_card = state.p2_hand.orderedRemove(0);

        try state.war_pile.append(state.allocator, self.p1_card);
        try state.war_pile.append(state.allocator, self.p2_card);
    }

    pub fn undo(self: *PlayCardsCommand, state: *GameState) !void {
        // Remove from war pile (last two cards)
        _ = state.war_pile.pop();
        _ = state.war_pile.pop();

        // Return to front of hands
        try state.p1_hand.insert(state.allocator, 0, self.p1_card);
        try state.p2_hand.insert(state.allocator, 0, self.p2_card);
    }

    pub fn redo(self: *PlayCardsCommand, state: *GameState) !void {
        // Same as do, but we already have the cards captured
        _ = state.p1_hand.orderedRemove(0);
        _ = state.p2_hand.orderedRemove(0);

        try state.war_pile.append(state.allocator, self.p1_card);
        try state.war_pile.append(state.allocator, self.p2_card);
    }
};

/// ResolveRoundCommand - Compare cards in war pile and award to winner
pub const ResolveRoundCommand = struct {
    winner: Player = undefined,
    war_pile_cards: std.ArrayList(Card) = undefined,
    prev_phase: GamePhase = undefined,
    prev_round: u32 = undefined,

    pub fn do(self: *ResolveRoundCommand, state: *GameState) !void {
        if (state.war_pile.items.len < 2) {
            return error.InsufficientCardsInWarPile;
        }

        // Capture state
        self.prev_phase = state.phase;
        self.prev_round = state.round;
        self.war_pile_cards = try state.war_pile.clone(state.allocator);

        // Get the last two cards played (P1's card is second-to-last, P2's is last)
        const p1_card = state.war_pile.items[state.war_pile.items.len - 2];
        const p2_card = state.war_pile.items[state.war_pile.items.len - 1];

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
        const winner_hand = state.getHand(self.winner);
        try winner_hand.appendSlice(state.allocator, state.war_pile.items);

        // Clear war pile
        state.war_pile.clearRetainingCapacity();

        // Check for game over
        if (state.isGameOver()) {
            state.phase = .game_over;
        }

        state.round += 1;
    }

    pub fn undo(self: *ResolveRoundCommand, state: *GameState) !void {
        // If we went to war, just restore state
        if (self.prev_phase != state.phase and state.phase == .war) {
            state.phase = self.prev_phase;
            state.round = self.prev_round;
            return;
        }

        // Remove cards from winner's hand
        const winner_hand = state.getHand(self.winner);
        const cards_to_remove = self.war_pile_cards.items.len;
        winner_hand.shrinkRetainingCapacity(winner_hand.items.len - cards_to_remove);

        // Restore war pile
        state.war_pile.clearRetainingCapacity();
        try state.war_pile.appendSlice(state.allocator, self.war_pile_cards.items);

        state.phase = self.prev_phase;
        state.round = self.prev_round;
    }

    pub fn redo(self: *ResolveRoundCommand, state: *GameState) !void {
        // Check if this was a war
        if (state.phase == .playing and self.prev_phase == .playing) {
            state.phase = .war;
            state.round = self.prev_round + 1;
            return;
        }

        // Award cards to winner
        const winner_hand = state.getHand(self.winner);
        try winner_hand.appendSlice(state.allocator, self.war_pile_cards.items);

        state.war_pile.clearRetainingCapacity();

        if (state.isGameOver()) {
            state.phase = .game_over;
        }

        state.round = self.prev_round + 1;
    }

    pub fn deinit(self: *ResolveRoundCommand, allocator: std.mem.Allocator) void {
        if (self.war_pile_cards.items.len > 0) {
            self.war_pile_cards.deinit(allocator);
        }
    }
};

/// WarCommand - Handle the "war" scenario when cards are equal
/// Each player puts down cards (traditionally 3 face-down + 1 face-up)
pub const WarCommand = struct {
    cards_per_player: usize = 4,

    // Captured cards for undo
    p1_cards: std.ArrayList(Card) = undefined,
    p2_cards: std.ArrayList(Card) = undefined,
    prev_phase: GamePhase = undefined,

    pub fn do(self: *WarCommand, state: *GameState) !void {
        self.p1_cards = .{};
        self.p2_cards = .{};
        self.prev_phase = state.phase;

        // Determine how many cards each player can contribute
        const p1_count = @min(self.cards_per_player, state.p1_hand.items.len);
        const p2_count = @min(self.cards_per_player, state.p2_hand.items.len);

        if (p1_count == 0 or p2_count == 0) {
            // Player ran out of cards during war - they lose
            state.phase = .game_over;
            return;
        }

        // Remove cards from each player and add to war pile
        var i: usize = 0;
        while (i < p1_count) : (i += 1) {
            const card = state.p1_hand.orderedRemove(0);
            try self.p1_cards.append(state.allocator, card);
            try state.war_pile.append(state.allocator, card);
        }

        i = 0;
        while (i < p2_count) : (i += 1) {
            const card = state.p2_hand.orderedRemove(0);
            try self.p2_cards.append(state.allocator, card);
            try state.war_pile.append(state.allocator, card);
        }

        // Return to playing phase to resolve the war
        state.phase = .playing;
    }

    pub fn undo(self: *WarCommand, state: *GameState) !void {
        // Remove cards from war pile
        var i: usize = 0;
        while (i < self.p2_cards.items.len) : (i += 1) {
            _ = state.war_pile.pop();
        }
        i = 0;
        while (i < self.p1_cards.items.len) : (i += 1) {
            _ = state.war_pile.pop();
        }

        // Return cards to front of hands (in reverse order)
        i = self.p2_cards.items.len;
        while (i > 0) {
            i -= 1;
            try state.p2_hand.insert(state.allocator, 0, self.p2_cards.items[i]);
        }

        i = self.p1_cards.items.len;
        while (i > 0) {
            i -= 1;
            try state.p1_hand.insert(state.allocator, 0, self.p1_cards.items[i]);
        }

        state.phase = self.prev_phase;
    }

    pub fn redo(self: *WarCommand, state: *GameState) !void {
        // Remove from hands and add to war pile
        for (self.p1_cards.items) |_| {
            _ = state.p1_hand.orderedRemove(0);
        }
        for (self.p2_cards.items) |_| {
            _ = state.p2_hand.orderedRemove(0);
        }

        try state.war_pile.appendSlice(state.allocator, self.p1_cards.items);
        try state.war_pile.appendSlice(state.allocator, self.p2_cards.items);

        if (state.p1_hand.items.len == 0 or state.p2_hand.items.len == 0) {
            state.phase = .game_over;
        } else {
            state.phase = .playing;
        }
    }

    pub fn deinit(self: *WarCommand, allocator: std.mem.Allocator) void {
        if (self.p1_cards.items.len > 0) {
            self.p1_cards.deinit(allocator);
        }
        if (self.p2_cards.items.len > 0) {
            self.p2_cards.deinit(allocator);
        }
    }
};

test "PlayCardsCommand basic usage" {
    const deck_module = @import("deck.zig");
    const deck = deck_module.Deck.init();
    var state = try GameState.init(std.testing.allocator, deck.cards);
    defer state.deinit();

    var cmd = PlayCardsCommand{};

    // Initial state
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));

    // Do: play cards
    try cmd.do(&state);
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 2), state.war_pile.items.len);

    // Undo
    try cmd.undo(&state);
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 26), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 0), state.war_pile.items.len);

    // Redo
    try cmd.redo(&state);
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player1));
    try std.testing.expectEqual(@as(usize, 25), state.handSize(.player2));
    try std.testing.expectEqual(@as(usize, 2), state.war_pile.items.len);
}

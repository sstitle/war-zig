const std = @import("std");
const game_state = @import("../state.zig");
const GameState = game_state.GameState;

const PlayCardsCommand = @import("play_cards.zig").PlayCardsCommand;
const ResolveRoundCommand = @import("resolve_round.zig").ResolveRoundCommand;
const WarCommand = @import("war.zig").WarCommand;

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

test "PlayCardsCommand basic usage" {
    const deck_lib = @import("../../../cards/deck.zig");
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

const std = @import("std");
const game_state = @import("../state.zig");
const GameState = game_state.GameState;
const GameError = @import("../errors.zig").GameError;

const PlayCardsCommand = @import("play_cards.zig").PlayCardsCommand;
const ResolveRoundCommand = @import("resolve_round.zig").ResolveRoundCommand;
const WarCommand = @import("war.zig").WarCommand;

/// Tagged union of all game commands for efficient dispatch.
/// Uses compile-time switch dispatch instead of virtual function pointers.
///
/// Command Pattern Invariants:
/// All commands must satisfy these properties for correct undo/redo:
///
/// 1. **Reversibility**: state_after_undo == state_before_do
///    - Executing undo() after do() must restore the exact prior state
///
/// 2. **Idempotence**: do() -> undo() -> redo() produces identical state to do()
///    - The state after redo() must equal the state after the original do()
///
/// 3. **State Capture**: Commands must capture ALL data needed for reversal
///    - Each command stores sufficient information during do() to enable undo()
///    - redo() reuses captured state rather than recomputing
///
/// 4. **Atomicity**: Commands represent indivisible game actions
///    - Each command completes fully or fails (no partial state changes)
///
/// Example command lifecycle:
/// ```zig
/// var cmd = PlayCardsCommand{};
/// try cmd.do(&state);        // state' = do(state)
/// try cmd.undo(&state);      // state  = undo(state')  [reversibility]
/// try cmd.redo(&state);      // state' = redo(state)   [idempotence]
/// ```
pub const GameCommand = union(enum) {
    play_cards: PlayCardsCommand,
    resolve_round: ResolveRoundCommand,
    war: WarCommand,

    pub fn do(self: *GameCommand, state: *GameState) GameError!void {
        return switch (self.*) {
            inline else => |*cmd| cmd.do(state),
        };
    }

    pub fn undo(self: *GameCommand, state: *GameState) GameError!void {
        return switch (self.*) {
            inline else => |*cmd| cmd.undo(state),
        };
    }

    pub fn redo(self: *GameCommand, state: *GameState) GameError!void {
        return switch (self.*) {
            inline else => |*cmd| cmd.redo(state),
        };
    }
};

test "PlayCardsCommand basic usage" {
    const deck_lib = @import("../../../cards/deck.zig");
    const deck = deck_lib.Deck.init();
    var state = try GameState.init(deck.cards);

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

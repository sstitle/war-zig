//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Internal imports
const card_module = @import("card.zig");
const deck_module = @import("deck.zig");

// Re-export common types for convenience
pub const Card = card_module.Card;
pub const Rank = card_module.Rank;
pub const Suit = card_module.Suit;
pub const Deck = deck_module.Deck;

// Re-export game modules
pub const game_state = @import("game_state.zig");
pub const game_action = @import("game_action.zig");
pub const command = @import("command.zig");
pub const action_history = @import("action_history.zig");

// Re-export game types for convenience
pub const GameState = game_state.GameState;
pub const Player = game_state.Player;
pub const GamePhase = game_state.GamePhase;

// Re-export command types
pub const GameCommand = game_action.GameCommand;
pub const PlayCardsCommand = game_action.PlayCardsCommand;
pub const ResolveRoundCommand = game_action.ResolveRoundCommand;
pub const WarCommand = game_action.WarCommand;

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

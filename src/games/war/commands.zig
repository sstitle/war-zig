//! War game commands module.
//!
//! This module provides command pattern implementations for all game actions,
//! supporting undo/redo functionality through captured state snapshots.

pub const GameCommand = @import("commands/game_command.zig").GameCommand;
pub const PlayCardsCommand = @import("commands/play_cards.zig").PlayCardsCommand;
pub const ResolveRoundCommand = @import("commands/resolve_round.zig").ResolveRoundCommand;
pub const WarCommand = @import("commands/war.zig").WarCommand;

// Re-export tests
comptime {
    _ = @import("commands/game_command.zig");
}

//! Configuration constants for the War card game.
//!
//! Centralizes magic numbers and configuration values for easier tuning
//! and better code clarity.

/// War game configuration constants
pub const Config = struct {
    /// Maximum number of commands to keep in history for undo/redo
    pub const max_history: usize = 10_000;

    /// Maximum rounds before declaring game incomplete (prevents infinite loops)
    pub const max_rounds: u32 = 100_000;

    /// Standard deck size
    pub const deck_size: usize = 52;

    /// Cards per player at game start (half the deck)
    pub const cards_per_player: usize = deck_size / 2;
};

//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Internal imports
const card = @import("card.zig");
const deck = @import("deck.zig");

// Re-export common types for convenience
pub const Card = card.Card;
pub const Rank = card.Rank;
pub const Suit = card.Suit;
pub const Deck = deck.Deck;

// Re-export game modules
pub const game_state = @import("game_state.zig");
pub const game_action = @import("game_action.zig");
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

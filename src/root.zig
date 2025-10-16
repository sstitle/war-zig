//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

// Cards - Playing card primitives
pub const Card = @import("cards/card.zig").Card;
pub const Rank = @import("cards/rank.zig").Rank;
pub const Suit = @import("cards/suit.zig").Suit;
pub const Deck = @import("cards/deck.zig").Deck;

// Data structures - Generic, reusable data structures
pub const action_history = @import("data_structures/action_history.zig");
pub const RingBuffer = @import("data_structures/ring_buffer.zig").RingBuffer;
pub const FixedBuffer = @import("data_structures/fixed_buffer.zig").FixedBuffer;

// Convenience type alias for Card queues
pub const CardQueue = @import("data_structures/card_queue.zig").CardQueue;

// War game - Game-specific types
const war_state = @import("games/war/state.zig");
const war_commands = @import("games/war/commands.zig");

// Re-export War game types
pub const GameState = war_state.GameState;
pub const Player = war_state.Player;
pub const GamePhase = war_state.GamePhase;
pub const WarPile = war_state.WarPile;

// Re-export War game commands
pub const GameCommand = war_commands.GameCommand;
pub const PlayCardsCommand = war_commands.PlayCardsCommand;
pub const ResolveRoundCommand = war_commands.ResolveRoundCommand;
pub const WarCommand = war_commands.WarCommand;

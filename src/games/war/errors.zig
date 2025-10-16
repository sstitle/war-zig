//! Error types for War card game commands and operations.
//!
//! Centralizes error definitions to provide explicit error sets
//! for better API documentation and type safety.

/// Errors that can occur during command execution and game operations.
pub const GameError = error{
    /// Insufficient cards in a player's hand to perform the operation
    InsufficientCards,

    /// Insufficient cards in the war pile to resolve
    InsufficientCardsInWarPile,

    /// Buffer is full and cannot accept more items
    BufferFull,

    /// Buffer is empty and cannot provide items
    BufferEmpty,

    /// Attempting to remove more items than available
    InsufficientItems,

    /// Index is out of bounds
    IndexOutOfBounds,

    /// Buffer is too small for the requested operation
    BufferTooSmall,
};

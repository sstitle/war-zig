//! Type alias for WarPile using the generic FixedBuffer.
//!
//! This provides a convenient type for the War game's pile of cards
//! while using the generic FixedBuffer implementation underneath.

const Card = @import("../card.zig").Card;
const FixedBuffer = @import("../../data_structures/fixed_buffer.zig").FixedBuffer;

/// Fixed-size war pile for zero-allocation card storage during rounds.
/// Maximum size is 52 (entire deck) but typical wars use 6-12 cards.
pub const WarPile = FixedBuffer(Card, 52);

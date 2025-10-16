//! Type alias for CardQueue using the generic RingBuffer.
//!
//! This provides a convenient type for working with card queues
//! while using the generic RingBuffer implementation underneath.

const Card = @import("../cards/card.zig").Card;
const RingBuffer = @import("ring_buffer.zig").RingBuffer;

/// A fixed-size circular buffer for exactly 52 cards.
/// This is a type alias for RingBuffer(Card, 52).
pub const CardQueue = RingBuffer(Card, 52);

const std = @import("std");
const Card = @import("card.zig").Card;

/// A fixed-size circular buffer optimized for card game operations.
/// Provides O(1) operations for removing from front and adding to back,
/// which is perfect for War game where cards are drawn from the top
/// and added to the bottom of the deck.
pub const CardQueue = struct {
    buffer: [52]Card,
    head: usize,
    tail: usize,
    count: usize,

    pub fn init() CardQueue {
        return CardQueue{
            .buffer = undefined,
            .head = 0,
            .tail = 0,
            .count = 0,
        };
    }

    /// Remove and return the card at the front of the queue.
    /// Returns error.EmptyQueue if the queue is empty.
    pub fn popFront(self: *CardQueue) !Card {
        if (self.count == 0) {
            return error.EmptyQueue;
        }

        const card = self.buffer[self.head];
        self.head = (self.head + 1) % self.buffer.len;
        self.count -= 1;
        return card;
    }

    /// Add a card to the back of the queue.
    /// Returns error.FullQueue if the queue is at capacity.
    pub fn pushBack(self: *CardQueue, card: Card) !void {
        if (self.count >= self.buffer.len) {
            return error.FullQueue;
        }

        self.buffer[self.tail] = card;
        self.tail = (self.tail + 1) % self.buffer.len;
        self.count += 1;
    }

    /// Add a card to the front of the queue (for undo operations).
    /// Returns error.FullQueue if the queue is at capacity.
    pub fn pushFront(self: *CardQueue, card: Card) !void {
        if (self.count >= self.buffer.len) {
            return error.FullQueue;
        }

        // Move head back by one (wrapping around if necessary)
        self.head = if (self.head == 0) self.buffer.len - 1 else self.head - 1;
        self.buffer[self.head] = card;
        self.count += 1;
    }

    /// View the card at the front without removing it.
    /// Returns error.EmptyQueue if the queue is empty.
    pub fn peekFront(self: *const CardQueue) !Card {
        if (self.count == 0) {
            return error.EmptyQueue;
        }
        return self.buffer[self.head];
    }

    /// Get the number of cards in the queue.
    pub fn size(self: *const CardQueue) usize {
        return self.count;
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const CardQueue) bool {
        return self.count == 0;
    }

    /// Check if the queue is full.
    pub fn isFull(self: *const CardQueue) bool {
        return self.count >= self.buffer.len;
    }

    /// Clear all cards from the queue.
    pub fn clear(self: *CardQueue) void {
        self.head = 0;
        self.tail = 0;
        self.count = 0;
    }

    /// Add multiple cards to the back of the queue.
    /// Optimized with single bounds check instead of checking on each iteration.
    pub fn pushBackSlice(self: *CardQueue, cards: []const Card) !void {
        if (self.count + cards.len > self.buffer.len) {
            return error.FullQueue;
        }

        for (cards) |card| {
            self.buffer[self.tail] = card;
            self.tail = (self.tail + 1) % self.buffer.len;
        }
        self.count += cards.len;
    }

    /// Remove multiple cards from the front of the queue.
    /// Returns a slice into a temporary buffer containing the removed cards.
    pub fn popFrontMultiple(self: *CardQueue, n: usize, out_buffer: []Card) ![]Card {
        if (n > self.count) {
            return error.InsufficientCards;
        }
        if (n > out_buffer.len) {
            return error.BufferTooSmall;
        }

        for (0..n) |i| {
            out_buffer[i] = try self.popFront();
        }

        return out_buffer[0..n];
    }

    /// Get a card at a specific index (0 = front).
    /// This is O(1) but should be used sparingly as it breaks the queue abstraction.
    pub fn getAt(self: *const CardQueue, index: usize) !Card {
        if (index >= self.count) {
            return error.IndexOutOfBounds;
        }

        const actual_index = (self.head + index) % self.buffer.len;
        return self.buffer[actual_index];
    }

    /// Remove N cards from the back of the queue (for undo operations).
    /// Returns error.InsufficientCards if trying to remove more than available.
    pub fn removeFromBack(self: *CardQueue, n: usize) !void {
        if (n > self.count) {
            return error.InsufficientCards;
        }

        // Move tail back by n positions
        if (self.tail >= n) {
            self.tail -= n;
        } else {
            self.tail = self.buffer.len - (n - self.tail);
        }
        self.count -= n;
    }
};

// Tests
const Rank = @import("card.zig").Rank;
const Suit = @import("card.zig").Suit;

test "CardQueue init" {
    const queue = CardQueue.init();
    try std.testing.expectEqual(@as(usize, 0), queue.size());
    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(!queue.isFull());
}

test "CardQueue pushBack and popFront" {
    var queue = CardQueue.init();

    const card1 = Card.init(.hearts, .ace);
    const card2 = Card.init(.diamonds, .king);

    try queue.pushBack(card1);
    try std.testing.expectEqual(@as(usize, 1), queue.size());

    try queue.pushBack(card2);
    try std.testing.expectEqual(@as(usize, 2), queue.size());

    const popped1 = try queue.popFront();
    try std.testing.expectEqual(card1.rank, popped1.rank);
    try std.testing.expectEqual(card1.suit, popped1.suit);
    try std.testing.expectEqual(@as(usize, 1), queue.size());

    const popped2 = try queue.popFront();
    try std.testing.expectEqual(card2.rank, popped2.rank);
    try std.testing.expectEqual(card2.suit, popped2.suit);
    try std.testing.expectEqual(@as(usize, 0), queue.size());
    try std.testing.expect(queue.isEmpty());
}

test "CardQueue wrap-around behavior" {
    var queue = CardQueue.init();

    // Fill buffer to near capacity
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const rank_val = @as(u8, @intCast((i % 13) + 2));
        const rank = @as(Rank, @enumFromInt(rank_val));
        const suit_idx = i % 4;
        const suit = switch (suit_idx) {
            0 => Suit.hearts,
            1 => Suit.diamonds,
            2 => Suit.clubs,
            else => Suit.spades,
        };
        try queue.pushBack(Card.init(suit, rank));
    }
    try std.testing.expectEqual(@as(usize, 50), queue.size());

    // Remove 25 cards
    i = 0;
    while (i < 25) : (i += 1) {
        _ = try queue.popFront();
    }
    try std.testing.expectEqual(@as(usize, 25), queue.size());

    // Add 25 more cards (this will wrap around)
    i = 0;
    while (i < 25) : (i += 1) {
        try queue.pushBack(Card.init(.hearts, .two));
    }
    try std.testing.expectEqual(@as(usize, 50), queue.size());

    // Verify we can still pop all cards
    i = 0;
    while (i < 50) : (i += 1) {
        _ = try queue.popFront();
    }
    try std.testing.expect(queue.isEmpty());
}

test "CardQueue pushFront for undo" {
    var queue = CardQueue.init();

    const card1 = Card.init(.hearts, .ace);
    const card2 = Card.init(.diamonds, .king);

    try queue.pushBack(card1);
    try queue.pushFront(card2);

    try std.testing.expectEqual(@as(usize, 2), queue.size());

    const popped = try queue.popFront();
    try std.testing.expectEqual(card2.rank, popped.rank);
}

test "CardQueue peekFront" {
    var queue = CardQueue.init();

    const card = Card.init(.hearts, .ace);
    try queue.pushBack(card);

    const peeked = try queue.peekFront();
    try std.testing.expectEqual(card.rank, peeked.rank);
    try std.testing.expectEqual(@as(usize, 1), queue.size()); // Size unchanged
}

test "CardQueue pushBackSlice" {
    var queue = CardQueue.init();

    const cards = [_]Card{
        Card.init(.hearts, .ace),
        Card.init(.diamonds, .king),
        Card.init(.clubs, .queen),
    };

    try queue.pushBackSlice(&cards);
    try std.testing.expectEqual(@as(usize, 3), queue.size());

    const popped = try queue.popFront();
    try std.testing.expectEqual(cards[0].rank, popped.rank);
}

test "CardQueue popFrontMultiple" {
    var queue = CardQueue.init();

    const cards = [_]Card{
        Card.init(.hearts, .ace),
        Card.init(.diamonds, .king),
        Card.init(.clubs, .queen),
    };

    try queue.pushBackSlice(&cards);

    var buffer: [10]Card = undefined;
    const removed = try queue.popFrontMultiple(2, &buffer);

    try std.testing.expectEqual(@as(usize, 2), removed.len);
    try std.testing.expectEqual(cards[0].rank, removed[0].rank);
    try std.testing.expectEqual(cards[1].rank, removed[1].rank);
    try std.testing.expectEqual(@as(usize, 1), queue.size());
}

test "CardQueue error conditions" {
    var queue = CardQueue.init();

    // Empty queue errors
    try std.testing.expectError(error.EmptyQueue, queue.popFront());
    try std.testing.expectError(error.EmptyQueue, queue.peekFront());

    // Fill to capacity
    var i: usize = 0;
    while (i < 52) : (i += 1) {
        try queue.pushBack(Card.init(.hearts, .ace));
    }

    // Full queue error
    try std.testing.expectError(error.FullQueue, queue.pushBack(Card.init(.hearts, .king)));
}

test "CardQueue getAt" {
    var queue = CardQueue.init();

    const cards = [_]Card{
        Card.init(.hearts, .ace),
        Card.init(.diamonds, .king),
        Card.init(.clubs, .queen),
    };

    try queue.pushBackSlice(&cards);

    const card_at_1 = try queue.getAt(1);
    try std.testing.expectEqual(cards[1].rank, card_at_1.rank);

    try std.testing.expectError(error.IndexOutOfBounds, queue.getAt(10));
}

test "CardQueue clear" {
    var queue = CardQueue.init();

    try queue.pushBack(Card.init(.hearts, .ace));
    try queue.pushBack(Card.init(.diamonds, .king));

    queue.clear();
    try std.testing.expectEqual(@as(usize, 0), queue.size());
    try std.testing.expect(queue.isEmpty());
}

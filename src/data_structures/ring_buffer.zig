//! Fixed-size circular buffer for efficient queue operations.
//!
//! Provides O(1) operations for adding/removing from both ends,
//! perfect for game state management where items are drawn from one end
//! and added to the other.
//!
//! Example:
//! ```
//! var buffer = RingBuffer(Card, 52).init();
//! try buffer.pushBack(Card.init(.hearts, .ace));
//! const card = try buffer.popFront();
//! ```

const std = @import("std");

/// A fixed-size circular buffer that can store up to `capacity` items of type `T`.
/// Uses a ring buffer to enable O(1) operations at both ends.
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]T,
        head: usize,
        tail: usize,
        count: usize,

        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = 0,
                .tail = 0,
                .count = 0,
            };
        }

        /// Remove and return the item at the front of the buffer.
        /// Returns error.EmptyQueue if the buffer is empty.
        pub fn popFront(self: *Self) !T {
            if (self.count == 0) {
                return error.EmptyQueue;
            }

            const item = self.buffer[self.head];
            self.head = (self.head + 1) % self.buffer.len;
            self.count -= 1;
            return item;
        }

        /// Add an item to the back of the buffer.
        /// Returns error.FullQueue if the buffer is at capacity.
        pub fn pushBack(self: *Self, item: T) !void {
            if (self.count >= self.buffer.len) {
                return error.FullQueue;
            }

            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % self.buffer.len;
            self.count += 1;
        }

        /// Add an item to the front of the buffer (for undo operations).
        /// Returns error.FullQueue if the buffer is at capacity.
        pub fn pushFront(self: *Self, item: T) !void {
            if (self.count >= self.buffer.len) {
                return error.FullQueue;
            }

            // Move head back by one (wrapping around if necessary)
            self.head = if (self.head == 0) self.buffer.len - 1 else self.head - 1;
            self.buffer[self.head] = item;
            self.count += 1;
        }

        /// View the item at the front without removing it.
        /// Returns error.EmptyQueue if the buffer is empty.
        pub fn peekFront(self: *const Self) !T {
            if (self.count == 0) {
                return error.EmptyQueue;
            }
            return self.buffer[self.head];
        }

        /// Get the number of items in the buffer.
        pub inline fn size(self: *const Self) usize {
            return self.count;
        }

        /// Check if the buffer is empty.
        pub inline fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }

        /// Check if the buffer is full.
        pub inline fn isFull(self: *const Self) bool {
            return self.count >= self.buffer.len;
        }

        /// Clear all items from the buffer.
        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
            self.count = 0;
        }

        /// Add multiple items to the back of the buffer.
        /// Optimized with single bounds check instead of checking on each iteration.
        pub fn pushBackSlice(self: *Self, items: []const T) !void {
            if (self.count + items.len > self.buffer.len) {
                return error.FullQueue;
            }

            for (items) |item| {
                self.buffer[self.tail] = item;
                self.tail = (self.tail + 1) % self.buffer.len;
            }
            self.count += items.len;
        }

        /// Remove multiple items from the front of the buffer.
        /// Returns a slice into a temporary buffer containing the removed items.
        pub fn popFrontMultiple(self: *Self, n: usize, out_buffer: []T) ![]T {
            if (n > self.count) {
                return error.InsufficientItems;
            }
            if (n > out_buffer.len) {
                return error.BufferTooSmall;
            }

            for (0..n) |i| {
                out_buffer[i] = try self.popFront();
            }

            return out_buffer[0..n];
        }

        /// Get an item at a specific index (0 = front).
        /// This is O(1) but should be used sparingly as it breaks the queue abstraction.
        pub fn getAt(self: *const Self, index: usize) !T {
            if (index >= self.count) {
                return error.IndexOutOfBounds;
            }

            const actual_index = (self.head + index) % self.buffer.len;
            return self.buffer[actual_index];
        }

        /// Remove N items from the back of the buffer (for undo operations).
        /// Returns error.InsufficientItems if trying to remove more than available.
        pub fn removeFromBack(self: *Self, n: usize) !void {
            if (n > self.count) {
                return error.InsufficientItems;
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
}

test "RingBuffer basic operations" {
    var buffer = RingBuffer(u32, 10).init();

    try std.testing.expectEqual(@as(usize, 0), buffer.size());
    try std.testing.expect(buffer.isEmpty());
    try std.testing.expect(!buffer.isFull());

    try buffer.pushBack(42);
    try std.testing.expectEqual(@as(usize, 1), buffer.size());

    const value = try buffer.popFront();
    try std.testing.expectEqual(@as(u32, 42), value);
    try std.testing.expect(buffer.isEmpty());
}

test "RingBuffer pushFront" {
    var buffer = RingBuffer(u32, 10).init();

    try buffer.pushBack(1);
    try buffer.pushFront(2);

    try std.testing.expectEqual(@as(usize, 2), buffer.size());

    const popped = try buffer.popFront();
    try std.testing.expectEqual(@as(u32, 2), popped);
}

test "RingBuffer peekFront" {
    var buffer = RingBuffer(u32, 10).init();

    try buffer.pushBack(42);

    const peeked = try buffer.peekFront();
    try std.testing.expectEqual(@as(u32, 42), peeked);
    try std.testing.expectEqual(@as(usize, 1), buffer.size()); // Size unchanged
}

test "RingBuffer pushBackSlice" {
    var buffer = RingBuffer(u32, 10).init();

    const values = [_]u32{ 1, 2, 3 };
    try buffer.pushBackSlice(&values);
    try std.testing.expectEqual(@as(usize, 3), buffer.size());

    const popped = try buffer.popFront();
    try std.testing.expectEqual(@as(u32, 1), popped);
}

test "RingBuffer wrap-around" {
    var buffer = RingBuffer(u32, 5).init();

    // Fill buffer
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try buffer.pushBack(i);
    }
    try std.testing.expect(buffer.isFull());

    // Remove 2 items
    _ = try buffer.popFront();
    _ = try buffer.popFront();

    // Add 2 more (will wrap around)
    try buffer.pushBack(10);
    try buffer.pushBack(11);

    try std.testing.expectEqual(@as(usize, 5), buffer.size());
}

test "RingBuffer getAt" {
    var buffer = RingBuffer(u32, 10).init();

    try buffer.pushBack(10);
    try buffer.pushBack(20);
    try buffer.pushBack(30);

    const value = try buffer.getAt(1);
    try std.testing.expectEqual(@as(u32, 20), value);

    try std.testing.expectError(error.IndexOutOfBounds, buffer.getAt(10));
}

test "RingBuffer removeFromBack" {
    var buffer = RingBuffer(u32, 10).init();

    try buffer.pushBack(1);
    try buffer.pushBack(2);
    try buffer.pushBack(3);
    try std.testing.expectEqual(@as(usize, 3), buffer.size());

    try buffer.removeFromBack(2);
    try std.testing.expectEqual(@as(usize, 1), buffer.size());

    const value = try buffer.popFront();
    try std.testing.expectEqual(@as(u32, 1), value);
}

test "RingBuffer clear" {
    var buffer = RingBuffer(u32, 10).init();

    try buffer.pushBack(1);
    try buffer.pushBack(2);

    buffer.clear();
    try std.testing.expectEqual(@as(usize, 0), buffer.size());
    try std.testing.expect(buffer.isEmpty());
}

test "RingBuffer with struct type" {
    const Point = struct { x: i32, y: i32 };
    var buffer = RingBuffer(Point, 5).init();

    try buffer.pushBack(.{ .x = 10, .y = 20 });
    try buffer.pushBack(.{ .x = 30, .y = 40 });

    try std.testing.expectEqual(@as(usize, 2), buffer.size());

    const point = try buffer.popFront();
    try std.testing.expectEqual(@as(i32, 10), point.x);
    try std.testing.expectEqual(@as(i32, 20), point.y);
}

//! Fixed-size buffer for zero-allocation storage.
//!
//! Provides a compile-time sized buffer that can store any type without
//! dynamic allocation. Useful for game state management where maximum
//! capacity is known at compile time.

const std = @import("std");

/// A fixed-size buffer that can store up to `capacity` items of type `T`.
/// No dynamic allocation - all storage is on the stack or embedded in the parent struct.
pub fn FixedBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]T = undefined,
        len: usize = 0,

        /// Initialize an empty buffer.
        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .len = 0,
            };
        }

        /// Append an item to the buffer.
        /// Returns error.BufferFull if capacity is exceeded.
        pub fn append(self: *Self, item: T) !void {
            if (self.len >= capacity) return error.BufferFull;
            self.buffer[self.len] = item;
            self.len += 1;
        }

        /// Get a slice of all valid items in the buffer.
        pub fn items(self: *const Self) []const T {
            return self.buffer[0..self.len];
        }

        /// Remove and return the last item from the buffer.
        /// Returns error.EmptyBuffer if the buffer is empty.
        pub fn pop(self: *Self) !T {
            if (self.len == 0) return error.EmptyBuffer;
            self.len -= 1;
            return self.buffer[self.len];
        }

        /// Clear the buffer without deallocating (no-op for fixed buffer).
        pub fn clearRetainingCapacity(self: *Self) void {
            self.len = 0;
        }

        /// Append multiple items from a slice.
        /// Returns error.BufferFull if the slice doesn't fit.
        pub fn appendSlice(self: *Self, slice: []const T) !void {
            if (self.len + slice.len > capacity) return error.BufferFull;
            @memcpy(self.buffer[self.len..][0..slice.len], slice);
            self.len += slice.len;
        }

        /// Get the number of items currently in the buffer.
        pub inline fn size(self: *const Self) usize {
            return self.len;
        }

        /// Check if the buffer is empty.
        pub inline fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Check if the buffer is at capacity.
        pub inline fn isFull(self: *const Self) bool {
            return self.len >= capacity;
        }

        /// Remove multiple items from the end of the buffer.
        /// Returns error.InsufficientItems if trying to remove more than available.
        pub fn popMultiple(self: *Self, count: usize) !void {
            if (count > self.len) {
                return error.InsufficientItems;
            }
            self.len -= count;
        }

        /// Peek at the last item without removing it.
        /// Returns error.EmptyBuffer if the buffer is empty.
        pub fn peekLast(self: *const Self) !T {
            if (self.len == 0) {
                return error.EmptyBuffer;
            }
            return self.buffer[self.len - 1];
        }
    };
}

test "FixedBuffer basic operations" {
    var buffer = FixedBuffer(u32, 10).init();

    try std.testing.expectEqual(@as(usize, 0), buffer.size());
    try std.testing.expect(buffer.isEmpty());

    try buffer.append(42);
    try std.testing.expectEqual(@as(usize, 1), buffer.size());

    const value = try buffer.pop();
    try std.testing.expectEqual(@as(u32, 42), value);
    try std.testing.expect(buffer.isEmpty());
}

test "FixedBuffer appendSlice" {
    var buffer = FixedBuffer(u32, 10).init();

    const values = [_]u32{ 1, 2, 3, 4, 5 };
    try buffer.appendSlice(&values);

    try std.testing.expectEqual(@as(usize, 5), buffer.size());

    const items_slice = buffer.items();
    try std.testing.expectEqual(@as(usize, 5), items_slice.len);
    try std.testing.expectEqual(@as(u32, 1), items_slice[0]);
    try std.testing.expectEqual(@as(u32, 5), items_slice[4]);
}

test "FixedBuffer capacity enforcement" {
    var buffer = FixedBuffer(u32, 3).init();

    try buffer.append(1);
    try buffer.append(2);
    try buffer.append(3);

    try std.testing.expect(buffer.isFull());
    try std.testing.expectError(error.BufferFull, buffer.append(4));
}

test "FixedBuffer clear" {
    var buffer = FixedBuffer(u32, 10).init();

    try buffer.append(1);
    try buffer.append(2);
    try std.testing.expectEqual(@as(usize, 2), buffer.size());

    buffer.clearRetainingCapacity();
    try std.testing.expectEqual(@as(usize, 0), buffer.size());
    try std.testing.expect(buffer.isEmpty());
}

test "FixedBuffer with struct type" {
    const Point = struct { x: i32, y: i32 };
    var buffer = FixedBuffer(Point, 5).init();

    try buffer.append(.{ .x = 10, .y = 20 });
    try buffer.append(.{ .x = 30, .y = 40 });

    try std.testing.expectEqual(@as(usize, 2), buffer.size());

    const point = try buffer.pop();
    try std.testing.expectEqual(@as(i32, 30), point.x);
    try std.testing.expectEqual(@as(i32, 40), point.y);
}

test "FixedBuffer popMultiple" {
    var buffer = FixedBuffer(u32, 10).init();

    try buffer.append(1);
    try buffer.append(2);
    try buffer.append(3);
    try buffer.append(4);
    try buffer.append(5);

    try std.testing.expectEqual(@as(usize, 5), buffer.size());

    try buffer.popMultiple(3);
    try std.testing.expectEqual(@as(usize, 2), buffer.size());

    const value = try buffer.pop();
    try std.testing.expectEqual(@as(u32, 2), value);

    try std.testing.expectError(error.InsufficientItems, buffer.popMultiple(5));
}

test "FixedBuffer peekLast" {
    var buffer = FixedBuffer(u32, 10).init();

    try std.testing.expectError(error.EmptyBuffer, buffer.peekLast());

    try buffer.append(42);
    try buffer.append(99);

    const value = try buffer.peekLast();
    try std.testing.expectEqual(@as(u32, 99), value);
    try std.testing.expectEqual(@as(usize, 2), buffer.size()); // Size unchanged
}

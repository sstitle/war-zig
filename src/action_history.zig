const std = @import("std");

/// Ring buffer-based action history for efficient undo/redo.
/// Stores a fixed number of recent actions to support tens of thousands of rounds
/// without unbounded memory growth.
pub fn ActionHistory(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]T,
        /// Index of the oldest action in the buffer
        start: usize,
        /// Number of valid actions currently stored
        count: usize,
        /// Current position in the history (for undo/redo)
        cursor: usize,

        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .start = 0,
                .count = 0,
                .cursor = 0,
            };
        }

        /// Push a new action onto the history.
        /// If the buffer is full, the oldest action is discarded.
        /// This also clears any redo history (actions after cursor).
        pub fn push(self: *Self, action: T) void {
            // If we're not at the end of history, discard redo actions
            if (self.cursor < self.count) {
                self.count = self.cursor;
            }

            // Calculate write position
            const write_pos = (self.start + self.count) % capacity;
            self.buffer[write_pos] = action;

            if (self.count < capacity) {
                // Buffer not full yet
                self.count += 1;
            } else {
                // Buffer full, overwrite oldest
                self.start = (self.start + 1) % capacity;
            }

            self.cursor = self.count;
        }

        /// Returns true if there are actions that can be undone
        pub fn canUndo(self: *const Self) bool {
            return self.cursor > 0;
        }

        /// Returns true if there are actions that can be redone
        pub fn canRedo(self: *const Self) bool {
            return self.cursor < self.count;
        }

        /// Get the action to undo (moves cursor back)
        pub fn undo(self: *Self) ?*T {
            if (!self.canUndo()) return null;

            self.cursor -= 1;
            const index = (self.start + self.cursor) % capacity;
            return &self.buffer[index];
        }

        /// Get the action to redo (moves cursor forward)
        pub fn redo(self: *Self) ?*T {
            if (!self.canRedo()) return null;

            const index = (self.start + self.cursor) % capacity;
            self.cursor += 1;
            return &self.buffer[index];
        }

        /// Get the current action (for inspection without modifying cursor)
        pub fn current(self: *const Self) ?*const T {
            if (self.cursor == 0 or self.cursor > self.count) return null;

            const index = (self.start + self.cursor - 1) % capacity;
            return &self.buffer[index];
        }

        /// Clear all history
        pub fn clear(self: *Self) void {
            self.start = 0;
            self.count = 0;
            self.cursor = 0;
        }

        /// Get the number of actions that can be undone
        pub fn undoCount(self: *const Self) usize {
            return self.cursor;
        }

        /// Get the number of actions that can be redone
        pub fn redoCount(self: *const Self) usize {
            return self.count - self.cursor;
        }

        /// Get total number of stored actions
        pub fn size(self: *const Self) usize {
            return self.count;
        }
    };
}

test "ActionHistory basic push and undo" {
    const History = ActionHistory(u32, 10);
    var history = History.init();

    try std.testing.expectEqual(@as(usize, 0), history.size());
    try std.testing.expect(!history.canUndo());
    try std.testing.expect(!history.canRedo());

    // Push some actions
    history.push(1);
    history.push(2);
    history.push(3);

    try std.testing.expectEqual(@as(usize, 3), history.size());
    try std.testing.expect(history.canUndo());
    try std.testing.expect(!history.canRedo());

    // Undo
    const action = history.undo();
    try std.testing.expect(action != null);
    try std.testing.expectEqual(@as(u32, 3), action.?.*);
    try std.testing.expectEqual(@as(usize, 2), history.cursor);
}

test "ActionHistory redo" {
    const History = ActionHistory(u32, 10);
    var history = History.init();

    history.push(1);
    history.push(2);
    history.push(3);

    // Undo twice
    _ = history.undo();
    _ = history.undo();

    try std.testing.expectEqual(@as(usize, 1), history.cursor);
    try std.testing.expect(history.canRedo());

    // Redo
    const action = history.redo();
    try std.testing.expect(action != null);
    try std.testing.expectEqual(@as(u32, 2), action.?.*);
    try std.testing.expectEqual(@as(usize, 2), history.cursor);
}

test "ActionHistory ring buffer overflow" {
    const History = ActionHistory(u32, 3);
    var history = History.init();

    // Push more than capacity
    history.push(1);
    history.push(2);
    history.push(3);
    history.push(4); // Should overwrite 1

    try std.testing.expectEqual(@as(usize, 3), history.size());

    // Undo all
    var action = history.undo();
    try std.testing.expectEqual(@as(u32, 4), action.?.*);

    action = history.undo();
    try std.testing.expectEqual(@as(u32, 3), action.?.*);

    action = history.undo();
    try std.testing.expectEqual(@as(u32, 2), action.?.*);

    try std.testing.expect(!history.canUndo());
}

test "ActionHistory push clears redo" {
    const History = ActionHistory(u32, 10);
    var history = History.init();

    history.push(1);
    history.push(2);
    history.push(3);

    // Undo twice
    _ = history.undo();
    _ = history.undo();

    try std.testing.expect(history.canRedo());

    // Push new action - should clear redo history
    history.push(4);

    try std.testing.expect(!history.canRedo());
    try std.testing.expectEqual(@as(usize, 2), history.size());
}

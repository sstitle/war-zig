const std = @import("std");

/// Command interface for the Command pattern.
/// Each command encapsulates a game action and knows how to do, undo, and redo itself.
///
/// - do(): Execute the command for the first time, modifying state and capturing undo info
/// - undo(): Reverse the command's effects using captured state
/// - redo(): Re-apply the command (cheaper than do() as we already have the result)
pub fn Command(comptime StateType: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        doFn: *const fn (ptr: *anyopaque, state: *StateType) anyerror!void,
        undoFn: *const fn (ptr: *anyopaque, state: *StateType) anyerror!void,
        redoFn: *const fn (ptr: *anyopaque, state: *StateType) anyerror!void,

        /// Execute the command for the first time
        pub fn do(self: Self, state: *StateType) !void {
            return self.doFn(self.ptr, state);
        }

        /// Reverse the command's effects
        pub fn undo(self: Self, state: *StateType) !void {
            return self.undoFn(self.ptr, state);
        }

        /// Re-apply the command (assumes it was previously done and undone)
        pub fn redo(self: Self, state: *StateType) !void {
            return self.redoFn(self.ptr, state);
        }

        /// Create a Command interface from a concrete command implementation.
        /// The concrete type must implement: do(*Self, *State), undo(*Self, *State), redo(*Self, *State)
        pub fn init(concrete_cmd: anytype) Self {
            const T = @TypeOf(concrete_cmd.*);

            const gen = struct {
                fn doImpl(ptr: *anyopaque, state: *StateType) !void {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.do(state);
                }

                fn undoImpl(ptr: *anyopaque, state: *StateType) !void {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.undo(state);
                }

                fn redoImpl(ptr: *anyopaque, state: *StateType) !void {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.redo(state);
                }
            };

            return Self{
                .ptr = concrete_cmd,
                .doFn = gen.doImpl,
                .undoFn = gen.undoImpl,
                .redoFn = gen.redoImpl,
            };
        }
    };
}

test "Command interface basic usage" {
    // Simple test state
    const TestState = struct {
        value: i32,
    };

    // Concrete command that increments by a delta
    const IncrementCommand = struct {
        delta: i32,
        previous_value: i32 = undefined,

        pub fn do(self: *@This(), state: *TestState) !void {
            self.previous_value = state.value;
            state.value += self.delta;
        }

        pub fn undo(self: *@This(), state: *TestState) !void {
            state.value = self.previous_value;
        }

        pub fn redo(self: *@This(), state: *TestState) !void {
            state.value = self.previous_value + self.delta;
        }
    };

    var state = TestState{ .value = 10 };
    var inc_cmd = IncrementCommand{ .delta = 5 };
    const cmd = Command(TestState).init(&inc_cmd);

    // Initial state
    try std.testing.expectEqual(@as(i32, 10), state.value);

    // Do: 10 + 5 = 15
    try cmd.do(&state);
    try std.testing.expectEqual(@as(i32, 15), state.value);

    // Undo: back to 10
    try cmd.undo(&state);
    try std.testing.expectEqual(@as(i32, 10), state.value);

    // Redo: 10 + 5 = 15
    try cmd.redo(&state);
    try std.testing.expectEqual(@as(i32, 15), state.value);
}

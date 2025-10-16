//! Terminal I/O utilities for interactive applications.
//!
//! Provides low-level terminal control for reading single keystrokes
//! and managing terminal modes.

const std = @import("std");

/// Read a single character from stdin without buffering or echo.
/// Sets the terminal to raw mode temporarily to capture a single keystroke.
///
/// Returns the character read, or error.EndOfStream if stdin is closed.
pub fn readKey() !u8 {
    const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };

    // Save original terminal settings
    const original = try std.posix.tcgetattr(stdin.handle);

    // Set terminal to raw mode for single-character input
    var raw = original;
    raw.lflag.ICANON = false; // Disable canonical mode (line buffering)
    raw.lflag.ECHO = false; // Disable echo
    raw.cc[@intFromEnum(std.posix.V.MIN)] = 1; // Minimum characters to read
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 0; // No timeout

    try std.posix.tcsetattr(stdin.handle, .FLUSH, raw);
    defer std.posix.tcsetattr(stdin.handle, .FLUSH, original) catch {};

    var buf: [1]u8 = undefined;
    const n = try stdin.read(&buf);
    if (n == 0) return error.EndOfStream;

    return buf[0];
}

//! War game state rendering utilities.
//!
//! Provides formatted output for game state, commands, and results.

const std = @import("std");
const GameState = @import("state.zig").GameState;
const Player = @import("state.zig").Player;
const GameCommand = @import("commands.zig").GameCommand;

/// Print current game state summary
pub fn printState(state: *const GameState) !void {
    std.debug.print("Round {d} | Phase: {s}\n", .{
        state.round,
        @tagName(state.phase),
    });
    std.debug.print("P1: {d} cards | P2: {d} cards | War pile: {d} cards\n", .{
        state.handSize(.player1),
        state.handSize(.player2),
        state.war_pile.len,
    });
    std.debug.print("History: {d} actions ({d} undo, {d} redo available)\n", .{
        state.history.size(),
        state.history.undoCount(),
        state.history.redoCount(),
    });
}

/// Print command execution details
pub fn printCommandDetails(cmd: *const GameCommand) void {
    switch (cmd.*) {
        .play_cards => |*play| {
            std.debug.print("  Play Cards: P1 played {f}, P2 played {f}\n", .{
                play.p1_card,
                play.p2_card,
            });
        },
        .resolve_round => |*resolve| {
            if (resolve.was_war) {
                std.debug.print("  Resolve: Cards matched - WAR!\n", .{});
            } else {
                const winner_name = switch (resolve.winner) {
                    .player1 => "P1",
                    .player2 => "P2",
                };
                std.debug.print("  Resolve: {s} won {d} cards\n", .{
                    winner_name,
                    resolve.war_pile_len,
                });
            }
        },
        .war => |*war| {
            std.debug.print("  War: P1 put down {d} cards, P2 put down {d} cards\n", .{
                war.p1_count,
                war.p2_count,
            });
        },
    }
}

/// Print game over summary
pub fn printGameOver(state: *const GameState) !void {
    std.debug.print("Total rounds: {d}\n", .{state.round});

    if (state.winner()) |winner| {
        const winner_name = switch (winner) {
            .player1 => "Player 1",
            .player2 => "Player 2",
        };
        std.debug.print("Winner: {s}\n", .{winner_name});
        std.debug.print("Final card count - P1: {d}, P2: {d}\n", .{
            state.handSize(.player1),
            state.handSize(.player2),
        });
    }
}

/// Print game over summary for incomplete games
pub fn printIncompleteGame(state: *const GameState) void {
    std.debug.print("Max rounds reached - Game incomplete\n", .{});
    std.debug.print("Current card count - P1: {d}, P2: {d}\n", .{
        state.handSize(.player1),
        state.handSize(.player2),
    });
}

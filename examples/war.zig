const std = @import("std");
const war_zig = @import("war_zig");

const GameState = war_zig.GameState;
const Player = war_zig.Player;
const GamePhase = war_zig.GamePhase;
const GameCommand = war_zig.GameCommand;
const PlayCardsCommand = war_zig.PlayCardsCommand;
const ResolveRoundCommand = war_zig.ResolveRoundCommand;
const WarCommand = war_zig.WarCommand;

const Config = struct {
    step_mode: bool = false,
};

fn parseArgs(allocator: std.mem.Allocator) !Config {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip program name

    var config = Config{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--step")) {
            config.step_mode = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("Usage: war [OPTIONS]\n\n", .{});
            std.debug.print("Options:\n", .{});
            std.debug.print("  --step    Run in step mode with keyboard controls\n", .{});
            std.debug.print("  --help    Show this help message\n\n", .{});
            std.debug.print("Step Mode Controls:\n", .{});
            std.debug.print("  SPACE     Advance one round\n", .{});
            std.debug.print("  u         Undo last action\n", .{});
            std.debug.print("  r         Redo undone action\n", .{});
            std.debug.print("  q         Quit game\n", .{});
            std.process.exit(0);
        }
    }

    return config;
}

/// Read a single character from stdin without buffering
fn readKey() !u8 {
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

fn stepMode(state: *GameState) !void {
    std.debug.print("\n=== Step Mode ===\n", .{});
    std.debug.print("Press SPACE to advance, 'u' to undo, 'r' to redo, 'q' to quit\n\n", .{});

    printState(state) catch {};

    while (!state.isGameOver()) {
        std.debug.print("\nCommand: ", .{});

        const key = try readKey();
        std.debug.print("\n", .{});

        switch (key) {
            ' ' => {
                // Advance game
                try advanceGame(state);
                printState(state) catch {};
            },
            'u' => {
                // Undo
                if (state.history.canUndo()) {
                    const cmd = state.history.undo();
                    if (cmd) |c| {
                        try c.undo(state);
                        std.debug.print("⟲ Undone:\n", .{});
                        printCommandDetails(c);
                        printState(state) catch {};
                    }
                } else {
                    std.debug.print("Nothing to undo\n", .{});
                }
            },
            'r' => {
                // Redo
                if (state.history.canRedo()) {
                    const cmd = state.history.redo();
                    if (cmd) |c| {
                        try c.redo(state);
                        std.debug.print("⟳ Redone:\n", .{});
                        printCommandDetails(c);
                        printState(state) catch {};
                    }
                } else {
                    std.debug.print("Nothing to redo\n", .{});
                }
            },
            'q' => {
                std.debug.print("Quitting...\n", .{});
                return;
            },
            else => {
                std.debug.print("Unknown command: '{c}'\n", .{key});
            },
        }
    }

    std.debug.print("\n=== Game Over ===\n", .{});
    printGameOver(state) catch {};
}

fn advanceGame(state: *GameState) !void {
    // Play cards
    var play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
    try play_cmd.do(state);
    state.history.push(play_cmd);

    std.debug.print("▸ ", .{});
    printCommandDetails(&play_cmd);

    // Resolve the round
    var resolve_cmd = GameCommand{ .resolve_round = ResolveRoundCommand{} };
    try resolve_cmd.do(state);
    state.history.push(resolve_cmd);

    std.debug.print("▸ ", .{});
    printCommandDetails(&resolve_cmd);

    // Handle war if needed
    while (state.phase == .war and !state.isGameOver()) {
        var war_cmd = GameCommand{ .war = WarCommand{} };
        try war_cmd.do(state);
        state.history.push(war_cmd);

        std.debug.print("▸ ", .{});
        printCommandDetails(&war_cmd);

        if (state.isGameOver()) break;

        // Play and resolve after war
        play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
        try play_cmd.do(state);
        state.history.push(play_cmd);

        std.debug.print("▸ ", .{});
        printCommandDetails(&play_cmd);

        resolve_cmd = GameCommand{ .resolve_round = ResolveRoundCommand{} };
        try resolve_cmd.do(state);
        state.history.push(resolve_cmd);

        std.debug.print("▸ ", .{});
        printCommandDetails(&resolve_cmd);
    }
}

fn printCommandDetails(cmd: *const GameCommand) void {
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

fn printState(state: *GameState) !void {
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

fn printGameOver(state: *GameState) !void {
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

fn autoMode(state: *GameState) !void {
    std.debug.print("=== War Game ===\n", .{});
    std.debug.print("Starting with 26 cards each\n\n", .{});

    var round_num: u32 = 0;
    const max_rounds: comptime_int = 100_000;
    var war_count: u32 = 0;

    while (!state.isGameOver() and round_num < max_rounds) : (round_num += 1) {
        // Play cards
        var play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
        play_cmd.do(state) catch |err| {
            std.debug.print("Fatal error playing cards: {s}\n", .{@errorName(err)});
            return err;
        };
        state.history.push(play_cmd);

        // Print the cards played
        std.debug.print("Round {d}: P1 plays {f}, P2 plays {f}", .{
            round_num + 1,
            play_cmd.play_cards.p1_card,
            play_cmd.play_cards.p2_card,
        });

        // Resolve the round
        var resolve_cmd = GameCommand{ .resolve_round = ResolveRoundCommand{} };
        resolve_cmd.do(state) catch |err| {
            std.debug.print("Fatal error resolving round: {s}\n", .{@errorName(err)});
            return err;
        };
        state.history.push(resolve_cmd);

        // Print the result
        if (state.phase == .war) {
            std.debug.print(" -> TIE! WAR!\n", .{});
        } else {
            const winner_name = switch (resolve_cmd.resolve_round.winner) {
                .player1 => "P1",
                .player2 => "P2",
            };
            std.debug.print(" -> {s} wins (P1: {d} cards, P2: {d} cards)\n", .{
                winner_name,
                state.handSize(.player1),
                state.handSize(.player2),
            });
        }

        // If we're in a war state, handle it
        while (state.phase == .war) {
            war_count += 1;
            std.debug.print("  WAR #{d}: Each player puts down cards...\n", .{war_count});

            var war_cmd = GameCommand{ .war = WarCommand{} };
            war_cmd.do(state) catch |err| {
                std.debug.print("Fatal error during war: {s}\n", .{@errorName(err)});
                state.phase = .game_over;
                break;
            };
            state.history.push(war_cmd);

            // After war, play and resolve again
            play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
            play_cmd.do(state) catch |err| {
                std.debug.print("Fatal error playing cards after war: {s}\n", .{@errorName(err)});
                state.phase = .game_over;
                break;
            };
            state.history.push(play_cmd);

            std.debug.print("  War resolution: P1 plays {f}, P2 plays {f}", .{
                play_cmd.play_cards.p1_card,
                play_cmd.play_cards.p2_card,
            });

            var resolve_cmd2 = GameCommand{ .resolve_round = ResolveRoundCommand{} };
            resolve_cmd2.do(state) catch |err| {
                std.debug.print("Fatal error resolving after war: {s}\n", .{@errorName(err)});
                state.phase = .game_over;
                break;
            };
            state.history.push(resolve_cmd2);

            if (state.phase == .war) {
                std.debug.print(" -> ANOTHER TIE!\n", .{});
            } else {
                const winner_name = switch (resolve_cmd2.resolve_round.winner) {
                    .player1 => "P1",
                    .player2 => "P2",
                };
                std.debug.print(" -> {s} wins the war! (P1: {d} cards, P2: {d} cards)\n", .{
                    winner_name,
                    state.handSize(.player1),
                    state.handSize(.player2),
                });
            }
        }
    }

    // Print final results
    std.debug.print("\n=== Game Over ===\n", .{});
    std.debug.print("Total rounds: {d}\n", .{state.round});
    std.debug.print("Total wars: {d}\n", .{war_count});

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
    } else {
        std.debug.print("Max rounds reached - Game incomplete\n", .{});
        std.debug.print("Current card count - P1: {d}, P2: {d}\n", .{
            state.handSize(.player1),
            state.handSize(.player2),
        });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try parseArgs(allocator);

    // Create and shuffle a deck
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch break :blk 42;
        break :blk seed;
    });
    const random = prng.random();

    var deck = war_zig.Deck.init();
    deck.shuffle(random);

    // Initialize game state
    var state = try GameState.init(deck.cards);
    defer state.deinit();

    if (config.step_mode) {
        try stepMode(&state);
    } else {
        try autoMode(&state);
    }
}

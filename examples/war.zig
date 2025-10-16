const std = @import("std");
const war_zig = @import("war_zig");

const GameState = war_zig.GameState;
const Player = war_zig.Player;
const GamePhase = war_zig.GamePhase;
const GameCommand = war_zig.GameCommand;
const Config = war_zig.WarConfig;
const Orchestrator = war_zig.WarOrchestrator;
const Renderer = war_zig.WarRenderer;
const Terminal = war_zig.Terminal;

/// Default seed when getrandom fails (uses timestamp for non-determinism)
const use_timestamp_fallback = true;

const AppConfig = struct {
    step_mode: bool = false,
};

fn parseArgs(allocator: std.mem.Allocator) !AppConfig {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip program name

    var config = AppConfig{};
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

fn stepMode(state: *GameState) !void {
    std.debug.print("\n=== Step Mode ===\n", .{});
    std.debug.print("Press SPACE to advance, 'u' to undo, 'r' to redo, 'q' to quit\n\n", .{});

    try Renderer.printState(state);

    while (!state.isGameOver()) {
        std.debug.print("\nCommand: ", .{});

        const key = try Terminal.readKey();
        std.debug.print("\n", .{});

        switch (key) {
            ' ' => {
                // Advance game
                var turn_result = try Orchestrator.executeTurn(state);

                std.debug.print("▸ ", .{});
                Renderer.printCommandDetails(&turn_result.round_result.play_cmd);
                std.debug.print("▸ ", .{});
                Renderer.printCommandDetails(&turn_result.round_result.resolve_cmd);

                if (turn_result.war_result) |*wr| {
                    for (wr.getCommands()) |*cmd| {
                        std.debug.print("▸ ", .{});
                        Renderer.printCommandDetails(cmd);
                    }
                }

                try Renderer.printState(state);
            },
            'u' => {
                // Undo
                if (state.history.canUndo()) {
                    const cmd = state.history.undo();
                    if (cmd) |c| {
                        try c.undo(state);
                        std.debug.print("⟲ Undone:\n", .{});
                        Renderer.printCommandDetails(c);
                        try Renderer.printState(state);
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
                        Renderer.printCommandDetails(c);
                        try Renderer.printState(state);
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
    try Renderer.printGameOver(state);
}

fn autoMode(state: *GameState) !void {
    std.debug.print("=== War Game ===\n", .{});
    std.debug.print("Starting with {d} cards each\n\n", .{Config.cards_per_player});

    var round_num: u32 = 0;
    var war_count: u32 = 0;

    while (!state.isGameOver() and round_num < Config.max_rounds) : (round_num += 1) {
        var turn_result = Orchestrator.executeTurn(state) catch |err| {
            std.debug.print("Fatal error during turn: {s}\n", .{@errorName(err)});
            return err;
        };

        // Print the round
        const play_cmd = &turn_result.round_result.play_cmd;
        const resolve_cmd = &turn_result.round_result.resolve_cmd;

        std.debug.print("Round {d}: P1 plays {f}, P2 plays {f}", .{
            round_num + 1,
            play_cmd.play_cards.p1_card,
            play_cmd.play_cards.p2_card,
        });

        if (turn_result.round_result.entered_war) {
            std.debug.print(" -> TIE! WAR!\n", .{});

            // Handle war details
            if (turn_result.war_result) |*wr| {
                const commands = wr.getCommands();
                for (0..wr.war_count) |i| {
                    war_count += 1;
                    std.debug.print("  WAR #{d}: Each player puts down cards...\n", .{war_count});

                    // Find the war resolution in the commands
                    const war_resolution_idx = (i * 3) + 2; // Each war is 3 commands: war, play, resolve
                    if (war_resolution_idx < commands.len) {
                        const war_resolve_cmd = &commands[war_resolution_idx];
                        if (war_resolve_cmd.* == .resolve_round) {
                            const war_play_cmd = &commands[war_resolution_idx - 1];
                            std.debug.print("  War resolution: P1 plays {f}, P2 plays {f}", .{
                                war_play_cmd.play_cards.p1_card,
                                war_play_cmd.play_cards.p2_card,
                            });

                            if (state.phase == .war and i + 1 < wr.war_count) {
                                std.debug.print(" -> ANOTHER TIE!\n", .{});
                            } else {
                                const winner_name = switch (war_resolve_cmd.resolve_round.winner) {
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
                }
            }
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
    }

    // Print final results
    std.debug.print("\n=== Game Over ===\n", .{});
    std.debug.print("Total rounds: {d}\n", .{state.round});
    std.debug.print("Total wars: {d}\n", .{war_count});

    if (state.winner()) |_| {
        try Renderer.printGameOver(state);
    } else {
        Renderer.printIncompleteGame(state);
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
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            // Fall back to timestamp-based seed if getrandom fails
            seed = if (use_timestamp_fallback)
                @intCast(std.time.milliTimestamp())
            else
                0; // Deterministic fallback for testing
            break :blk seed;
        };
        break :blk seed;
    });
    const random = prng.random();

    var deck = war_zig.Deck.init();
    deck.shuffle(random);

    // Initialize game state
    var state = try GameState.init(deck.cards);

    if (config.step_mode) {
        try stepMode(&state);
    } else {
        try autoMode(&state);
    }
}

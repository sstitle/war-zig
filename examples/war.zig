const std = @import("std");
const war_zig = @import("war_zig");

const GameState = war_zig.GameState;
const Player = war_zig.Player;
const GamePhase = war_zig.GamePhase;
const PlayCardsCommand = war_zig.PlayCardsCommand;
const ResolveRoundCommand = war_zig.ResolveRoundCommand;
const WarCommand = war_zig.WarCommand;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
    var state = try GameState.init(allocator, deck.cards);
    defer state.deinit();

    std.debug.print("=== War Game ===\n", .{});
    std.debug.print("Starting with 26 cards each\n\n", .{});

    // Play the game
    var round_num: u32 = 0;
    const max_rounds: u32 = 50000; // Prevent infinite loops
    var war_count: u32 = 0;

    while (!state.isGameOver() and round_num < max_rounds) : (round_num += 1) {
        // Play cards
        var play_cmd = PlayCardsCommand{};
        play_cmd.do(&state) catch |err| {
            std.debug.print("Error playing cards: {}\n", .{err});
            break;
        };

        // Print the cards played
        std.debug.print("Round {d}: P1 plays {f}, P2 plays {f}", .{
            round_num + 1,
            play_cmd.p1_card,
            play_cmd.p2_card,
        });

        // Resolve the round
        var resolve_cmd = ResolveRoundCommand{};
        defer resolve_cmd.deinit(allocator);

        resolve_cmd.do(&state) catch |err| {
            std.debug.print("Error resolving round: {}\n", .{err});
            break;
        };

        // Print the result
        if (state.phase == .war) {
            std.debug.print(" -> TIE! WAR!\n", .{});
        } else {
            const winner_name = switch (resolve_cmd.winner) {
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

            var war_cmd = WarCommand{};
            defer war_cmd.deinit(allocator);

            war_cmd.do(&state) catch |err| {
                std.debug.print("Error during war: {}\n", .{err});
                state.phase = .game_over;
                break;
            };

            // After war, play and resolve again
            play_cmd = PlayCardsCommand{};
            play_cmd.do(&state) catch |err| {
                std.debug.print("Error playing cards after war: {}\n", .{err});
                break;
            };

            std.debug.print("  War resolution: P1 plays {f}, P2 plays {f}", .{
                play_cmd.p1_card,
                play_cmd.p2_card,
            });

            var resolve_cmd2 = ResolveRoundCommand{};
            defer resolve_cmd2.deinit(allocator);

            resolve_cmd2.do(&state) catch |err| {
                std.debug.print("Error resolving after war: {}\n", .{err});
                break;
            };

            if (state.phase == .war) {
                std.debug.print(" -> ANOTHER TIE!\n", .{});
                // Loop continues to handle the next war
            } else {
                const winner_name = switch (resolve_cmd2.winner) {
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

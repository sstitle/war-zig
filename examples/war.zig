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
    var state = GameState.init(deck.cards);

    std.debug.print("=== War Game ===\n", .{});
    std.debug.print("Starting with 26 cards each\n\n", .{});

    // Play the game
    var round_num: u32 = 0;
    const max_rounds: u32 = 10000; // Prevent infinite loops

    while (!state.isGameOver() and round_num < max_rounds) : (round_num += 1) {
        // Play cards
        var play_cmd = PlayCardsCommand{};
        play_cmd.do(&state) catch |err| {
            std.debug.print("Error playing cards: {}\n", .{err});
            break;
        };

        // Resolve the round
        var resolve_cmd = ResolveRoundCommand{};
        resolve_cmd.do(&state) catch |err| {
            std.debug.print("Error resolving round: {}\n", .{err});
            break;
        };

        // If we're in a war state, handle it
        if (state.phase == .war) {
            std.debug.print("Round {d}: WAR!\n", .{round_num + 1});

            var war_cmd = WarCommand{};
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

            resolve_cmd = ResolveRoundCommand{};
            resolve_cmd.do(&state) catch |err| {
                std.debug.print("Error resolving after war: {}\n", .{err});
                break;
            };
        }

        // Print status every 1000 rounds
        if (round_num % 1000 == 0) {
            std.debug.print("Round {d}: P1={d} cards, P2={d} cards\n", .{
                round_num + 1,
                state.handSize(.player1),
                state.handSize(.player2),
            });
        }
    }

    // Print final results
    std.debug.print("\n=== Game Over ===\n", .{});
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
    } else {
        std.debug.print("Max rounds reached - Game incomplete\n", .{});
        std.debug.print("Current card count - P1: {d}, P2: {d}\n", .{
            state.handSize(.player1),
            state.handSize(.player2),
        });
    }
}

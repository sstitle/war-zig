//! War game orchestration logic.
//!
//! Handles game flow, command execution, and state transitions.
//! Consolidates common game logic used by different UI modes.

const std = @import("std");
const GameState = @import("state.zig").GameState;
const GameCommand = @import("commands.zig").GameCommand;
const PlayCardsCommand = @import("commands.zig").PlayCardsCommand;
const ResolveRoundCommand = @import("commands.zig").ResolveRoundCommand;
const WarCommand = @import("commands.zig").WarCommand;

const MAX_WARS_PER_TURN = 20; // Reasonable upper bound for wars in a single turn

/// Execute a single round: play cards and resolve
pub fn executeRound(state: *GameState) !RoundResult {
    var result = RoundResult{};

    // Play cards
    var play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
    try play_cmd.do(state);
    state.history.push(play_cmd);
    result.play_cmd = play_cmd;

    // Resolve the round
    var resolve_cmd = GameCommand{ .resolve_round = ResolveRoundCommand{} };
    try resolve_cmd.do(state);
    state.history.push(resolve_cmd);
    result.resolve_cmd = resolve_cmd;

    result.entered_war = state.phase == .war;

    return result;
}

/// Handle complete war phase until resolved
pub fn handleWarPhase(state: *GameState) !WarResult {
    var result = WarResult{
        .war_count = 0,
        .commands_count = 0,
    };

    while (state.phase == .war and !state.isGameOver() and result.war_count < MAX_WARS_PER_TURN) {
        result.war_count += 1;

        // Execute war command
        var war_cmd = GameCommand{ .war = WarCommand{} };
        try war_cmd.do(state);
        state.history.push(war_cmd);
        result.commands[result.commands_count] = war_cmd;
        result.commands_count += 1;

        if (state.isGameOver()) break;

        // Play and resolve after war
        var play_cmd = GameCommand{ .play_cards = PlayCardsCommand{} };
        try play_cmd.do(state);
        state.history.push(play_cmd);
        result.commands[result.commands_count] = play_cmd;
        result.commands_count += 1;

        var resolve_cmd = GameCommand{ .resolve_round = ResolveRoundCommand{} };
        try resolve_cmd.do(state);
        state.history.push(resolve_cmd);
        result.commands[result.commands_count] = resolve_cmd;
        result.commands_count += 1;
    }

    return result;
}

/// Execute a complete game turn (round + any wars that occur)
pub fn executeTurn(state: *GameState) !TurnResult {
    var result = TurnResult{
        .round_result = try executeRound(state),
        .war_result = null,
    };

    // Handle war if it occurred
    if (result.round_result.entered_war) {
        result.war_result = try handleWarPhase(state);
    }

    return result;
}

/// Result of executing a single round
pub const RoundResult = struct {
    play_cmd: GameCommand = undefined,
    resolve_cmd: GameCommand = undefined,
    entered_war: bool = false,
};

/// Result of handling a complete war phase
pub const WarResult = struct {
    war_count: u32,
    commands: [MAX_WARS_PER_TURN * 3]GameCommand = undefined, // 3 commands per war
    commands_count: usize,

    pub fn getCommands(self: *const WarResult) []const GameCommand {
        return self.commands[0..self.commands_count];
    }
};

/// Result of a complete turn (round + potential wars)
pub const TurnResult = struct {
    round_result: RoundResult,
    war_result: ?WarResult,

    pub fn deinit(self: *TurnResult) void {
        // No cleanup needed - using fixed-size buffers
        _ = self;
    }
};

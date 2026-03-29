package sim

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import game "../src"

MAX_SIM_TURNS :: 200
MAX_ROUNDS :: 100_000

Sim_Config :: struct {
	encounter: string,
	rounds:    int,
	seed:      u64,
	csv_path:  string,
	no_skulls: bool,
	combat:    bool,   // single game with full combat log
	replay:    string, // path to a decision trace file for replay mode
}

main :: proc() {
	config := parse_args()

	skull_chance := config.no_skulls ? 0 : game.SKULL_CHANCE

	// Validate encounter loads
	{
		_, _, ok := game.config_load_encounter(config.encounter)
		if !ok {
			fmt.eprintfln("Failed to load encounter: %s", config.encounter)
			os.exit(1)
		}
	}

	// --- Combat mode: single game with full combat log ---
	if config.combat {
		run_combat(config, skull_chance)
		return
	}

	// --- Replay mode: drive player decisions from a trace file ---
	if config.replay != "" {
		run_replay(config.replay, skull_chance)
		return
	}

	// --- Stats mode: N games with aggregate statistics ---
	fmt.printfln(
		"Simulating %d rounds of '%s' (seed: %d)%s...",
		config.rounds,
		config.encounter,
		config.seed,
		config.no_skulls ? " [no skulls]" : "",
	)

	all_stats := make([]Game_Stats, config.rounds)
	defer delete(all_stats)

	rolls := new(Roll_Collector)
	defer free(rolls)

	agg: Aggregate_Stats
	sw := time.tick_now()

	for round in 0 ..< config.rounds {
		game_seed := config.seed + u64(round)
		rand.reset(game_seed)

		gs, ok := game.game_init(config.encounter, nil, skull_chance)
		if !ok {
			fmt.eprintfln("Failed to init game for round %d", round + 1)
			continue
		}

		game_stats := Game_Stats{seed = game_seed}
		game_stats.player_count = gs.player_party.count
		game_stats.enemy_count = gs.enemy_party.count
		for i in 0 ..< gs.player_party.count {
			init_char_stats_meta(&game_stats.player_chars[i], &gs.player_party.characters[i])
		}
		for i in 0 ..< gs.enemy_party.count {
			init_char_stats_meta(&game_stats.enemy_chars[i], &gs.enemy_party.characters[i])
		}

		run_game(&gs, &game_stats, rolls)

		all_stats[round] = game_stats
		aggregate_add(&agg, &game_stats)
	}

	elapsed := time.tick_since(sw)
	ms := time.duration_milliseconds(elapsed)

	fmt.println()
	dice_aggs := aggregate_dice(rolls)
	dcm := aggregate_dice_count(rolls)
	print_summary(config.encounter, config.seed, &agg, &dice_aggs, &dcm)

	fmt.println()
	fmt.printfln("Completed in %.0f ms (%.1f games/sec)", ms, f64(config.rounds) / (ms / 1000.0))

	if len(config.csv_path) > 0 && config.rounds > 0 {
		ok := write_csv(config.csv_path, all_stats, agg.player_count, agg.enemy_count)
		if ok {
			fmt.printfln("CSV written to %s", config.csv_path)
		} else {
			fmt.eprintfln("Failed to write CSV: %s", config.csv_path)
		}
	}
}

// Run a single game with full combat log output to stdout.
run_combat :: proc(config: Sim_Config, skull_chance: int) {
	rand.reset(config.seed)

	// Enable file output before game_init so the seed line is captured
	clog: game.Combat_Log
	game.combat_log_init_file(&clog)

	gs, ok := game.game_init(config.encounter, &clog, skull_chance, seed = config.seed)
	if !ok {
		fmt.eprintfln("Failed to init game")
		os.exit(1)
	}

	// Run the game
	stats := Game_Stats{seed = config.seed}
	rolls := new(Roll_Collector)
	defer free(rolls)
	run_game(&gs, &stats, rolls)

	// Print the full combat log to stdout
	game.combat_log_print(&gs.log)

	// Print outcome
	fmt.println()
	switch stats.winner {
	case .Player: fmt.printfln("Result: VICTORY in %d turns", stats.turns)
	case .Enemy:  fmt.printfln("Result: DEFEAT in %d turns", stats.turns)
	case .Draw:   fmt.printfln("Result: DRAW (turn limit %d)", stats.turns)
	}
}

// Tick turn-based conditions for all characters in a party (sim version).
tick_sim_conditions :: proc(party: ^game.Party) {
	for i in 0 ..< party.count {
		game.condition_tick_turns(&party.characters[i])
	}
}

// --- Headless game loop ---

// Snapshot all party HP into a fixed array.
snapshot_party_hp :: proc(party: ^game.Party) -> [game.MAX_PARTY_SIZE]int {
	hp: [game.MAX_PARTY_SIZE]int
	for i in 0 ..< party.count {
		hp[i] = party.characters[i].stats.hp
	}
	return hp
}

// Swap player and enemy parties/hands so ai_take_turn acts on the other side.
// ai_take_turn is hardcoded to operate on enemy_party/enemy_hand, so we swap
// before calling it for the player side, then swap back and fix the turn phase.
swap_sides :: proc(gs: ^game.Game_State) {
	gs.player_party, gs.enemy_party = gs.enemy_party, gs.player_party
	gs.hand, gs.enemy_hand = gs.enemy_hand, gs.hand
}

// Fix turn phase after a swapped AI call for the player side.
// The AI sets phases as if it were the enemy — we remap to player equivalents.
fix_player_draft_phase :: proc(gs: ^game.Game_State) {
	#partial switch gs.turn {
	case .Draft_Player_Pick:
		gs.turn = .Draft_Enemy_Pick
	case .Combat_Enemy_Turn:
		gs.turn = .Combat_Player_Turn
	case .Combat_Player_Turn:
		gs.turn = .Combat_Enemy_Turn
	}
}

fix_player_combat_phase :: proc(gs: ^game.Game_State) {
	#partial switch gs.turn {
	case .Enemy_Roll_Result:
		gs.turn = .Player_Roll_Result
	case .Combat_Enemy_Turn:
		// ai_combat_turn looped back to roll another — remap to player side
		gs.turn = .Combat_Player_Turn
	case .Round_End:
		// Player side finished rolling — enemy still needs to go
		gs.turn = .Combat_Enemy_Turn
	}
}

// After ai_take_turn produces a roll result, collect stats from the roll.
collect_after_roll :: proc(
	stats: ^Game_Stats,
	rolls: ^Roll_Collector,
	gs: ^game.Game_State,
	is_player_attacking: bool,
	attacker_hp_before: [game.MAX_PARTY_SIZE]int,
	target_hp_before: [game.MAX_PARTY_SIZE]int,
) {
	ci := gs.rolling_index
	attacker_party := is_player_attacking ? &gs.player_party : &gs.enemy_party
	target_party := is_player_attacking ? &gs.enemy_party : &gs.player_party

	attacker := &attacker_party.characters[ci]
	target := game.get_target(target_party, ci)

	snap := Hp_Snapshot{attacker_hp = attacker_hp_before[ci]}
	if target != nil {
		for i in 0 ..< target_party.count {
			if &target_party.characters[i] == target {
				snap.target_hp = target_hp_before[i]
				break
			}
		}
	}

	collect_roll_stats(stats, is_player_attacking, ci, attacker, target, snap, rolls)
	if target != nil {
		collect_target_damage(stats, !is_player_attacking, target, target_party, snap)
	}
}

run_game :: proc(gs: ^game.Game_State, stats: ^Game_Stats, rolls: ^Roll_Collector) {
	turn_count := 0

	for {
		#partial switch gs.turn {
		// --- Draft Phase ---
		case .Draft_Player_Pick:
			// Swap so ai_draft_pick acts on the player side
			swap_sides(gs)
			game.ai_draft_pick(gs)
			swap_sides(gs)
			fix_player_draft_phase(gs)

		case .Draft_Enemy_Pick:
			game.ai_draft_pick(gs)

		// --- Combat Phase ---
		case .Combat_Player_Turn:
			player_hp := snapshot_party_hp(&gs.player_party)
			enemy_hp := snapshot_party_hp(&gs.enemy_party)

			// Swap so ai_combat_turn acts on the player side
			swap_sides(gs)
			game.ai_combat_turn(gs)
			swap_sides(gs)
			fix_player_combat_phase(gs)
			turn_count += 1

			if gs.turn == .Player_Roll_Result {
				collect_after_roll(stats, rolls, gs, true, player_hp, enemy_hp)
			}

		case .Player_Roll_Result:
			game.character_clear_roll(&gs.player_party.characters[gs.rolling_index])
			gs.turn_timer = 0
			// Back to player combat turn to roll more characters
			next := game.check_win_lose(gs, .Combat_Player_Turn)
			gs.turn = next

		case .Combat_Enemy_Turn:
			enemy_hp := snapshot_party_hp(&gs.enemy_party)
			player_hp := snapshot_party_hp(&gs.player_party)

			game.ai_combat_turn(gs)
			turn_count += 1

			if gs.turn == .Enemy_Roll_Result {
				collect_after_roll(stats, rolls, gs, false, enemy_hp, player_hp)
			}

		case .Enemy_Roll_Result:
			game.character_clear_roll(&gs.enemy_party.characters[gs.rolling_index])
			gs.turn_timer = 0
			// Back to enemy combat turn to roll more characters
			next := game.check_win_lose(gs, .Combat_Enemy_Turn)
			gs.turn = next

		case .Round_End:
			// Check win/lose, then start next round
			game.round_end_update(gs)

		case .Victory:
			stats.winner = .Player
			stats.turns = turn_count
			collect_endgame(stats, &gs.player_party, true)
			collect_endgame(stats, &gs.enemy_party, false)
			return

		case .Defeat:
			stats.winner = .Enemy
			stats.turns = turn_count
			collect_endgame(stats, &gs.player_party, true)
			collect_endgame(stats, &gs.enemy_party, false)
			return
		}

		if turn_count > MAX_SIM_TURNS {
			stats.winner = .Draw
			stats.turns = turn_count
			collect_endgame(stats, &gs.player_party, true)
			collect_endgame(stats, &gs.enemy_party, false)
			return
		}
	}
}

// --- Replay mode ---

// Drive the player side from a decision trace. Enemy turns are still AI-driven.
// Fails hard with an error message if the trace diverges from game state.
run_replay :: proc(path: string, skull_chance: int) {
	reader, load_ok := trace_reader_load(path)
	if !load_ok {
		fmt.eprintfln("Failed to load trace: %s", path)
		os.exit(1)
	}
	defer trace_reader_destroy(&reader)

	if reader.seed == 0 {
		fmt.eprintfln("trace: missing SEED header in %s", path)
		os.exit(1)
	}
	if reader.encounter == "" {
		fmt.eprintfln("trace: missing ENCOUNTER header in %s", path)
		os.exit(1)
	}

	fmt.printfln("Replaying trace: %s", path)
	fmt.printfln("  Seed:      %d", reader.seed)
	fmt.printfln("  Encounter: %s", reader.encounter)

	rand.reset(reader.seed)
	gs, game_ok := game.game_init(reader.encounter, nil, skull_chance, seed = reader.seed)
	if !game_ok {
		fmt.eprintfln("Failed to init game for encounter: %s", reader.encounter)
		os.exit(1)
	}

	// Consume the ROUND 1 marker that opens the trace
	replay_expect_round(&reader, 1)
	fmt.printfln("  [Round 1]")

	turn_count := 0
	ai_fallback := false // true once the trace is exhausted; player side runs on AI

	for {
		#partial switch gs.turn {
		case .Draft_Player_Pick:
			if ai_fallback {
				swap_sides(&gs)
				game.ai_draft_pick(&gs)
				swap_sides(&gs)
				fix_player_draft_phase(&gs)
			} else {
				ai_fallback = replay_draft_player_pick(&gs, &reader)
			}

		case .Draft_Enemy_Pick:
			game.ai_draft_pick(&gs)

		case .Combat_Player_Turn:
			if !game.party_has_assigned_dice(&gs.player_party) {
				gs.turn = .Combat_Enemy_Turn
				continue
			}
			if ai_fallback {
				player_hp := snapshot_party_hp(&gs.player_party)
				enemy_hp := snapshot_party_hp(&gs.enemy_party)
				swap_sides(&gs)
				game.ai_combat_turn(&gs)
				swap_sides(&gs)
				fix_player_combat_phase(&gs)
				turn_count += 1
				_ = player_hp
				_ = enemy_hp
			} else {
				exhausted := replay_combat_player_turn(&gs, &reader)
				if exhausted {
					ai_fallback = true
				}
				turn_count += 1
			}

		case .Player_Roll_Result:
			game.character_clear_roll(&gs.player_party.characters[gs.rolling_index])
			gs.turn_timer = 0
			gs.turn = game.check_win_lose(&gs, .Combat_Player_Turn)

		case .Combat_Enemy_Turn:
			game.ai_combat_turn(&gs)
			turn_count += 1

		case .Enemy_Roll_Result:
			game.character_clear_roll(&gs.enemy_party.characters[gs.rolling_index])
			gs.turn_timer = 0
			gs.turn = game.check_win_lose(&gs, .Combat_Enemy_Turn)

		case .Round_End:
			game.round_end_update(&gs)
			// round_end_update transitions to Victory/Defeat or a new draft phase.
			// If it advanced to a new round, consume the ROUND marker from the trace.
			#partial switch gs.turn {
			case .Victory, .Defeat:
				// handled next iteration
			case:
				if !ai_fallback {
					// Skip stale DONE/ROLL actions before the ROUND marker.
					for {
						a, has := trace_peek(&reader)
						if !has {
							ai_fallback = true
							break
						}
						_, is_done := a.(Trace_Done)
						_, is_roll := a.(Trace_Roll)
						if !is_done && !is_roll {
							break
						}
						trace_next(&reader)
					}
					if !ai_fallback {
						action, has_action := trace_peek(&reader)
						if !has_action {
							ai_fallback = true
						} else if r, is_round := action.(Trace_Round); is_round {
							trace_next(&reader)
							fmt.printfln("  [Round %d]", r.number)
							if r.number != gs.round.round_number {
								fmt.eprintfln(
									"replay: round mismatch: trace says %d, game says %d",
									r.number,
									gs.round.round_number,
								)
								os.exit(1)
							}
						}
					}
				}
				if ai_fallback {
					fmt.printfln("  [Round %d] (AI)", gs.round.round_number)
				}
			}

		case .Victory:
			fmt.printfln("Result: VICTORY in %d turns", turn_count)
			return

		case .Defeat:
			fmt.printfln("Result: DEFEAT in %d turns", turn_count)
			return
		}

		if turn_count > MAX_SIM_TURNS {
			fmt.printfln("Result: DRAW (turn limit %d)", turn_count)
			return
		}
	}
}

// Execute player draft picks from the trace until one PICK uses the turn.
// Returns true if the trace was exhausted (caller should switch to AI fallback).
// Processes DISCARD free actions that appear before the PICK.
@(private)
replay_draft_player_pick :: proc(gs: ^game.Game_State, reader: ^Trace_Reader) -> (exhausted: bool) {
	// Process any free discards
	replay_consume_discards(gs, reader)

	// Skip stale DONE/ROLL actions. These appear when the original game had characters
	// with assigned dice that the player skipped (DONE) or rolled, but in the replay
	// those characters have no dice (auto-advance fires instead of consuming DONE/ROLL).
	for {
		action, has := trace_peek(reader)
		if !has {
			break
		}
		_, is_done := action.(Trace_Done)
		_, is_roll := action.(Trace_Roll)
		if !is_done && !is_roll {
			break
		}
		trace_next(reader)
	}

	action, ok := trace_next(reader)
	if !ok {
		return true
	}
	pick, is_pick := action.(Trace_Pick)
	if !is_pick {
		fmt.eprintfln("replay: expected PICK at pos %d, got: %v", reader.pos - 1, action)
		os.exit(1)
	}

	// Find the die type anywhere in the pool.
	// Pool order can drift from the original due to RNG divergence in combat outcomes,
	// so we match by type only — the trace records *what* was picked, not which slot.
	actual_idx := -1
	for i in 0 ..< gs.pool.remaining {
		if gs.pool.dice[i] == pick.die_type {
			actual_idx = i
			break
		}
	}
	if actual_idx < 0 {
		if gs.pool.remaining <= 0 {
			fmt.eprintfln("replay: PICK %s but pool is empty", game.DIE_TYPE_NAMES[pick.die_type])
			os.exit(1)
		}
		// Die type diverged (game state drift from prior combat outcomes).
		// Pick the closest-value die available so the replay still completes.
		wanted := game.DIE_FACES[pick.die_type]
		best_diff := max(int)
		for i in 0 ..< gs.pool.remaining {
			dt := gs.pool.dice[i]
			if dt == .Skull || dt == .None {
				continue
			}
			diff := abs(game.DIE_FACES[dt] - wanted)
			if diff < best_diff {
				best_diff = diff
				actual_idx = i
			}
		}
		// Last resort: any die (skull or otherwise)
		if actual_idx < 0 {
			actual_idx = 0
		}
		fmt.eprintfln(
			"replay: note: %s unavailable, substituting %s",
			game.DIE_TYPE_NAMES[pick.die_type],
			game.DIE_TYPE_NAMES[gs.pool.dice[actual_idx]],
		)
	}

	// Execute the pick
	game.pool_remove_die(&gs.pool, actual_idx)
	if pick.to_hand {
		game.hand_add(&gs.hand, pick.die_type)
	} else {
		if pick.char_index < 0 || pick.char_index >= gs.player_party.count {
			fmt.eprintfln("replay: PICK char_index %d out of range", pick.char_index)
			os.exit(1)
		}
		game.character_assign_die(&gs.player_party.characters[pick.char_index], pick.die_type)
	}

	// Advance turn phase (mirrors draft_player_pick_update)
	if game.pool_is_empty(&gs.pool) {
		gs.turn = .Combat_Player_Turn
	} else {
		gs.turn = .Draft_Enemy_Pick
	}
	return false
}

// Execute one player combat action (ROLL or DONE) from the trace.
// Returns true if the trace was exhausted (caller should switch to AI fallback).
// Processes DISCARD free actions that appear before the main action.
@(private)
replay_combat_player_turn :: proc(gs: ^game.Game_State, reader: ^Trace_Reader) -> (exhausted: bool) {
	// Process any free discards
	replay_consume_discards(gs, reader)

	action, ok := trace_next(reader)
	if !ok {
		return true
	}

	#partial switch a in action {
	case Trace_Roll:
		ci := a.char_index
		if ci < 0 || ci >= gs.player_party.count {
			fmt.eprintfln("replay: ROLL char_index %d out of range", ci)
			os.exit(1)
		}
		attacker := &gs.player_party.characters[ci]
		// The ROLL line is the ground truth for assigned dice.
		// Force-assign to account for hand→char moves not recorded in the trace.
		attacker.assigned_count = 0
		for i in 0 ..< game.MAX_CHARACTER_DICE {
			attacker.assigned[i] = {}
		}
		for i in 0 ..< a.dice_count {
			attacker.assigned[i] = a.dice[i]
		}
		attacker.assigned_count = a.dice_count
		target := game.get_target(&gs.enemy_party, ci)
		game.character_roll(attacker)
		game.resolve_roll(gs, attacker, target)
		gs.rolling_index = ci
		gs.turn = .Player_Roll_Result

	case Trace_Done:
		gs.turn = .Combat_Enemy_Turn

	case:
		fmt.eprintfln("replay: expected ROLL or DONE in Combat_Player_Turn, got something else")
		os.exit(1)
	}
	return false
}

// Consume DISCARD actions from the trace and execute them on the player hand.
// Searches by die type (not index) because hand→char assignments between picks
// are not recorded in the trace and can shift hand slot indices.
// Skips silently if the die is no longer in hand (moved to a character).
@(private)
replay_consume_discards :: proc(gs: ^game.Game_State, reader: ^Trace_Reader) {
	for {
		action, has_action := trace_peek(reader)
		if !has_action {
			return
		}
		d, is_discard := action.(Trace_Discard)
		if !is_discard {
			return
		}
		trace_next(reader)

		// Search for the die type anywhere in the hand
		found_slot := -1
		for i in 0 ..< gs.hand.count {
			if gs.hand.dice[i] == d.die_type {
				found_slot = i
				break
			}
		}
		if found_slot >= 0 {
			game.hand_discard(&gs.hand, found_slot)
		}
		// If not found: die was moved to a character — silently skip the discard
	}
}

// Expect and consume a ROUND marker. Fails if the trace has a different action.
@(private)
replay_expect_round :: proc(reader: ^Trace_Reader, expected: int) {
	action, ok := trace_next(reader)
	if !ok {
		fmt.eprintfln("replay: trace exhausted expecting ROUND %d", expected)
		os.exit(1)
	}
	r, is_round := action.(Trace_Round)
	if !is_round {
		fmt.eprintfln("replay: expected ROUND %d, got a different action", expected)
		os.exit(1)
	}
	if r.number != expected {
		fmt.eprintfln("replay: expected ROUND %d, got ROUND %d", expected, r.number)
		os.exit(1)
	}
}

// --- CLI parsing ---

parse_args :: proc() -> Sim_Config {
	config := Sim_Config {
		encounter = "tutorial",
		rounds    = 100,
		seed      = u64(time.time_to_unix(time.now())),
		csv_path  = "sim_results.csv",
	}

	args := os.args[1:]
	for arg in args {
		if strings.has_prefix(arg, "--encounter=") {
			config.encounter = arg[len("--encounter="):]
		} else if strings.has_prefix(arg, "--rounds=") {
			val, ok := strconv.parse_int(arg[len("--rounds="):])
			if ok {
				config.rounds = clamp(val, 1, MAX_ROUNDS)
			}
		} else if strings.has_prefix(arg, "--seed=") {
			val, ok := strconv.parse_u64(arg[len("--seed="):])
			if ok {
				config.seed = val
			}
		} else if strings.has_prefix(arg, "--csv=") {
			config.csv_path = arg[len("--csv="):]
		} else if arg == "--no-skulls" {
			config.no_skulls = true
		} else if arg == "--combat" {
			config.combat = true
		} else if strings.has_prefix(arg, "--replay=") {
			config.replay = arg[len("--replay="):]
		} else {
			fmt.eprintfln("Unknown argument: %s", arg)
			print_usage()
			os.exit(1)
		}
	}

	return config
}

print_usage :: proc() {
	fmt.eprintln("Usage: dicey-sim [options]")
	fmt.eprintln("  --encounter=NAME  Encounter to simulate (default: tutorial)")
	fmt.eprintln("  --rounds=N        Number of games (default: 100, max: 100000)")
	fmt.eprintln("  --seed=N          RNG seed (default: current time)")
	fmt.eprintln("  --csv=PATH        CSV output path (default: sim_results.csv)")
	fmt.eprintln("  --no-skulls       Disable skull dice in the pool")
	fmt.eprintln("  --combat          Run 1 game with full combat log (use --seed for replay)")
	fmt.eprintln("  --replay=PATH     Replay a decision trace (decision_trace.txt)")
}

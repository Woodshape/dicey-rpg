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
}

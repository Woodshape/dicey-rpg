package sim

import "core:fmt"
import "core:os"
import "core:strings"
import game "../src"

// --- Per-character stats collected during a single game ---

Char_Stats :: struct {
	name:                 cstring,
	damage_dealt:         int,
	damage_taken:         int,
	healing_done:         int,
	ability_fires:        int,
	ability_attempts:     int,
	resolve_fires:        int,
	skull_damage_dealt:   int,
	ability_damage_dealt: int, // main ability + resolve damage combined
	hp_remaining:         int,
	alive:                bool,
	die_type_used:        game.Die_Type,
	// Match distribution
	match_histogram:      [game.MAX_CHARACTER_DICE + 1]int, // [i] = rolls with exactly i matched dice
	total_matched_count:  int, // sum of matched_count across rolls
	total_matched_value:  int, // sum of matched_value across rolls
	// Miss tracking
	ability_misses:       int, // rolls where matched_count < min_matches
	total_miss_dice:      int, // sum of normal dice count on misses (for avg dice on miss)
	// Resolve meter
	total_unmatched:      int, // sum of unmatched dice across rolls
	rolls_since_resolve:  int, // running counter within a game (reset on resolve fire)
	total_rolls_to_resolve: int, // sum of rolls_since_resolve at each resolve fire
	// Ability metadata (copied once from character)
	ability_name:         cstring,
	ability_scaling:      game.Ability_Scaling,
	ability_min_matches:  int,
	resolve_name:         cstring,
}

// Which side won a game
Side :: enum {
	Player,
	Enemy,
	Draw,
}

// --- Per-game stats ---

Game_Stats :: struct {
	winner:       Side,
	turns:        int,
	seed:         u64,
	player_chars: [game.MAX_PARTY_SIZE]Char_Stats,
	enemy_chars:  [game.MAX_PARTY_SIZE]Char_Stats,
	player_count: int,
	enemy_count:  int,
}

// --- Per-roll stats for dice mechanics analysis ---

Roll_Stats :: struct {
	die_type:        game.Die_Type,
	die_count:       int,
	matched_count:   int,
	matched_value:   int,
	unmatched_count: int,
	ability_damage:  int,
	ability_fired:   bool,
	scaling:         game.Ability_Scaling,
}

// --- Aggregated stats across all rounds ---

Aggregate_Stats :: struct {
	rounds:        int,
	player_wins:   int,
	enemy_wins:    int,
	draws:         int,
	total_turns:   int,
	player_totals: [game.MAX_PARTY_SIZE]Char_Totals,
	enemy_totals:  [game.MAX_PARTY_SIZE]Char_Totals,
	player_count:  int,
	enemy_count:   int,
}

Char_Totals :: struct {
	name:                   cstring,
	total_damage_dealt:     int,
	total_damage_taken:     int,
	total_healing_done:     int,
	total_ability_fires:    int,
	total_ability_attempts: int,
	total_resolve_fires:    int,
	total_hp_remaining:     int,
	games_survived:         int,
	// Damage breakdown
	total_skull_damage:     int,
	total_ability_damage:   int, // main ability + resolve combined
	// Match distribution (summed histograms)
	match_histogram:        [game.MAX_CHARACTER_DICE + 1]int,
	total_matched_count:    int,
	total_matched_value:    int,
	// Miss tracking
	total_ability_misses:   int,
	total_miss_dice:        int,
	// Resolve meter
	total_unmatched:        int,
	total_rolls_to_resolve: int, // sum of rolls between resolve fires
	total_resolve_events:   int, // number of resolve fire events (for averaging)
	// Ability metadata
	ability_name:           cstring,
	ability_scaling:        game.Ability_Scaling,
	ability_min_matches:    int,
	resolve_name:           cstring,
}

// --- Dice mechanics aggregation ---

Dice_Aggregate :: struct {
	die_type:           game.Die_Type,
	total_rolls:        int,
	total_matches:      int,
	total_value:        int,
	rolls_with_match:   int,
	total_unmatched:    int,
	total_dmg_match:    int,
	rolls_match_scale:  int,
	total_dmg_value:    int,
	rolls_value_scale:  int,
	total_dmg_hybrid:   int,
	rolls_hybrid_scale: int,
}

// --- Dice count × die type matrix ---

// Bucket key: (die_type, normal_dice_count). die_count 0 is unused.
Dice_Count_Bucket :: struct {
	total_rolls:      int,
	total_matches:    int, // sum of matched_count
	total_value:      int, // sum of matched_value
	rolls_with_match: int, // rolls where matched_count >= 2
	total_unmatched:  int,
	ability_fires:    int,
	total_ability_dmg: int, // sum of ability damage when ability fired
}

// Indexed by [Die_Type][dice_count]. dice_count 1..MAX_CHARACTER_DICE.
Dice_Count_Matrix :: [game.Die_Type][game.MAX_CHARACTER_DICE + 1]Dice_Count_Bucket

aggregate_dice_count :: proc(rolls: ^Roll_Collector) -> Dice_Count_Matrix {
	m: Dice_Count_Matrix
	for i in 0 ..< rolls.count {
		r := &rolls.rolls[i]
		if r.die_count <= 0 || r.die_count > game.MAX_CHARACTER_DICE {
			continue
		}
		b := &m[r.die_type][r.die_count]
		b.total_rolls += 1
		b.total_matches += r.matched_count
		b.total_value += r.matched_value
		b.total_unmatched += r.unmatched_count
		if r.matched_count >= 2 {
			b.rolls_with_match += 1
		}
		if r.ability_fired {
			b.ability_fires += 1
			b.total_ability_dmg += r.ability_damage
		}
	}
	return m
}

MAX_ROLL_STATS :: 100_000

Roll_Collector :: struct {
	rolls: [MAX_ROLL_STATS]Roll_Stats,
	count: int,
}

// --- Snapshot helpers ---

Hp_Snapshot :: struct {
	attacker_hp: int,
	target_hp:   int,
}

snapshot_hp :: proc(attacker, target: ^game.Character) -> Hp_Snapshot {
	snap := Hp_Snapshot{attacker_hp = attacker.stats.hp}
	if target != nil {
		snap.target_hp = target.stats.hp
	}
	return snap
}

// --- Init per-game character metadata ---

// Copy ability metadata from the game character into Char_Stats.
// Called once per game at init time so we have ability names/scaling for output.
init_char_stats_meta :: proc(cs: ^Char_Stats, ch: ^game.Character) {
	cs.name = ch.name
	cs.ability_name = ch.ability.name
	cs.ability_scaling = ch.ability.scaling
	cs.ability_min_matches = ch.ability.min_matches
	cs.resolve_name = ch.resolve_ability.name
}

// --- Stat collection ---

// Collect stats from a single resolve_roll by comparing HP snapshots.
collect_roll_stats :: proc(
	gs: ^Game_Stats,
	is_player: bool,
	char_idx: int,
	attacker, target: ^game.Character,
	snap: Hp_Snapshot,
	rolls: ^Roll_Collector,
) {
	chars := is_player ? &gs.player_chars : &gs.enemy_chars
	cs := &chars[char_idx]
	roll := &attacker.roll

	cs.ability_attempts += 1

	// Damage dealt = how much target HP dropped
	skull_dmg := 0
	if target != nil {
		dmg := snap.target_hp - target.stats.hp
		cs.damage_dealt += dmg

		if roll.skull_count > 0 {
			skull_per_hit := max(attacker.stats.attack - target.stats.defense, 0)
			skull_dmg = skull_per_hit * roll.skull_count
		}
		cs.skull_damage_dealt += skull_dmg
		cs.ability_damage_dealt += max(dmg - skull_dmg, 0)
	}

	// Healing done = how much attacker HP increased
	heal := attacker.stats.hp - snap.attacker_hp
	if heal > 0 {
		cs.healing_done += heal
	}

	// Ability fire/miss tracking
	if attacker.ability_fired {
		cs.ability_fires += 1
	} else {
		// Ability didn't fire — was there a match threshold miss?
		if attacker.ability.min_matches > 0 {
			cs.ability_misses += 1
			cs.total_miss_dice += roll.count - roll.skull_count
		}
	}

	// Resolve tracking
	cs.rolls_since_resolve += 1
	if attacker.resolve_fired {
		cs.resolve_fires += 1
		cs.total_rolls_to_resolve += cs.rolls_since_resolve
		cs.rolls_since_resolve = 0
	}

	// Match distribution
	matched := min(roll.matched_count, game.MAX_CHARACTER_DICE)
	cs.match_histogram[matched] += 1
	cs.total_matched_count += roll.matched_count
	cs.total_matched_value += roll.matched_value

	// Unmatched (for resolve charge rate)
	cs.total_unmatched += roll.unmatched_count

	// Per-roll dice mechanics data
	if rolls != nil && rolls.count < MAX_ROLL_STATS {
		dt, has_type := game.character_assigned_normal_die_type(attacker)
		if has_type {
			ability_dmg := 0
			if target != nil {
				total_dmg := snap.target_hp - target.stats.hp
				ability_dmg = max(total_dmg - skull_dmg, 0)
			}

			rolls.rolls[rolls.count] = Roll_Stats{
				die_type        = dt,
				die_count       = roll.count - roll.skull_count,
				matched_count   = roll.matched_count,
				matched_value   = roll.matched_value,
				unmatched_count = roll.unmatched_count,
				ability_damage  = ability_dmg,
				ability_fired   = attacker.ability_fired,
				scaling         = attacker.ability.scaling,
			}
			rolls.count += 1
		}
	}
}

// Collect damage-taken stats for the target side.
collect_target_damage :: proc(
	gs: ^Game_Stats,
	is_target_player: bool,
	target: ^game.Character,
	target_party: ^game.Party,
	snap: Hp_Snapshot,
) {
	if target == nil {
		return
	}
	dmg := snap.target_hp - target.stats.hp
	if dmg <= 0 {
		return
	}
	for i in 0 ..< target_party.count {
		if &target_party.characters[i] == target {
			chars := is_target_player ? &gs.player_chars : &gs.enemy_chars
			chars[i].damage_taken += dmg
			break
		}
	}
}

// Fill end-of-game stats for all characters in a party.
collect_endgame :: proc(gs: ^Game_Stats, party: ^game.Party, is_player: bool) {
	chars := is_player ? &gs.player_chars : &gs.enemy_chars
	count := is_player ? &gs.player_count : &gs.enemy_count
	count^ = party.count

	for i in 0 ..< party.count {
		ch := &party.characters[i]
		cs := &chars[i]
		cs.name = ch.name
		cs.hp_remaining = ch.stats.hp
		cs.alive = game.character_is_alive(ch)
		dt, has := game.character_assigned_normal_die_type(ch)
		if has {
			cs.die_type_used = dt
		}
	}
}

// --- Aggregation ---

aggregate_add :: proc(agg: ^Aggregate_Stats, gs: ^Game_Stats) {
	agg.rounds += 1
	agg.total_turns += gs.turns

	switch gs.winner {
	case .Player:
		agg.player_wins += 1
	case .Enemy:
		agg.enemy_wins += 1
	case .Draw:
		agg.draws += 1
	}

	agg.player_count = gs.player_count
	agg.enemy_count = gs.enemy_count

	for i in 0 ..< gs.player_count {
		add_char_totals(&agg.player_totals[i], &gs.player_chars[i])
	}
	for i in 0 ..< gs.enemy_count {
		add_char_totals(&agg.enemy_totals[i], &gs.enemy_chars[i])
	}
}

@(private = "file")
add_char_totals :: proc(t: ^Char_Totals, cs: ^Char_Stats) {
	t.name = cs.name
	t.total_damage_dealt += cs.damage_dealt
	t.total_damage_taken += cs.damage_taken
	t.total_healing_done += cs.healing_done
	t.total_ability_fires += cs.ability_fires
	t.total_ability_attempts += cs.ability_attempts
	t.total_resolve_fires += cs.resolve_fires
	if cs.alive {
		t.total_hp_remaining += cs.hp_remaining
		t.games_survived += 1
	}
	// Damage breakdown
	t.total_skull_damage += cs.skull_damage_dealt
	t.total_ability_damage += cs.ability_damage_dealt
	// Match distribution
	for j in 0 ..< len(cs.match_histogram) {
		t.match_histogram[j] += cs.match_histogram[j]
	}
	t.total_matched_count += cs.total_matched_count
	t.total_matched_value += cs.total_matched_value
	// Miss tracking
	t.total_ability_misses += cs.ability_misses
	t.total_miss_dice += cs.total_miss_dice
	// Resolve meter
	t.total_unmatched += cs.total_unmatched
	t.total_rolls_to_resolve += cs.total_rolls_to_resolve
	t.total_resolve_events += cs.resolve_fires
	// Metadata (overwrite each game — they're constant)
	t.ability_name = cs.ability_name
	t.ability_scaling = cs.ability_scaling
	t.ability_min_matches = cs.ability_min_matches
	t.resolve_name = cs.resolve_name
}

// --- Dice mechanics aggregation ---

aggregate_dice :: proc(rolls: ^Roll_Collector) -> [game.Die_Type]Dice_Aggregate {
	aggs: [game.Die_Type]Dice_Aggregate
	for dt in game.Die_Type.D4 ..= game.Die_Type.D12 {
		aggs[dt].die_type = dt
	}

	for i in 0 ..< rolls.count {
		r := &rolls.rolls[i]
		a := &aggs[r.die_type]
		a.total_rolls += 1
		a.total_matches += r.matched_count
		a.total_value += r.matched_value
		a.total_unmatched += r.unmatched_count
		if r.matched_count >= 2 {
			a.rolls_with_match += 1
		}

		if r.ability_fired {
			switch r.scaling {
			case .Match:
				a.total_dmg_match += r.ability_damage
				a.rolls_match_scale += 1
			case .Value:
				a.total_dmg_value += r.ability_damage
				a.rolls_value_scale += 1
			case .Hybrid:
				a.total_dmg_hybrid += r.ability_damage
				a.rolls_hybrid_scale += 1
			case .None:
			// flat damage — not bucketed by die type
			}
		}
	}

	return aggs
}

// --- Output ---

SCALING_NAMES := [game.Ability_Scaling]string {
	.None   = "flat",
	.Match  = "match",
	.Value  = "value",
	.Hybrid = "hybrid",
}

print_summary :: proc(encounter: string, seed: u64, agg: ^Aggregate_Stats, dice_aggs: ^[game.Die_Type]Dice_Aggregate, dcm: ^Dice_Count_Matrix) {
	rounds := agg.rounds
	if rounds == 0 {
		return
	}

	fmt.printfln("Encounter: %s | Rounds: %d | Seed: %d", encounter, rounds, seed)
	fmt.println()
	fmt.println("Results:")
	fmt.printfln("  Player wins: %d (%.1f%%)", agg.player_wins, pct(agg.player_wins, rounds))
	fmt.printfln("  Enemy wins:  %d (%.1f%%)", agg.enemy_wins, pct(agg.enemy_wins, rounds))
	fmt.printfln("  Draws:       %d (%.1f%%)", agg.draws, pct(agg.draws, rounds))
	fmt.printfln("  Avg turns:   %.1f", f64(agg.total_turns) / f64(rounds))

	fmt.println()
	fmt.println("Player Party:")
	print_party_stats(&agg.player_totals, agg.player_count, rounds)

	fmt.println()
	fmt.println("Enemy Party:")
	print_party_stats(&agg.enemy_totals, agg.enemy_count, rounds)

	// Dice mechanics table
	fmt.println()
	fmt.println("Dice Mechanics:")
	fmt.println("  Type | Rolls | Avg[M] | Avg[V] | Match% | DMG(match) | DMG(value) | DMG(hybrid) | Resolve/roll")
	for dt in game.Die_Type.D4 ..= game.Die_Type.D12 {
		a := &dice_aggs[dt]
		if a.total_rolls == 0 {
			continue
		}
		r := f64(a.total_rolls)
		fmt.printfln(
			"  %-4s | %d | %.1f | %.1f | %.1f%% | %.1f | %.1f | %.1f | %.1f",
			game.DIE_TYPE_NAMES[dt],
			a.total_rolls,
			f64(a.total_matches) / r,
			f64(a.total_value) / r,
			pct(a.rolls_with_match, a.total_rolls),
			a.rolls_match_scale > 0 ? f64(a.total_dmg_match) / f64(a.rolls_match_scale) : 0,
			a.rolls_value_scale > 0 ? f64(a.total_dmg_value) / f64(a.rolls_value_scale) : 0,
			a.rolls_hybrid_scale > 0 ? f64(a.total_dmg_hybrid) / f64(a.rolls_hybrid_scale) : 0,
			f64(a.total_unmatched) / r,
		)
	}

	// Dice count × die type matrix
	print_dice_count_matrix(dcm)
}

@(private = "file")
print_dice_count_matrix :: proc(dcm: ^Dice_Count_Matrix) {
	fmt.println()
	fmt.println("Dice Count Breakdown:")
	for dt in game.Die_Type.D4 ..= game.Die_Type.D12 {
		printed_header := false
		for dc in 1 ..= game.MAX_CHARACTER_DICE {
			b := &dcm[dt][dc]
			if b.total_rolls == 0 {
				continue
			}
			if !printed_header {
				fmt.printfln("  %s:", game.DIE_TYPE_NAMES[dt])
				printed_header = true
			}
			r := f64(b.total_rolls)
			avg_dmg: f64 = 0
			if b.ability_fires > 0 {
				avg_dmg = f64(b.total_ability_dmg) / f64(b.ability_fires)
			}
			fmt.printfln(
				"    %d dice: %d rolls, %.1f%% match, avg[M] %.1f, avg[V] %.1f, fire %.1f%%, avg dmg %.1f, %.1f unmatched/roll",
				dc,
				b.total_rolls,
				pct(b.rolls_with_match, b.total_rolls),
				f64(b.total_matches) / r,
				f64(b.total_value) / r,
				pct(b.ability_fires, b.total_rolls),
				avg_dmg,
				f64(b.total_unmatched) / r,
			)
		}
	}
}

@(private = "file")
print_party_stats :: proc(totals: ^[game.MAX_PARTY_SIZE]Char_Totals, count, rounds: int) {
	for i in 0 ..< count {
		t := &totals[i]
		r := f64(rounds)
		fire_rate: f64 = 0
		if t.total_ability_attempts > 0 {
			fire_rate = pct(t.total_ability_fires, t.total_ability_attempts)
		}
		avg_hp: f64 = 0
		if t.games_survived > 0 {
			avg_hp = f64(t.total_hp_remaining) / f64(t.games_survived)
		}

		// Summary line
		fmt.printfln(
			"  %-10s | DMG: %.1f | HEAL: %.1f | Ability: %.1f%% | Resolve: %.1f/game | Survival: %.1f%% | Avg HP: %.1f",
			t.name,
			f64(t.total_damage_dealt) / r,
			f64(t.total_healing_done) / r,
			fire_rate,
			f64(t.total_resolve_fires) / r,
			pct(t.games_survived, rounds),
			avg_hp,
		)

		// Detail block
		print_character_detail(t, rounds)
		fmt.println()
	}
}

@(private = "file")
print_character_detail :: proc(t: ^Char_Totals, rounds: int) {
	r := f64(rounds)
	attempts := t.total_ability_attempts

	// Damage breakdown
	fmt.printfln(
		"    Damage: skull %.1f + ability %.1f",
		f64(t.total_skull_damage) / r,
		f64(t.total_ability_damage) / r,
	)

	// Healing line (only if there was any)
	if t.total_healing_done > 0 {
		fmt.printfln("    Healing: %.1f/game", f64(t.total_healing_done) / r)
	}

	// Ability info with miss rate
	if attempts > 0 {
		miss_rate := pct(t.total_ability_misses, attempts)
		avg_miss_dice: f64 = 0
		if t.total_ability_misses > 0 {
			avg_miss_dice = f64(t.total_miss_dice) / f64(t.total_ability_misses)
		}
		fmt.printfln(
			"    Ability \"%s\" (%s, min %d): fired %.1f%%, missed %.1f%% (avg %.1f dice on miss)",
			t.ability_name,
			SCALING_NAMES[t.ability_scaling],
			t.ability_min_matches,
			pct(t.total_ability_fires, attempts),
			miss_rate,
			avg_miss_dice,
		)
	}

	// Match distribution histogram
	if attempts > 0 {
		fmt.printf("    Matches:")
		for j in 0 ..< len(t.match_histogram) {
			if t.match_histogram[j] > 0 {
				fmt.printf(" %dx=%.0f%%", j, pct(t.match_histogram[j], attempts))
			}
		}
		avg_m: f64 = 0
		avg_v: f64 = 0
		if attempts > 0 {
			avg_m = f64(t.total_matched_count) / f64(attempts)
			avg_v = f64(t.total_matched_value) / f64(attempts)
		}
		fmt.printfln(" | Avg[M]: %.1f | Avg[V]: %.1f", avg_m, avg_v)
	}

	// Resolve meter stats
	if t.total_resolve_fires > 0 || t.total_unmatched > 0 {
		avg_rolls_to_resolve: f64 = 0
		if t.total_resolve_events > 0 {
			avg_rolls_to_resolve = f64(t.total_rolls_to_resolve) / f64(t.total_resolve_events)
		}
		avg_unmatched_per_roll: f64 = 0
		if attempts > 0 {
			avg_unmatched_per_roll = f64(t.total_unmatched) / f64(attempts)
		}
		fmt.printfln(
			"    Resolve \"%s\": %.1f fires/game, avg %.1f rolls to fill, %.1f unmatched/roll",
			t.resolve_name,
			f64(t.total_resolve_fires) / r,
			avg_rolls_to_resolve,
			avg_unmatched_per_roll,
		)
	}
}

@(private = "file")
pct :: proc(num, denom: int) -> f64 {
	if denom == 0 {
		return 0
	}
	return f64(num) * 100.0 / f64(denom)
}

// --- CSV output ---

write_csv :: proc(path: string, all_stats: []Game_Stats, player_count, enemy_count: int) -> bool {
	sb: strings.Builder
	strings.builder_init(&sb, allocator = context.temp_allocator)

	// Header
	strings.write_string(&sb, "round,seed,winner,turns")
	for i in 0 ..< player_count {
		write_char_csv_header(&sb, fmt.tprintf("p%d", i))
	}
	for i in 0 ..< enemy_count {
		write_char_csv_header(&sb, fmt.tprintf("e%d", i))
	}
	strings.write_byte(&sb, '\n')

	// Rows
	for &gs, round in all_stats {
		winner_str: string
		switch gs.winner {
		case .Player:
			winner_str = "player"
		case .Enemy:
			winner_str = "enemy"
		case .Draw:
			winner_str = "draw"
		}
		fmt.sbprintf(&sb, "%d,%d,%s,%d", round + 1, gs.seed, winner_str, gs.turns)

		for i in 0 ..< player_count {
			write_char_csv_row(&sb, &gs.player_chars[i])
		}
		for i in 0 ..< enemy_count {
			write_char_csv_row(&sb, &gs.enemy_chars[i])
		}
		strings.write_byte(&sb, '\n')
	}

	return os.write_entire_file(path, sb.buf[:])
}

@(private = "file")
write_char_csv_header :: proc(sb: ^strings.Builder, prefix: string) {
	fmt.sbprintf(sb, ",%s_name,%s_dmg,%s_heal,%s_ability,%s_resolve,%s_hp,%s_alive", prefix, prefix, prefix, prefix, prefix, prefix, prefix)
}

@(private = "file")
write_char_csv_row :: proc(sb: ^strings.Builder, cs: ^Char_Stats) {
	fmt.sbprintf(sb, ",%s,%d,%d,%d,%d,%d,%s", cs.name, cs.damage_dealt, cs.healing_done, cs.ability_fires, cs.resolve_fires, cs.hp_remaining, cs.alive ? "yes" : "no")
}

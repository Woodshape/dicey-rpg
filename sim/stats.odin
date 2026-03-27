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
	ability_damage_dealt: int,
	hp_remaining:         int,
	alive:                bool,
	die_type_used:        game.Die_Type,
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
	die_type:       game.Die_Type,
	die_count:      int,
	matched_count:  int,
	matched_value:  int,
	unmatched_count: int,
	ability_damage: int,
	ability_fired:  bool,
	scaling:        game.Ability_Scaling,
}

// --- Aggregated stats across all rounds ---

Aggregate_Stats :: struct {
	rounds:             int,
	player_wins:        int,
	enemy_wins:         int,
	draws:              int,
	total_turns:        int,
	// Per-character totals (indexed by party position)
	player_totals:      [game.MAX_PARTY_SIZE]Char_Totals,
	enemy_totals:       [game.MAX_PARTY_SIZE]Char_Totals,
	player_count:       int,
	enemy_count:        int,
}

Char_Totals :: struct {
	name:                 cstring,
	total_damage_dealt:   int,
	total_damage_taken:   int,
	total_healing_done:   int,
	total_ability_fires:  int,
	total_ability_attempts: int,
	total_resolve_fires:  int,
	total_hp_remaining:   int, // sum of HP when alive at game end
	games_survived:       int,
}

// --- Dice mechanics aggregation ---

Dice_Aggregate :: struct {
	die_type:           game.Die_Type,
	total_rolls:        int,
	total_matches:      int,
	total_value:        int,
	rolls_with_match:   int,
	total_unmatched:    int,
	// Damage by scaling type
	total_dmg_match:    int,
	rolls_match_scale:  int,
	total_dmg_value:    int,
	rolls_value_scale:  int,
	total_dmg_hybrid:   int,
	rolls_hybrid_scale: int,
}

MAX_ROLL_STATS :: 100_000

Roll_Collector :: struct {
	rolls: [MAX_ROLL_STATS]Roll_Stats,
	count: int,
}

// --- Snapshot helpers ---

// Snapshot a character's HP before resolve_roll so we can compute deltas.
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

// Collect stats from a single resolve_roll by comparing snapshots.
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

	cs.ability_attempts += 1

	// Damage dealt = how much target HP dropped
	if target != nil {
		dmg := snap.target_hp - target.stats.hp
		cs.damage_dealt += dmg

		// Skull damage: count from roll
		skull_dmg := 0
		if attacker.roll.skull_count > 0 {
			skull_per_hit := max(attacker.stats.attack - target.stats.defense, 0)
			skull_dmg = skull_per_hit * attacker.roll.skull_count
		}
		cs.skull_damage_dealt += skull_dmg
		cs.ability_damage_dealt += max(dmg - skull_dmg, 0)
	}

	// Healing done = how much attacker HP increased
	heal := attacker.stats.hp - snap.attacker_hp
	if heal > 0 {
		cs.healing_done += heal
	}

	if attacker.ability_fired {
		cs.ability_fires += 1
	}
	if attacker.resolve_fired {
		cs.resolve_fires += 1
	}

	// Collect per-roll dice mechanics data
	if rolls != nil && rolls.count < MAX_ROLL_STATS {
		roll := &attacker.roll
		dt, has_type := game.character_assigned_normal_die_type(attacker)
		if has_type {
			ability_dmg := 0
			if target != nil {
				skull_dmg := 0
				if roll.skull_count > 0 {
					skull_per_hit := max(attacker.stats.attack - target.stats.defense, 0)
					skull_dmg = skull_per_hit * roll.skull_count
				}
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
	// Find which index this character is in their party
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

print_summary :: proc(encounter: string, seed: u64, agg: ^Aggregate_Stats, dice_aggs: ^[game.Die_Type]Dice_Aggregate) {
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
	fmt.println("  Die Type | Rolls | Avg [M] | Avg [V] | Match% | DMG(match) | DMG(value) | DMG(hybrid) | Resolve/roll")
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

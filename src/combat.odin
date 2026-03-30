package game

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

// Top-level update dispatcher. Routes to the appropriate phase handler.
combat_update :: proc(gs: ^Game_State, input: Input_State) {
	// Handle character inspect toggle before any phase logic.
	// Works in all non-game-over phases. Any left-click closes the view;
	// clicking a character header opens it.
	if gs.turn != .Victory && gs.turn != .Defeat {
		if input.left_pressed {
			if gs.inspect_active {
				gs.inspect_active = false
				return
			}

			ci := mouse_on_party_header(&gs.player_party, CHAR_PANEL_X, input.mouse_x, input.mouse_y)
			if ci >= 0 {
				gs.inspect_active = true
				gs.inspect_party_enemy = false
				gs.inspect_char_index = ci
				gs.drag = {}
				return
			}

			ci = mouse_on_party_header(&gs.enemy_party, ENEMY_PANEL_X, input.mouse_x, input.mouse_y)
			if ci >= 0 {
				gs.inspect_active = true
				gs.inspect_party_enemy = true
				gs.inspect_char_index = ci
				gs.drag = {}
				return
			}
		}
	}

	prev_turn := gs.turn

	#partial switch gs.turn {
	case .Draft_Player_Pick:
		draft_player_pick_update(gs, input)
	case .Draft_Enemy_Pick:
		draft_enemy_pick_update(gs)
	case .Combat_Player_Turn:
		combat_player_turn_update(gs, input)
	case .Player_Roll_Result:
		player_roll_result_update(gs, input)
	case .Combat_Enemy_Turn:
		combat_enemy_turn_update(gs)
	case .Enemy_Roll_Result:
		enemy_roll_result_update(gs, input)
	case .Round_End:
		round_end_update(gs)
	case .Victory, .Defeat:
		game_over_update(gs, input)
	}

	// Tick turn-based conditions once when a side's combat turn begins
	if gs.turn != prev_turn {
		if gs.turn == .Combat_Player_Turn && prev_turn != .Player_Roll_Result {
			// Tick player conditions at the start of the combat phase (not between rolls)
			tick_party_conditions(&gs.player_party, &gs.log)
		} else if gs.turn == .Combat_Enemy_Turn && prev_turn != .Enemy_Roll_Result {
			// Tick enemy conditions at the start of the combat phase (not between rolls)
			tick_party_conditions(&gs.enemy_party, &gs.log)
		}
	}
}

// --- Targeting ---

// Check if all characters in a party are dead.
party_all_dead :: proc(party: ^Party) -> bool {
	for i in 0 ..< party.count {
		if character_is_alive(&party.characters[i]) {
			return false
		}
	}
	return true
}

// Get the target for an attacker at the given index.
// Prefers the facing opponent (same index). Falls back to first alive enemy.
// Returns nil if all enemies are dead.
get_target :: proc(enemy_party: ^Party, attacker_index: int) -> ^Character {
	// Try facing opponent first
	if attacker_index < enemy_party.count &&
	   character_is_alive(&enemy_party.characters[attacker_index]) {
		return &enemy_party.characters[attacker_index]
	}
	// Fallback to first alive
	for i in 0 ..< enemy_party.count {
		if character_is_alive(&enemy_party.characters[i]) {
			return &enemy_party.characters[i]
		}
	}
	return nil
}

// --- Win/Lose ---

// Check if either side is fully dead. Returns the appropriate next phase,
// or the given default_next if both sides have living characters.
check_win_lose :: proc(gs: ^Game_State, default_next: Turn_Phase) -> Turn_Phase {
	if party_all_dead(&gs.enemy_party) {
		return .Victory
	}
	if party_all_dead(&gs.player_party) {
		return .Defeat
	}
	return default_next
}

// --- Roll Resolution (with logging) ---

// --- Passive trigger helpers ---

// Fire On_Roll passives for the attacker. Called at the start of resolve_roll.
// The passive effect proc is responsible for setting owner.passive_fired = true
// only when it actually does something (not when it returns early).
fire_on_roll_passive :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character) {
	attacker.passive_fired = false
	if attacker.passive.trigger != .On_Roll || attacker.passive.effect == nil {return}
	attacker.passive.effect(gs, attacker, target, &attacker.roll)
}

// Notify On_Ally_Damaged passives for all alive allies of the damaged character.
// Called after any damage is applied to a character (skull, ability, resolve).
notify_ally_damaged :: proc(gs: ^Game_State, damaged: ^Character) {
	if damaged == nil {return}
	party := attacker_party(gs, damaged)
	if party == nil {return}
	for i in 0 ..< party.count {
		ally := &party.characters[i]
		if ally == damaged {continue}
		if !character_is_alive(ally) {continue}
		if ally.passive.trigger != .On_Ally_Damaged || ally.passive.effect == nil {continue}
		ally.passive.effect(gs, ally, damaged, nil)
	}
}

// Resolve a character's roll: skull damage, abilities, resolve meter.
// Logs everything to the combat log.
resolve_roll :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character) {
	roll := &attacker.roll
	atag := find_char_tag(gs, attacker)
	ttag := find_char_tag(gs, target)

	// Log rolled values for auditability
	log_rolled_values(gs, attacker, roll)
	trace_values(&gs.trace, atag, attacker)
	trace_match(&gs.trace, atag, attacker)

	// Fire On_Roll passives first (e.g. Iron Skin applies DEF before any damage)
	passive_attacker_hp := attacker.stats.hp
	passive_target_hp := target != nil ? target.stats.hp : 0
	fire_on_roll_passive(gs, attacker, target)
	if attacker.passive_fired {
		trace_passive(&gs.trace, atag, attacker)
		if attacker.stats.hp != passive_attacker_hp { trace_hp(&gs.trace, atag, attacker) }
		if target != nil && target.stats.hp != passive_target_hp { trace_hp(&gs.trace, ttag, target) }
	}

	// Skull damage
	if roll.skull_count > 0 && target != nil {
		hp_before := target.stats.hp
		dmg := apply_skull_damage(attacker, target)
		absorbed := hp_before - target.stats.hp - dmg  // negative = shield absorbed
		if dmg > 0 || absorbed < 0 {
			// Compute actual absorption: raw hits minus what HP actually lost
			raw_per_hit := max(attacker.stats.attack - character_effective_defense(target), 0)
			raw_total := raw_per_hit * roll.skull_count
			shield_absorbed := raw_total - dmg
			if shield_absorbed > 0 {
				combat_log_add(
					&gs.log,
					rl.Color{200, 60, 60, 255},
					"%s: Skull x%d -> %d dmg to %s (-%d shield) [HP %d]",
					attacker.name, roll.skull_count, dmg, target.name,
					shield_absorbed, target.stats.hp,
				)
			} else {
				combat_log_add(
					&gs.log,
					rl.Color{200, 60, 60, 255},
					"%s: Skull x%d -> %d dmg to %s [HP %d]",
					attacker.name, roll.skull_count, dmg, target.name,
					target.stats.hp,
				)
			}
		}
		// Notify On_Ally_Damaged passives after skull damage
		if target.stats.hp < hp_before {
			notify_ally_damaged(gs, target)
		}
		if roll.skull_count > 0 && target != nil && dmg > 0 {
			trace_skull(&gs.trace, atag, attacker, ttag, target, roll.skull_count, dmg)
			trace_hp(&gs.trace, ttag, target)
		}
	}

	// Snapshot resolve and target HP before ability resolution
	resolve_before := attacker.resolve
	attacker_hp_before := attacker.stats.hp
	target_hp_before := target != nil ? target.stats.hp : 0

	// --- Main ability ---
	if roll.matched_count >= attacker.ability.min_matches && attacker.ability.effect != nil {
		ability_target_hp_before := target != nil ? target.stats.hp : 0
		ability_attacker_hp_before := attacker.stats.hp
		attacker.ability.effect(gs, attacker, target, roll)
		attacker.ability_fired = true
		ability_dmg  := target != nil ? ability_target_hp_before - target.stats.hp : 0
		ability_heal := attacker.stats.hp - ability_attacker_hp_before
		trace_ability(&gs.trace, atag, attacker, ttag, target, ability_dmg, ability_heal)
		if target != nil && ability_dmg > 0 { trace_hp(&gs.trace, ttag, target) }
		if ability_heal > 0 { trace_hp(&gs.trace, atag, attacker) }
	} else {
		attacker.ability_fired = false
	}

	// --- Charge resolve from unmatched dice ---
	attacker.resolve += roll.unmatched_count
	if roll.unmatched_count > 0 {
		trace_charge(&gs.trace, atag, attacker, roll.unmatched_count)
	}

	// --- Resolve ability ---
	if attacker.resolve >= attacker.resolve_max && attacker.resolve_ability.effect != nil {
		resolve_target_hp_before := target != nil ? target.stats.hp : 0
		resolve_attacker_hp_before := attacker.stats.hp
		attacker.resolve_ability.effect(gs, attacker, target, roll)
		attacker.resolve_fired = true
		attacker.resolve = 0
		resolve_dmg  := target != nil ? resolve_target_hp_before - target.stats.hp : 0
		resolve_heal := attacker.stats.hp - resolve_attacker_hp_before
		trace_resolve_ability(&gs.trace, atag, attacker, ttag, target, resolve_dmg, resolve_heal)
		if target != nil && resolve_dmg > 0 { trace_hp(&gs.trace, ttag, target) }
		if resolve_heal > 0 { trace_hp(&gs.trace, atag, attacker) }
	} else {
		attacker.resolve_fired = false
	}

	// Notify On_Ally_Damaged passives after ability/resolve damage
	if target != nil && target.stats.hp < target_hp_before {
		notify_ally_damaged(gs, target)
	}

	// Log match info
	if roll.matched_count > 0 {
		combat_log_add(
			&gs.log,
			rl.Color{220, 200, 60, 255},
			"%s: Matched %d x %d",
			attacker.name,
			roll.matched_count,
			roll.matched_value,
		)
	} else if roll.skull_count == 0 {
		combat_log_add(&gs.log, rl.Color{180, 80, 80, 255}, "%s: No match", attacker.name)
	}

	// Pre-format display strings into roll — used by both the log and the draw layer.
	if attacker.ability_fired && attacker.ability.describe != nil {
		s := fmt.bprintf(
			roll.ability_desc[:],
			"%s",
			attacker.ability.describe(gs, attacker, target, roll),
		)
		if len(s) < MAX_LOG_LENGTH {roll.ability_desc[len(s)] = 0}
	}
	if attacker.resolve_fired && attacker.resolve_ability.describe != nil {
		s := fmt.bprintf(
			roll.resolve_desc[:],
			"%s",
			attacker.resolve_ability.describe(gs, attacker, target, roll),
		)
		if len(s) < MAX_LOG_LENGTH {roll.resolve_desc[len(s)] = 0}
	}

	// Log ability with HP result
	if attacker.ability_fired && target != nil {
		desc: cstring = attacker.ability.name
		if roll.ability_desc[0] != 0 {
			desc = cstring(raw_data(roll.ability_desc[:]))
		}
		// Detect if ability healed the attacker or damaged the target
		if attacker.stats.hp > attacker_hp_before {
			combat_log_add(
				&gs.log,
				rl.Color{100, 200, 255, 255},
				"%s: %s (%s) [HP %d]",
				attacker.name, attacker.ability.name, desc,
				attacker.stats.hp,
			)
		} else {
			combat_log_add(
				&gs.log,
				rl.Color{100, 200, 255, 255},
				"%s: %s (%s) -> %s [HP %d]",
				attacker.name, attacker.ability.name, desc, target.name,
				target.stats.hp,
			)
		}
	}

	// Log resolve meter (using pre-resolution value + charge)
	if roll.unmatched_count > 0 {
		charged_to := resolve_before + roll.unmatched_count
		combat_log_add(
			&gs.log,
			rl.Color{150, 120, 220, 255},
			"%s: Resolve +%d (%d/%d)",
			attacker.name,
			roll.unmatched_count,
			charged_to,
			attacker.resolve_max,
		)
	}

	// Log resolve ability with target and HP
	if attacker.resolve_fired {
		desc: cstring = attacker.resolve_ability.name
		if roll.resolve_desc[0] != 0 {
			desc = cstring(raw_data(roll.resolve_desc[:]))
		}
		if target != nil {
			combat_log_add(
				&gs.log,
				rl.Color{255, 200, 50, 255},
				"%s: RESOLVE %s (%s) -> %s [HP %d]",
				attacker.name,
				attacker.resolve_ability.name,
				desc,
				target.name,
				target.stats.hp,
			)
		} else {
			combat_log_add(
				&gs.log,
				rl.Color{255, 200, 50, 255},
				"%s: RESOLVE %s (%s)",
				attacker.name,
				attacker.resolve_ability.name,
				desc,
			)
		}
	}

	// Log passive if it fired
	if attacker.passive_fired {
		combat_log_add(
			&gs.log,
			rl.Color{160, 200, 160, 255},
			"%s: %s",
			attacker.name,
			attacker.passive.name,
		)
	}

	// Mark dead and log
	if target != nil && target.stats.hp <= 0 && target.state == .Alive {
		target.state = .Dead
		combat_log_add(&gs.log, rl.Color{255, 60, 60, 255}, "%s is defeated!", target.name)
		trace_hp(&gs.trace, ttag, target)
		trace_dead(&gs.trace, ttag, target)
	}
}

// Log the actual dice values rolled with die type (e.g., "Warrior rolls 3d12 [3, 12, Skl]")
log_rolled_values :: proc(gs: ^Game_State, attacker: ^Character, roll: ^Roll_Result) {
	// Determine die type from assigned dice (still on character at this point)
	die_type_name: cstring = "?"
	normal_count := 0
	for i in 0 ..< attacker.assigned_count {
		if die_type_is_normal(attacker.assigned[i]) {
			die_type_name = DIE_TYPE_NAMES[attacker.assigned[i]]
			normal_count += 1
		}
	}

	// Build a compact string of rolled values
	buf: [64]u8
	pos := 0

	for i in 0 ..< roll.count {
		if i > 0 {
			buf[pos] = ','; pos += 1
			buf[pos] = ' '; pos += 1
		}
		if roll.skulls[i] == 1 {
			buf[pos] = 'S'; pos += 1
			buf[pos] = 'k'; pos += 1
			buf[pos] = 'l'; pos += 1
		} else {
			v := roll.values[i]
			if v >= 10 {
				buf[pos] = '0' + u8(v / 10); pos += 1
			}
			buf[pos] = '0' + u8(v % 10); pos += 1
		}
	}
	buf[pos] = 0

	if roll.skull_count > 0 && normal_count > 0 {
		combat_log_add(
			&gs.log,
			rl.Color{140, 140, 160, 255},
			"%s rolls %d%s+%dSkl [%s]",
			attacker.name, normal_count, die_type_name,
			roll.skull_count, cstring(raw_data(buf[:])),
		)
	} else if roll.skull_count > 0 {
		combat_log_add(
			&gs.log,
			rl.Color{140, 140, 160, 255},
			"%s rolls %dSkl [%s]",
			attacker.name, roll.skull_count, cstring(raw_data(buf[:])),
		)
	} else {
		combat_log_add(
			&gs.log,
			rl.Color{140, 140, 160, 255},
			"%s rolls %d%s [%s]",
			attacker.name, normal_count, die_type_name,
			cstring(raw_data(buf[:])),
		)
	}
}

// --- Condition Ticking ---

// Tick turn-based conditions for all characters in a party.
// Called once when a side's turn begins (at phase transition, not per-frame).
// Logs condition expiries to the combat log when log is provided.
tick_party_conditions :: proc(party: ^Party, log: ^Combat_Log = nil) {
	for ci in 0 ..< party.count {
		ch := &party.characters[ci]
		if log == nil {
			condition_tick_turns(ch)
			continue
		}
		// Snapshot conditions before ticking to detect expiries
		old_kinds: [MAX_CONDITIONS]Condition_Kind
		old_count := ch.condition_count
		for i in 0 ..< old_count {
			old_kinds[i] = ch.conditions[i].kind
		}

		condition_tick_turns(ch)

		// Log any conditions that were removed
		for i in 0 ..< old_count {
			kind := old_kinds[i]
			if kind == .None { continue }
			if !condition_has(ch, kind) {
				combat_log_add(
					log,
					rl.Color{160, 140, 100, 255},
					"%s: %s expired",
					ch.name,
					CONDITION_NAMES[kind],
				)
			}
		}
	}
}

// --- Draft Phase ---

// Player picks one die from the pool. Free assign/discard also available.
draft_player_pick_update :: proc(gs: ^Game_State, input: Input_State) {
	if gs.inspect_active {
		return
	}

	// Right-click on a hand die to discard it (free action)
	if input.right_pressed {
		slot := mouse_to_hand_slot(input.mouse_x, input.mouse_y)
		if slot >= 0 && slot < gs.hand.count && hand_can_discard(&gs.hand, slot) {
			die_type := gs.hand.dice[slot]
			trace_discard(&gs.trace, "p", slot, die_type)
			hand_discard(&gs.hand, slot)
			combat_log_write(&gs.log, "You discard %s", DIE_TYPE_NAMES[die_type])
		}
	}

	if input.left_pressed {
		// Try to start a drag (pool, hand, or character)
		try_start_drag(gs, input.mouse_x, input.mouse_y)
	}

	if input.left_released && gs.drag.active {
		pick_used := try_drop(gs, input.mouse_x, input.mouse_y)
		gs.drag = {}
		if pick_used {
			// Advance to enemy pick, or combat phase if pool empty
			if pool_is_empty(&gs.pool) {
				gs.turn = .Combat_Player_Turn
			} else {
				gs.turn = .Draft_Enemy_Pick
			}
		}
	}
}

// AI picks one die from the pool.
draft_enemy_pick_update :: proc(gs: ^Game_State) {
	ai_draft_pick(gs)
}

// --- Combat Phase ---

// Player assigns freely and rolls characters one at a time.
// When no characters have dice left, auto-advances to enemy combat turn.
combat_player_turn_update :: proc(gs: ^Game_State, input: Input_State) {
	if gs.inspect_active {
		return
	}

	// Auto-advance: if no alive player character has assigned dice, enemy's turn
	if !party_has_assigned_dice(&gs.player_party) {
		gs.turn = .Combat_Enemy_Turn
		return
	}

	// Right-click on a hand die to discard it (free action)
	if input.right_pressed {
		slot := mouse_to_hand_slot(input.mouse_x, input.mouse_y)
		if slot >= 0 && slot < gs.hand.count && hand_can_discard(&gs.hand, slot) {
			die_type := gs.hand.dice[slot]
			trace_discard(&gs.trace, "p", slot, die_type)
			hand_discard(&gs.hand, slot)
			combat_log_write(&gs.log, "You discard %s", DIE_TYPE_NAMES[die_type])
		}
	}

	if input.left_pressed {
		// Check roll button for any player character
		roll_ci := mouse_on_party_roll_button(&gs.player_party, CHAR_PANEL_X, input.mouse_x, input.mouse_y)
		if roll_ci >= 0 {
			attacker := &gs.player_party.characters[roll_ci]
			trace_roll(&gs.trace, "p", roll_ci, attacker)
			target := get_target(&gs.enemy_party, roll_ci)
			character_roll(attacker)
			resolve_roll(gs, attacker, target)
			gs.rolling_index = roll_ci
			gs.turn = .Player_Roll_Result
			return
		}

		// Done button — skip remaining rolls, advance to enemy
		if mouse_on_done_button(input.mouse_x, input.mouse_y) {
			trace_done(&gs.trace, "p")
			gs.turn = .Combat_Enemy_Turn
			return
		}

		// Try to start a drag (hand or character — no pool during combat)
		try_start_drag(gs, input.mouse_x, input.mouse_y)
	}

	if input.left_released && gs.drag.active {
		try_drop(gs, input.mouse_x, input.mouse_y)
		gs.drag = {}
	}
}

// --- Player Roll Result ---

PLAYER_ROLL_DISPLAY_TIME :: 1.5 // seconds to show player roll results

player_roll_result_update :: proc(gs: ^Game_State, input: Input_State) {
	gs.turn_timer += input.delta_time
	if gs.turn_timer >= PLAYER_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.player_party.characters[gs.rolling_index])
		gs.turn_timer = 0
		// Back to player combat turn to roll more characters or auto-advance
		gs.turn = check_win_lose(gs, .Combat_Player_Turn)
	}
}

// --- Enemy Combat Turn ---

combat_enemy_turn_update :: proc(gs: ^Game_State) {
	ai_combat_turn(gs)
}

// --- Enemy Roll Result ---

ENEMY_ROLL_DISPLAY_TIME :: 1.5 // seconds to show enemy roll results

enemy_roll_result_update :: proc(gs: ^Game_State, input: Input_State) {
	gs.turn_timer += input.delta_time
	if gs.turn_timer >= ENEMY_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.enemy_party.characters[gs.rolling_index])
		gs.turn_timer = 0
		// Back to enemy combat turn to roll more characters or auto-advance
		gs.turn = check_win_lose(gs, .Combat_Enemy_Turn)
	}
}

// --- Round End ---

round_end_update :: proc(gs: ^Game_State) {
	// Check win/lose before starting next round
	next := check_win_lose(gs, .Draft_Player_Pick)
	if next == .Victory || next == .Defeat {
		gs.turn = next
		return
	}

	// Clear per-round has_acted flag for all characters
	for i in 0 ..< gs.player_party.count {
		gs.player_party.characters[i].has_acted = false
	}
	for i in 0 ..< gs.enemy_party.count {
		gs.enemy_party.characters[i].has_acted = false
	}

	// Advance round state and generate new pool
	round_state_advance(&gs.round)
	gs.pool = pool_generate(&gs.round)
	trace_round(&gs.trace, gs.round.round_number)
	combat_log_add(&gs.log, rl.Color{180, 180, 100, 255}, "--- Round %d ---", gs.round.round_number)

	// Alternate first pick
	if gs.round.first_pick {
		gs.turn = .Draft_Player_Pick
	} else {
		gs.turn = .Draft_Enemy_Pick
	}
}

// --- Game Over ---

game_over_update :: proc(gs: ^Game_State, input: Input_State) {
	if input.left_pressed {
		if mouse_on_play_again(input.mouse_x, input.mouse_y) {
			new_seed := u64(time.time_to_unix(time.now()))
			rand.reset(new_seed)
			new_gs, ok := game_init("tutorial", &gs.log, seed = new_seed)
			if ok {
				gs^ = new_gs
			}
			// On failure: error already logged, stay on game-over screen
		}
	}
}

// --- Helpers ---

// Check if any alive character in the party has assigned dice.
party_has_assigned_dice :: proc(party: ^Party) -> bool {
	for i in 0 ..< party.count {
		ch := &party.characters[i]
		if character_is_alive(ch) && ch.assigned_count > 0 {
			return true
		}
	}
	return false
}

// Action validation
can_pick :: proc(pool: ^Draft_Pool, hand: ^Hand) -> bool {
	return !hand_is_full(hand) && !pool_is_empty(pool)
}

can_roll :: proc(character: ^Character) -> bool {
	return character.assigned_count > 0 && !character.has_acted
}

// Done button — lets the player skip remaining rolls during combat phase
DONE_BUTTON_WIDTH  :: 80
DONE_BUTTON_HEIGHT :: 28

done_button_rect :: proc() -> rl.Rectangle {
	return rl.Rectangle {
		x      = f32(WINDOW_WIDTH / 2 - DONE_BUTTON_WIDTH / 2),
		y      = f32(WINDOW_HEIGHT / 2 + 80),
		width  = DONE_BUTTON_WIDTH,
		height = DONE_BUTTON_HEIGHT,
	}
}

mouse_on_done_button :: proc(mouse_x, mouse_y: i32) -> bool {
	r := done_button_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

package game

import "core:fmt"
import rl "vendor:raylib"

// Top-level update dispatcher. Routes to the appropriate phase handler.
combat_update :: proc(gs: ^Game_State) {
	// Handle character inspect toggle before any phase logic.
	// Works in all non-game-over phases. Any left-click closes the view;
	// clicking a character header opens it.
	if gs.turn != .Victory && gs.turn != .Defeat {
		if rl.IsMouseButtonPressed(.LEFT) {
			mouse_x := rl.GetMouseX()
			mouse_y := rl.GetMouseY()

			if gs.inspect_active {
				gs.inspect_active = false
				return
			}

			ci := mouse_on_party_header(&gs.player_party, CHAR_PANEL_X, mouse_x, mouse_y)
			if ci >= 0 {
				gs.inspect_active = true
				gs.inspect_party_enemy = false
				gs.inspect_char_index = ci
				gs.drag = {}
				return
			}

			ci = mouse_on_party_header(&gs.enemy_party, ENEMY_PANEL_X, mouse_x, mouse_y)
			if ci >= 0 {
				gs.inspect_active = true
				gs.inspect_party_enemy = true
				gs.inspect_char_index = ci
				gs.drag = {}
				return
			}
		}
	}

	#partial switch gs.turn {
	case .Player_Turn:
		player_turn_update(gs)
	case .Player_Roll_Result:
		player_roll_result_update(gs)
	case .Enemy_Turn:
		enemy_turn_update(gs)
	case .Enemy_Roll_Result:
		enemy_roll_result_update(gs)
	case .Victory, .Defeat:
		game_over_update(gs)
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
	if attacker_index < enemy_party.count && character_is_alive(&enemy_party.characters[attacker_index]) {
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

// Resolve a character's roll: skull damage, abilities, resolve meter.
// Logs everything to the combat log.
resolve_roll :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character) {
	roll := &attacker.roll

	// Skull damage
	if roll.skull_count > 0 && target != nil {
		dmg := apply_skull_damage(attacker, target)
		combat_log_add(
			&gs.log,
			rl.Color{200, 60, 60, 255},
			"%s: Skull x%d -> %d dmg to %s",
			attacker.name,
			roll.skull_count,
			dmg,
			target.name,
		)
	}

	// Snapshot resolve before resolution (it may reset)
	resolve_before := attacker.resolve

	// Ability + resolve
	if target != nil {
		resolve_abilities(gs, attacker, target)
	}

	// Log match info first
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
	// Called once here with full context; draw procs read from the buffer, no gs needed.
	if attacker.ability_fired && attacker.ability.describe != nil {
		s := fmt.bprintf(roll.ability_desc[:], "%s", attacker.ability.describe(gs, attacker, target, roll))
		if len(s) < MAX_LOG_LENGTH { roll.ability_desc[len(s)] = 0 }
	}
	if attacker.resolve_fired && attacker.resolve_ability.describe != nil {
		s := fmt.bprintf(roll.resolve_desc[:], "%s", attacker.resolve_ability.describe(gs, attacker, target, roll))
		if len(s) < MAX_LOG_LENGTH { roll.resolve_desc[len(s)] = 0 }
	}

	// Log ability
	if attacker.ability_fired && target != nil {
		desc: cstring = attacker.ability.name
		if roll.ability_desc[0] != 0 {
			desc = cstring(raw_data(roll.ability_desc[:]))
		}
		combat_log_add(
			&gs.log,
			rl.Color{100, 200, 255, 255},
			"%s: %s (%s) -> %s",
			attacker.name,
			attacker.ability.name,
			desc,
			target.name,
		)
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

	// Log resolve ability
	if attacker.resolve_fired {
		desc: cstring = attacker.resolve_ability.name
		if roll.resolve_desc[0] != 0 {
			desc = cstring(raw_data(roll.resolve_desc[:]))
		}
		combat_log_add(
			&gs.log,
			rl.Color{255, 200, 50, 255},
			"%s: RESOLVE %s -> %s",
			attacker.name,
			attacker.resolve_ability.name,
			desc,
		)
	}

	// Mark dead and log
	if target != nil && target.stats.hp <= 0 && target.state == .Alive {
		target.state = .Dead
		combat_log_add(&gs.log, rl.Color{255, 60, 60, 255}, "%s is defeated!", target.name)
	}
}

// --- Board Refill ---

// Refill the board if no pickable dice remain.
// This covers both an empty board and a board with only inaccessible inner tiles.
check_board_refill :: proc(gs: ^Game_State) {
	if !board_has_pickable(&gs.board) {
		gs.board = board_init()
		combat_log_add(&gs.log, rl.Color{180, 180, 100, 255}, "Board refilled")
	}
}

// --- Player Turn ---

player_turn_update :: proc(gs: ^Game_State) {
	check_board_refill(gs)

	// Block all player input while inspect overlay is open
	if gs.inspect_active {
		return
	}

	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	// Right-click on a hand die to discard it (free action)
	if rl.IsMouseButtonPressed(.RIGHT) {
		slot := mouse_to_hand_slot(mouse_x, mouse_y)
		if slot >= 0 && slot < gs.hand.count && hand_can_discard(&gs.hand, slot) {
			die_type := gs.hand.dice[slot]
			hand_discard(&gs.hand, slot)
			combat_log_write(&gs.log, "You discard %s", DIE_TYPE_NAMES[die_type])
		}
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		// Check roll button for any player character
		roll_ci := mouse_on_party_roll_button(&gs.player_party, CHAR_PANEL_X, mouse_x, mouse_y)
		if roll_ci >= 0 {
			attacker := &gs.player_party.characters[roll_ci]
			target := get_target(&gs.enemy_party, roll_ci)
			character_roll(attacker)
			resolve_roll(gs, attacker, target)
			gs.rolling_index = roll_ci
			gs.turn = .Player_Roll_Result
			return
		}

		// Try to start a drag
		try_start_drag(gs, mouse_x, mouse_y)
	}

	if rl.IsMouseButtonReleased(.LEFT) && gs.drag.active {
		action_used := try_drop(gs, mouse_x, mouse_y)
		gs.drag = {}
		if action_used {
			gs.turn = .Enemy_Turn
		}
	}
}

// --- Player Roll Result ---

PLAYER_ROLL_DISPLAY_TIME :: 1.5 // seconds to show player roll results

player_roll_result_update :: proc(gs: ^Game_State) {
	gs.turn_timer += rl.GetFrameTime()
	if gs.turn_timer >= PLAYER_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.player_party.characters[gs.rolling_index])
		gs.turn_timer = 0
		gs.turn = check_win_lose(gs, .Enemy_Turn)
	}
}

// --- Enemy Turn ---

enemy_turn_update :: proc(gs: ^Game_State) {
	check_board_refill(gs)
	ai_take_turn(gs)
}

// --- Enemy Roll Result ---

ENEMY_ROLL_DISPLAY_TIME :: 1.5 // seconds to show enemy roll results

enemy_roll_result_update :: proc(gs: ^Game_State) {
	gs.turn_timer += rl.GetFrameTime()
	if gs.turn_timer >= ENEMY_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.enemy_party.characters[gs.rolling_index])
		gs.turn_timer = 0
		gs.turn = check_win_lose(gs, .Player_Turn)
	}
}

// --- Game Over ---

game_over_update :: proc(gs: ^Game_State) {
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_x := rl.GetMouseX()
		mouse_y := rl.GetMouseY()
		if mouse_on_play_again(mouse_x, mouse_y) {
			gs^ = game_init(&gs.log)
		}
	}
}

// --- Action validation ---

can_pick :: proc(gs: ^Game_State, hand: ^Hand) -> bool {
	return !hand_is_full(hand) && board_has_pickable(&gs.board)
}

can_roll :: proc(character: ^Character) -> bool {
	return character.assigned_count > 0 && !character.has_rolled
}

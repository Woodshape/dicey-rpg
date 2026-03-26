package game

import rl "vendor:raylib"

// Top-level update dispatcher. Routes to the appropriate phase handler.
combat_update :: proc(gs: ^Game_State) {
	#partial switch gs.turn {
	case .Player_Turn:
		player_turn_update(gs)
	case .Player_Roll_Result:
		player_roll_result_update(gs)
	case .Enemy_Turn:
		enemy_turn_update(gs)
	case .Enemy_Roll_Result:
		enemy_roll_result_update(gs)
	}
}

// --- Player Turn ---

player_turn_update :: proc(gs: ^Game_State) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	if rl.IsMouseButtonPressed(.LEFT) {
		// Check roll button (not draggable)
		if gs.player.assigned_count > 0 && mouse_on_roll_button(mouse_x, mouse_y) {
			character_roll(&gs.player)
			apply_skull_damage(&gs.player, &gs.enemy)
			resolve_abilities(&gs.player, &gs.enemy)
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

player_roll_result_update :: proc(gs: ^Game_State) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	if rl.IsMouseButtonPressed(.LEFT) {
		if mouse_on_clear_button(mouse_x, mouse_y) {
			character_clear_roll(&gs.player)
			gs.turn = .Enemy_Turn
		}
	}
}

// --- Enemy Turn ---

enemy_turn_update :: proc(gs: ^Game_State) {
	ai_take_turn(gs)
}

// --- Enemy Roll Result ---

ENEMY_ROLL_DISPLAY_TIME :: 1.5  // seconds to show enemy roll results

enemy_roll_result_update :: proc(gs: ^Game_State) {
	gs.turn_timer += rl.GetFrameTime()
	if gs.turn_timer >= ENEMY_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.enemy)
		gs.turn_timer = 0
		gs.turn = .Player_Turn
	}
}

// --- Action validation ---

can_pick :: proc(gs: ^Game_State, hand: ^Hand) -> bool {
	return !hand_is_full(hand) && board_has_pickable(&gs.board)
}

can_roll :: proc(character: ^Character) -> bool {
	return character.assigned_count > 0 && !character.has_rolled
}

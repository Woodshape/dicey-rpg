package game

import rl "vendor:raylib"

// Minimum dice on board before refill triggers.
BOARD_REFILL_THRESHOLD :: 0

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
	case .Victory, .Defeat:
		game_over_update(gs)
	}
}

// --- Win/Lose ---

// Check if either character is dead. Returns the appropriate next phase,
// or the given default_next if both are alive.
check_win_lose :: proc(gs: ^Game_State, default_next: Turn_Phase) -> Turn_Phase {
	if gs.enemy.stats.hp <= 0 {
		return .Victory
	}
	if gs.player.stats.hp <= 0 {
		return .Defeat
	}
	return default_next
}

// --- Board Refill ---

// Refill the board if it's at or below the threshold.
check_board_refill :: proc(gs: ^Game_State) {
	if board_count_dice(&gs.board) <= BOARD_REFILL_THRESHOLD {
		gs.board = board_init()
	}
}

// --- Player Turn ---

player_turn_update :: proc(gs: ^Game_State) {
	check_board_refill(gs)

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

PLAYER_ROLL_DISPLAY_TIME :: 1.5 // seconds to show player roll results

player_roll_result_update :: proc(gs: ^Game_State) {
	gs.turn_timer += rl.GetFrameTime()
	if gs.turn_timer >= PLAYER_ROLL_DISPLAY_TIME {
		character_clear_roll(&gs.player)
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
		character_clear_roll(&gs.enemy)
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
			gs^ = game_init()
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

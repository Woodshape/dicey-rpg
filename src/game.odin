package game

import "core:fmt"
import rl "vendor:raylib"

Game_State :: struct {
	running:   bool,
	board:     Board,
	hand:      Hand,
	player:    Character,
	selection: Selection,
}

game_init :: proc() -> Game_State {
	return Game_State{
		running = true,
		board   = board_init(),
		player  = character_create("Warrior", .Common),
	}
}

game_update :: proc(gs: ^Game_State) {
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_x := rl.GetMouseX()
		mouse_y := rl.GetMouseY()

		// Check board click
		row, col := mouse_to_cell(mouse_x, mouse_y)
		if row >= 0 && col >= 0 {
			handle_board_click(gs, row, col)
			return
		}

		// Check hand click
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		if hand_slot >= 0 {
			handle_hand_click(gs, hand_slot)
			return
		}

		// Check character slot click
		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 {
			handle_char_click(gs, char_slot)
			return
		}

		// Clicked nothing — deselect
		gs.selection = {}
	}

	// Right click to deselect
	if rl.IsMouseButtonPressed(.RIGHT) {
		gs.selection = {}
	}
}

handle_board_click :: proc(gs: ^Game_State, row, col: int) {
	// Deselect any selection first
	gs.selection = {}

	// Pick die from board into hand
	if hand_is_full(&gs.hand) {
		return
	}
	die_type, ok := board_remove(&gs.board, row, col)
	if ok {
		hand_add(&gs.hand, die_type)
	}
}

handle_hand_click :: proc(gs: ^Game_State, slot: int) {
	if slot >= gs.hand.count {
		// Clicked empty hand slot — deselect
		gs.selection = {}
		return
	}

	// Toggle selection on this hand die
	if gs.selection.source == .Hand && gs.selection.index == slot {
		gs.selection = {}
	} else {
		gs.selection = Selection{source = .Hand, index = slot}
	}
}

handle_char_click :: proc(gs: ^Game_State, slot: int) {
	if gs.selection.source == .Hand {
		// Assign selected hand die to character
		hand_index := gs.selection.index
		if hand_index < gs.hand.count {
			die_type := gs.hand.dice[hand_index]
			if character_can_assign(&gs.player, die_type) {
				hand_remove(&gs.hand, hand_index)
				character_assign(&gs.player, die_type)
			}
		}
		gs.selection = {}
	} else if slot < gs.player.assigned_count {
		// Unassign: return die from character to hand
		if !hand_is_full(&gs.hand) {
			die_type, ok := character_unassign(&gs.player, slot)
			if ok {
				hand_add(&gs.hand, die_type)
			}
		}
		gs.selection = {}
	}
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	board_draw(&gs.board)
	hand_draw(&gs.hand, &gs.selection)
	character_draw(&gs.player, &gs.selection)

	// HUD
	rl.DrawText("Dicey RPG", 20, 20, 24, rl.RAYWHITE)

	remaining := board_count(&gs.board)
	count_str := fmt.ctprintf("Board: %d  |  Hand: %d/%d  |  %s: %d/%d",
		remaining,
		gs.hand.count, MAX_HAND_SIZE,
		gs.player.name, gs.player.assigned_count, gs.player.max_dice,
	)
	rl.DrawText(count_str, 20, 50, 16, rl.GRAY)
}

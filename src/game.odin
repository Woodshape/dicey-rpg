package game

import "core:fmt"
import rl "vendor:raylib"

// Enemy panel position (right side)
ENEMY_PANEL_X :: WINDOW_WIDTH - CHAR_PANEL_X - CHAR_PANEL_WIDTH
ENEMY_PANEL_Y :: CHAR_PANEL_Y

Game_State :: struct {
	running:    bool,
	board:      Board,
	hand:       Hand,
	player:     Character,
	enemy:      Character,
	enemy_hand: Hand,
	drag:       Drag_State,
	turn:       Turn_Phase,
	turn_timer: f32,
}

game_init :: proc() -> Game_State {
	return Game_State {
		running = true,
		board   = board_init(),
		player  = warrior_create(),
		enemy   = goblin_create(),
	}
}

game_update :: proc(gs: ^Game_State) {
	combat_update(gs)
}

try_start_drag :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) {
	// Board drag (can drop on hand or character)
	row, col := mouse_to_cell(&gs.board, mouse_x, mouse_y)
	if row >= 0 && col >= 0 {
		if cell_is_pickable(&gs.board, row, col) {
			gs.drag = Drag_State{
				active    = true,
				source    = .Board,
				die_type  = gs.board.cells[row][col].die_type,
				board_row = row,
				board_col = col,
			}
		}
		return
	}

	// Hand drag
	hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
	if hand_slot >= 0 && hand_slot < gs.hand.count {
		gs.drag = Drag_State{
			active   = true,
			source   = .Hand,
			die_type = gs.hand.dice[hand_slot],
			index    = hand_slot,
		}
		return
	}

	// Character die drag (only if hand not full — die returns to hand)
	if !gs.player.has_rolled {
		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 && char_slot < gs.player.assigned_count {
			gs.drag = Drag_State{
				active   = true,
				source   = .Character,
				die_type = gs.player.assigned[char_slot],
				index    = char_slot,
			}
		}
	}
}

// Returns true if a Pick action was consumed (ends turn), false for free Assign moves.
try_drop :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) -> bool {
	#partial switch gs.drag.source {
	case .Board:
		// Board drops are Pick actions (cost a turn)
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			board_remove_die(&gs.board, gs.drag.board_row, gs.drag.board_col)
			hand_add(&gs.hand, gs.drag.die_type)
			return true
		}

		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 && character_can_assign_die(&gs.player, gs.drag.die_type) {
			board_remove_die(&gs.board, gs.drag.board_row, gs.drag.board_col)
			character_assign_die(&gs.player, gs.drag.die_type)
			return true
		}

	case .Hand:
		// Hand to character is a free Assign
		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 && character_can_assign_die(&gs.player, gs.drag.die_type) {
			hand_remove(&gs.hand, gs.drag.index)
			character_assign_die(&gs.player, gs.drag.die_type)
		}

	case .Character:
		// Character to hand is a free Assign
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			character_unassign_die(&gs.player, gs.drag.index)
			hand_add(&gs.hand, gs.drag.die_type)
		}
	}

	return false
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	board_draw(&gs.board, &gs.drag)
	hand_draw(&gs.hand, &gs.drag)
	character_draw(&gs.player, &gs.drag)
	character_draw_at(&gs.enemy, ENEMY_PANEL_X, ENEMY_PANEL_Y, &gs.drag, false, rl.Color{220, 100, 100, 255})
	hand_draw_at(&gs.enemy_hand, ENEMY_HAND_CENTER_X, &gs.drag, false)

	// Dragged die follows cursor
	if gs.drag.active {
		mouse_x := rl.GetMouseX()
		mouse_y := rl.GetMouseY()
		draw_dragged_die(gs.drag.die_type, mouse_x, mouse_y)
	}

	// HUD
	rl.DrawText("Dicey RPG", 20, 20, 24, rl.RAYWHITE)

	remaining := board_count_dice(&gs.board)
	count_str := fmt.ctprintf("Board: %d  |  Hand: %d/%d",
		remaining,
		gs.hand.count, MAX_HAND_SIZE,
	)
	rl.DrawText(count_str, 20, 50, 16, rl.GRAY)

	// Turn indicator
	draw_turn_indicator(gs.turn)
}

// Draw turn phase indicator at top-centre of screen
draw_turn_indicator :: proc(turn: Turn_Phase) {
	label: cstring
	color: rl.Color

	#partial switch turn {
	case .Player_Turn:
		label = "Your Turn"
		color = rl.Color{80, 200, 80, 255}
	case .Player_Roll_Result:
		label = "Roll Result"
		color = rl.Color{220, 200, 60, 255}
	case .Enemy_Turn:
		label = "Enemy Turn"
		color = rl.Color{220, 80, 80, 255}
	case .Enemy_Roll_Result:
		label = "Enemy Roll"
		color = rl.Color{220, 120, 80, 255}
	}

	text_w := rl.MeasureText(label, 20)
	x := (WINDOW_WIDTH - text_w) / 2
	rl.DrawText(label, x, 20, 20, color)
}

// Draw the die being dragged at the cursor position
draw_dragged_die :: proc(die_type: Die_Type, mouse_x, mouse_y: i32) {
	size :: HAND_SLOT_SIZE
	x := mouse_x - size / 2
	y := mouse_y - size / 2

	color := DIE_TYPE_COLORS[die_type]
	rl.DrawRectangle(x, y, size, size, color)
	rl.DrawRectangleLines(x, y, size, size, rl.WHITE)

	label := DIE_TYPE_NAMES[die_type]
	text_w := rl.MeasureText(label, 14)
	rl.DrawText(label, x + (size - text_w) / 2, y + (size - 14) / 2, 14, rl.WHITE)
}

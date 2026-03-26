package game

import "core:fmt"
import rl "vendor:raylib"

// Enemy panel position (right side)
ENEMY_PANEL_X :: WINDOW_WIDTH - CHAR_PANEL_X - HP_BAR_WIDTH
ENEMY_PANEL_Y :: CHAR_PANEL_Y

Game_State :: struct {
	running: bool,
	board:   Board,
	hand:    Hand,
	player:  Character,
	enemy:   Character,
	drag:    Drag_State,
}

game_init :: proc() -> Game_State {
	return Game_State{
		running = true,
		board   = board_init(),
		player  = character_create("Warrior", .Common, Character_Stats{hp = 20, max_hp = 20, attack = 3, defense = 1}),
		enemy   = character_create("Goblin",  .Common, Character_Stats{hp = 15, max_hp = 15, attack = 2, defense = 0}),
	}
}

game_update :: proc(gs: ^Game_State) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	if rl.IsMouseButtonPressed(.LEFT) {
		// If rolled, only allow clear button
		if gs.player.has_rolled {
			if mouse_on_clear_button(mouse_x, mouse_y) {
				character_clear_roll(&gs.player)
			}
			return
		}

		// Check roll button first (not draggable)
		if gs.player.assigned_count > 0 && mouse_on_roll_button(mouse_x, mouse_y) {
			character_roll(&gs.player)
			// Apply skull damage to enemy
			apply_skull_damage(&gs.player, &gs.enemy)
			return
		}

		// Try to start a drag
		try_start_drag(gs, mouse_x, mouse_y)
	}

	if rl.IsMouseButtonReleased(.LEFT) && gs.drag.active {
		try_drop(gs, mouse_x, mouse_y)
		gs.drag = {}
	}
}

try_start_drag :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) {
	// Board drag (can drop on hand or character)
	row, col := mouse_to_cell(mouse_x, mouse_y)
	if row >= 0 && col >= 0 {
		if cell_is_perimeter(&gs.board, row, col) {
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

try_drop :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) {
	#partial switch gs.drag.source {
	case .Board:
		// Board can drop on hand or directly on character
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			board_remove(&gs.board, gs.drag.board_row, gs.drag.board_col)
			hand_add(&gs.hand, gs.drag.die_type)
			return
		}

		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 && character_can_assign_die(&gs.player, gs.drag.die_type) {
			board_remove(&gs.board, gs.drag.board_row, gs.drag.board_col)
			character_assign_die(&gs.player, gs.drag.die_type)
		}

	case .Hand:
		// Hand can only drop on character
		char_slot := mouse_to_char_slot(mouse_x, mouse_y, gs.player.max_dice)
		if char_slot >= 0 && character_can_assign_die(&gs.player, gs.drag.die_type) {
			hand_remove(&gs.hand, gs.drag.index)
			character_assign_die(&gs.player, gs.drag.die_type)
		}

	case .Character:
		// Character can only drop on hand
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			character_unassign_die(&gs.player, gs.drag.index)
			hand_add(&gs.hand, gs.drag.die_type)
		}
	}
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	board_draw(&gs.board, &gs.drag)
	hand_draw(&gs.hand, &gs.drag)
	character_draw(&gs.player, &gs.drag)
	draw_enemy_panel(&gs.enemy)

	// Dragged die follows cursor
	if gs.drag.active {
		mouse_x := rl.GetMouseX()
		mouse_y := rl.GetMouseY()
		draw_dragged_die(gs.drag.die_type, mouse_x, mouse_y)
	}

	// HUD
	rl.DrawText("Dicey RPG", 20, 20, 24, rl.RAYWHITE)

	remaining := board_count(&gs.board)
	count_str := fmt.ctprintf("Board: %d  |  Hand: %d/%d",
		remaining,
		gs.hand.count, MAX_HAND_SIZE,
	)
	rl.DrawText(count_str, 20, 50, 16, rl.GRAY)
}

// Draw a simple enemy panel on the right side
draw_enemy_panel :: proc(enemy: ^Character) {
	if !character_is_active(enemy) {
		return
	}

	x := i32(ENEMY_PANEL_X)
	y := i32(ENEMY_PANEL_Y)

	rl.DrawText(enemy.name, x, y, 20, rl.Color{220, 100, 100, 255})
	rl.DrawText(RARITY_NAMES[enemy.rarity], x, y + 24, 14, rl.GRAY)

	// Stats
	stats_str := fmt.ctprintf("ATK %d  DEF %d", enemy.stats.attack, enemy.stats.defense)
	rl.DrawText(stats_str, x, y + 42, 12, rl.Color{180, 180, 180, 255})

	draw_hp_bar(enemy, x, y + 58)
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

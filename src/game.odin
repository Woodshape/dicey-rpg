package game

import "core:fmt"
import rl "vendor:raylib"

Game_State :: struct {
	running: bool,
	board:   Board,
}

game_init :: proc() -> Game_State {
	return Game_State{
		running = true,
		board   = board_init(),
	}
}

game_update :: proc(gs: ^Game_State) {
	// Click to pick a die from the board perimeter
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_x := rl.GetMouseX()
		mouse_y := rl.GetMouseY()
		row, col := mouse_to_cell(mouse_x, mouse_y)
		if row >= 0 && col >= 0 {
			board_remove(&gs.board, row, col)
		}
	}
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	board_draw(&gs.board)

	// HUD
	rl.DrawText("Dicey RPG", 20, 20, 24, rl.RAYWHITE)

	remaining := board_count(&gs.board)
	count_str := fmt.ctprintf("Dice remaining: %d", remaining)
	rl.DrawText(count_str, 20, 50, 18, rl.GRAY)
}

package game

import rl "vendor:raylib"

Game_State :: struct {
	running: bool,
}

game_init :: proc() -> Game_State {
	return Game_State{
		running = true,
	}
}

game_update :: proc(gs: ^Game_State) {
	// placeholder — game logic goes here
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	rl.DrawText("Dicey RPG", 20, 20, 30, rl.RAYWHITE)
	rl.DrawText("Milestone 0 — skeleton running", 20, 60, 18, rl.GRAY)
}

package game

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()

	rl.SetTargetFPS(TARGET_FPS)

	gs := game_init()
	combat_log_init_file(&gs.log)

	for !rl.WindowShouldClose() && gs.running {
		game_update(&gs)
		game_draw(&gs)
	}
}

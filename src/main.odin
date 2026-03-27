package game

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()

	rl.SetTargetFPS(TARGET_FPS)

	clog: Combat_Log
	combat_log_init_file(&clog)
	gs, ok := game_init("tutorial", &clog)
	if !ok {
		rl.TraceLog(.ERROR, "Failed to load encounter — check config files")
		return
	}

	for !rl.WindowShouldClose() && gs.running {
		game_update(&gs)
		game_draw(&gs)
	}
}

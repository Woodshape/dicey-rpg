package game

import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()

	rl.SetTargetFPS(TARGET_FPS)

	seed := u64(time.time_to_unix(time.now()))
	rand.reset(seed)

	encounter :: "tutorial"
	gs, ok := game_init(encounter, seed = seed)
	if !ok {
		rl.TraceLog(.ERROR, "Failed to load encounter — check config files")
		return
	}

	// Initialize decision trace (writes header + ROUND 1)
	trace_init(&gs.trace, seed, encounter)
	trace_round(&gs.trace, 1)
	defer trace_close(&gs.trace)

	for !rl.WindowShouldClose() && gs.running {
		game_update(&gs)
		game_draw(&gs)
	}
}

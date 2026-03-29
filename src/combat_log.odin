package game

import "core:fmt"
import rl "vendor:raylib"

// Add an entry to the combat log ring buffer with a color.
combat_log_add :: proc(log: ^Combat_Log, color: rl.Color, format: string, args: ..any) {
	entry := &log.entries[log.head]
	entry.color = color

	// Format into the fixed buffer and null-terminate for cstring safety
	buf := entry.text[:]
	result := fmt.bprintf(buf, format, ..args)
	entry.len = len(result)
	if entry.len < MAX_LOG_LENGTH {
		entry.text[entry.len] = 0
	}

	log.head = (log.head + 1) % MAX_LOG_ENTRIES
	if log.count < MAX_LOG_ENTRIES {
		log.count += 1
	}
}

// Convenience: log with default white color
combat_log_write :: proc(log: ^Combat_Log, format: string, args: ..any) {
	combat_log_add(log, rl.Color{200, 200, 200, 255}, format, ..args)
}

// Draw the combat log in the bottom-centre of the screen.
LOG_FONT_SIZE :: 13
LOG_LINE_HEIGHT :: 16
LOG_Y_BOTTOM :: WINDOW_HEIGHT - 20 // bottom edge of log area
LOG_WIDTH :: 400

combat_log_draw :: proc(log: ^Combat_Log) {
	if log.count <= 0 {
		return
	}

	x := i32((WINDOW_WIDTH - LOG_WIDTH) / 2)

	// Draw entries from oldest to newest (bottom-up: newest at the bottom)
	for i in 0 ..< log.count {
		// Ring buffer index: oldest entry first
		idx := (log.head - log.count + i + MAX_LOG_ENTRIES) % MAX_LOG_ENTRIES
		entry := &log.entries[idx]

		line_y := LOG_Y_BOTTOM - i32(log.count - i) * LOG_LINE_HEIGHT

		// Convert fixed buffer to cstring for raylib
		text := cstring(raw_data(entry.text[:entry.len]))
		rl.DrawText(text, x, line_y, LOG_FONT_SIZE, entry.color)
	}
}

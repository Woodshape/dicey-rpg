package game

import "core:math/rand"
import rl "vendor:raylib"

// --- Round State ---

// Create initial round state, shuffle first weight group cycle.
round_state_init :: proc(pool_size: int = DEFAULT_POOL_SIZE, skull_chance: int = SKULL_CHANCE) -> Round_State {
	rs := Round_State {
		round_number = 1,
		first_pick   = true, // player picks first in round 1
		pool_size    = pool_size,
		skull_chance = skull_chance,
	}
	shuffle_weight_groups(&rs)
	return rs
}

// Advance to the next weight group. Reshuffles when the cycle is exhausted.
round_state_advance :: proc(rs: ^Round_State) {
	rs.cycle_index += 1
	if rs.cycle_index >= WEIGHT_GROUP_COUNT {
		shuffle_weight_groups(rs)
	}
	rs.round_number += 1
	rs.first_pick = !rs.first_pick
}

// Shuffle the 4 weight groups into a random order (Fisher-Yates).
@(private = "file")
shuffle_weight_groups :: proc(rs: ^Round_State) {
	rs.cycle_index = 0
	// Initialize with all groups in order
	rs.group_order = {.Low, .Mid_Low, .Mid_High, .High}
	// Fisher-Yates shuffle
	for i := WEIGHT_GROUP_COUNT - 1; i > 0; i -= 1 {
		j := rand.int_max(i + 1)
		rs.group_order[i], rs.group_order[j] = rs.group_order[j], rs.group_order[i]
	}
}

// --- Pool Generation ---

// Generate a pool of dice using the current weight group and skull chance.
pool_generate :: proc(rs: ^Round_State) -> Draft_Pool {
	group := rs.group_order[rs.cycle_index]
	pool := Draft_Pool {
		count        = rs.pool_size,
		remaining    = rs.pool_size,
		weight_group = group,
		skull_chance = rs.skull_chance,
	}
	for i in 0 ..< rs.pool_size {
		pool.dice[i] = weight_group_die_type(group, rs.skull_chance)
	}
	return pool
}

// Weighted random die type for a weight group.
// Skull chance is checked first; if not skull, uses group-specific weights.
weight_group_die_type :: proc(group: Weight_Group, skull_chance: int = SKULL_CHANCE) -> Die_Type {
	// Skull check first
	if skull_chance > 0 && rand.int_max(100) < skull_chance {
		return .Skull
	}

	w_d4, w_d6, w_d8, w_d10, w_d12: f32

	switch group {
	case .Low:
		w_d4  = 1.0; w_d6  = 0.8; w_d8  = 0.2; w_d10 = 0.0; w_d12 = 0.0
	case .Mid_Low:
		w_d4  = 0.2; w_d6  = 0.8; w_d8  = 1.0; w_d10 = 0.2; w_d12 = 0.0
	case .Mid_High:
		w_d4  = 0.0; w_d6  = 0.2; w_d8  = 0.8; w_d10 = 1.0; w_d12 = 0.3
	case .High:
		w_d4  = 0.0; w_d6  = 0.0; w_d8  = 0.2; w_d10 = 0.8; w_d12 = 1.0
	}

	total := w_d4 + w_d6 + w_d8 + w_d10 + w_d12
	roll := rand.float32() * total

	roll -= w_d4;  if roll < 0 { return .D4 }
	roll -= w_d6;  if roll < 0 { return .D6 }
	roll -= w_d8;  if roll < 0 { return .D8 }
	roll -= w_d10; if roll < 0 { return .D10 }
	return .D12
}

// --- Pool Operations ---

// Remove a die from the pool by index. Shifts remaining dice left.
// Returns the die type removed, or (.None, false) on invalid index.
pool_remove_die :: proc(pool: ^Draft_Pool, index: int) -> (Die_Type, bool) {
	if index < 0 || index >= pool.remaining {
		return .None, false
	}

	die_type := pool.dice[index]

	// Shift remaining dice left
	for i in index ..< pool.remaining - 1 {
		pool.dice[i] = pool.dice[i + 1]
	}
	pool.dice[pool.remaining - 1] = .None
	pool.remaining -= 1

	return die_type, true
}

// True if no dice remain in the pool.
pool_is_empty :: proc(pool: ^Draft_Pool) -> bool {
	return pool.remaining <= 0
}

// --- Layout & Hit-Testing ---

// Top-left pixel position of the pool (centred horizontally, upper third of screen).
pool_origin :: proc(count: int) -> (i32, i32) {
	pool_px := i32(count) * i32(POOL_CELL_SIZE + POOL_CELL_GAP) - i32(POOL_CELL_GAP)
	x := (WINDOW_WIDTH - pool_px) / 2
	y := WINDOW_HEIGHT / 3 - i32(POOL_CELL_SIZE) / 2
	return x, y
}

// Pixel position of the Nth die slot in the pool.
pool_slot_position :: proc(index, count: int) -> (i32, i32) {
	ox, oy := pool_origin(count)
	stride := i32(POOL_CELL_SIZE + POOL_CELL_GAP)
	x := ox + i32(index) * stride
	return x, oy
}

// Hit-test pool slots. Returns the index of the die under the mouse, or -1.
mouse_to_pool_slot :: proc(pool: ^Draft_Pool, mouse_x, mouse_y: i32) -> int {
	if pool.remaining <= 0 {
		return -1
	}

	ox, oy := pool_origin(pool.remaining)
	stride := i32(POOL_CELL_SIZE + POOL_CELL_GAP)

	rel_x := mouse_x - ox
	rel_y := mouse_y - oy

	if rel_x < 0 || rel_y < 0 || rel_y >= i32(POOL_CELL_SIZE) {
		return -1
	}

	index := int(rel_x) / int(stride)
	if index >= pool.remaining {
		return -1
	}

	// Check we're inside the cell, not in the gap
	local_x := int(rel_x) % int(stride)
	if local_x >= POOL_CELL_SIZE {
		return -1
	}

	return index
}

// --- Rendering ---

// Draw the draft pool with hover/drag visuals.
pool_draw :: proc(pool: ^Draft_Pool, drag: ^Drag_State) {
	if pool.remaining <= 0 {
		return
	}

	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hover_index := mouse_to_pool_slot(pool, mouse_x, mouse_y)

	for i in 0 ..< pool.remaining {
		die_type := pool.dice[i]
		x, y := pool_slot_position(i, pool.remaining)
		is_dragged := drag.active && drag.source == .Pool && drag.pool_index == i

		// Ghost the die being dragged
		if is_dragged {
			rl.DrawRectangle(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, rl.Color{60, 60, 70, 120})
			rl.DrawRectangleLines(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, rl.Color{255, 255, 255, 40})
			continue
		}

		is_hovered := i == hover_index && !drag.active

		// Cell background
		color := DIE_TYPE_COLORS[die_type]
		rl.DrawRectangle(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, color)

		// Hover highlight
		if is_hovered {
			rl.DrawRectangle(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, rl.Color{255, 255, 255, 50})
			rl.DrawRectangleLines(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, rl.WHITE)
		} else {
			rl.DrawRectangleLines(x, y, POOL_CELL_SIZE, POOL_CELL_SIZE, rl.Color{255, 255, 255, 80})
		}

		// Die type label
		label := DIE_TYPE_NAMES[die_type]
		text_w := rl.MeasureText(label, 16)
		rl.DrawText(label, x + (POOL_CELL_SIZE - text_w) / 2, y + (POOL_CELL_SIZE - 16) / 2, 16, rl.WHITE)
	}
}

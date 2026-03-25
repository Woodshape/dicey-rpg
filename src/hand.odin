package game

import rl "vendor:raylib"

// Add a die to the hand. Returns false if hand is full.
hand_add :: proc(hand: ^Hand, die_type: Die_Type) -> bool {
	assert(die_type != .None, "cannot add Die_Type.None to hand")
	if hand.count >= MAX_HAND_SIZE {
		return false
	}
	hand.dice[hand.count] = die_type
	hand.count += 1
	return true
}

// Remove a die from the hand by index. Returns the die type.
hand_remove :: proc(hand: ^Hand, index: int) -> (Die_Type, bool) {
	if index < 0 || index >= hand.count {
		return .D4, false
	}

	die_type := hand.dice[index]

	// Shift remaining dice left and clear vacated slot
	for i in index ..< hand.count - 1 {
		hand.dice[i] = hand.dice[i + 1]
	}
	hand.count -= 1
	hand.dice[hand.count] = {}

	return die_type, true
}

// Check if hand is full
hand_is_full :: proc(hand: ^Hand) -> bool {
	return hand.count >= MAX_HAND_SIZE
}

// Get pixel position for a hand slot (centred at bottom of screen)
hand_slot_position :: proc(index: int) -> (i32, i32) {
	slot_stride := i32(HAND_SLOT_SIZE + HAND_SLOT_GAP)
	total_width := slot_stride * MAX_HAND_SIZE - HAND_SLOT_GAP
	start_x := (WINDOW_WIDTH - total_width) / 2
	x := start_x + i32(index) * slot_stride
	y := i32(WINDOW_HEIGHT - HAND_Y_OFFSET)
	return x, y
}

// Check if mouse is over a hand slot. Returns slot index or -1.
mouse_to_hand_slot :: proc(mouse_x, mouse_y: i32) -> int {
	for i in 0 ..< MAX_HAND_SIZE {
		x, y := hand_slot_position(i)
		if mouse_x >= x && mouse_x < x + HAND_SLOT_SIZE &&
		   mouse_y >= y && mouse_y < y + HAND_SLOT_SIZE {
			return i
		}
	}
	return -1
}

// Check if mouse is in the general hand region (for loose drop targeting)
mouse_in_hand_region :: proc(mouse_x, mouse_y: i32) -> bool {
	first_x, first_y := hand_slot_position(0)
	last_x, _ := hand_slot_position(MAX_HAND_SIZE - 1)
	region_right := last_x + HAND_SLOT_SIZE

	padding :: 10
	return mouse_x >= first_x - padding && mouse_x <= region_right + padding &&
	       mouse_y >= first_y - padding && mouse_y <= first_y + HAND_SLOT_SIZE + padding
}

// Draw the hand
hand_draw :: proc(hand: ^Hand, drag: ^Drag_State) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hover_slot := mouse_to_hand_slot(mouse_x, mouse_y)

	// Is the hand a valid drop target right now?
	is_drop_target := drag.active && (drag.source == .Board || drag.source == .Character)

	for i in 0 ..< MAX_HAND_SIZE {
		x, y := hand_slot_position(i)

		if i < hand.count {
			is_dragged := drag.active && drag.source == .Hand && drag.index == i

			if is_dragged {
				// Ghost the slot being dragged
				rl.DrawRectangle(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, rl.Color{60, 60, 70, 120})
				rl.DrawRectangleLines(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, rl.Color{255, 255, 255, 40})
			} else {
				// Normal filled slot
				die_type := hand.dice[i]
				color := DIE_TYPE_COLORS[die_type]
				rl.DrawRectangle(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, color)

				label := DIE_TYPE_NAMES[die_type]
				text_w := rl.MeasureText(label, 14)
				rl.DrawText(label, x + (HAND_SLOT_SIZE - text_w) / 2, y + (HAND_SLOT_SIZE - 14) / 2, 14, rl.WHITE)

				// Hover highlight (only when not dragging)
				if i == hover_slot && !drag.active {
					rl.DrawRectangle(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, rl.Color{255, 255, 255, 40})
					rl.DrawRectangleLines(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, rl.WHITE)
				}
			}
		} else {
			// Empty slot
			border_color := rl.Color{255, 255, 255, 30}
			if is_drop_target {
				border_color = rl.Color{60, 200, 80, 180}
			}
			rl.DrawRectangleLines(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, border_color)

			// Hover glow on empty slots when they're a drop target
			if is_drop_target && i == hover_slot {
				rl.DrawRectangle(x, y, HAND_SLOT_SIZE, HAND_SLOT_SIZE, rl.Color{60, 200, 80, 40})
			}
		}
	}

	// Label
	slot_x, slot_y := hand_slot_position(0)
	rl.DrawText("Hand", slot_x, slot_y - 20, 16, rl.GRAY)
}

package game

import "core:fmt"
import rl "vendor:raylib"

// Create a character with the given name and rarity
character_create :: proc(name: cstring, rarity: Character_Rarity) -> Character {
	return Character{
		state    = .Alive,
		name     = name,
		rarity   = rarity,
		max_dice = RARITY_MAX_DICE[rarity],
	}
}

// Get the die type currently assigned to a character, if any.
character_assigned_type :: proc(character: ^Character) -> (Die_Type, bool) {
	if character.assigned_count == 0 {
		return .None, false
	}
	return character.assigned[0], true
}

// Check if a die type can be assigned to a character.
// Must not be full, and must match the existing assigned type (or be first die).
character_can_assign :: proc(character: ^Character, die_type: Die_Type) -> bool {
	if character.assigned_count >= character.max_dice {
		return false
	}
	if character.assigned_count == 0 {
		return true
	}
	return character.assigned[0] == die_type
}

// Assign a die to a character. Returns false if invalid.
character_assign :: proc(character: ^Character, die_type: Die_Type) -> bool {
	assert(die_type != .None, "cannot assign Die_Type.None to character")
	if !character_can_assign(character, die_type) {
		return false
	}
	character.assigned[character.assigned_count] = die_type
	character.assigned_count += 1
	return true
}

// Remove a die from a character by index. Returns the die type.
character_unassign :: proc(character: ^Character, index: int) -> (Die_Type, bool) {
	if index < 0 || index >= character.assigned_count {
		return .None, false
	}

	die_type := character.assigned[index]

	// Shift remaining dice left and clear vacated slot
	for i in index ..< character.assigned_count - 1 {
		character.assigned[i] = character.assigned[i + 1]
	}
	character.assigned_count -= 1
	character.assigned[character.assigned_count] = {}

	return die_type, true
}

// Get pixel position for a character's die slot
char_slot_position :: proc(slot_index: int) -> (i32, i32) {
	slot_stride := i32(CHAR_SLOT_SIZE + CHAR_SLOT_GAP)
	x := i32(CHAR_PANEL_X) + i32(slot_index) * slot_stride
	y := i32(CHAR_PANEL_Y) + 50  // below name/rarity text
	return x, y
}

// Check if mouse is over a character die slot. Returns slot index or -1.
mouse_to_char_slot :: proc(mouse_x, mouse_y: i32, max_dice: int) -> int {
	for i in 0 ..< max_dice {
		x, y := char_slot_position(i)
		if mouse_x >= x && mouse_x < x + CHAR_SLOT_SIZE &&
		   mouse_y >= y && mouse_y < y + CHAR_SLOT_SIZE {
			return i
		}
	}
	return -1
}

// Roll button position (below dice slots)
ROLL_BTN_WIDTH  :: 70
ROLL_BTN_HEIGHT :: 28

roll_button_rect :: proc() -> rl.Rectangle {
	_, slot_y := char_slot_position(0)
	return rl.Rectangle{
		x      = f32(CHAR_PANEL_X),
		y      = f32(slot_y + CHAR_SLOT_SIZE + 10),
		width  = ROLL_BTN_WIDTH,
		height = ROLL_BTN_HEIGHT,
	}
}

// Check if mouse is over the roll button
mouse_on_roll_button :: proc(mouse_x, mouse_y: i32) -> bool {
	r := roll_button_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

// Draw a character panel
character_draw :: proc(character: ^Character, drag: ^Drag_State) {
	if !character_is_active(character) {
		return
	}

	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hover_slot := mouse_to_char_slot(mouse_x, mouse_y, character.max_dice)

	// Name and rarity
	rl.DrawText(character.name, CHAR_PANEL_X, CHAR_PANEL_Y, 20, rl.RAYWHITE)
	rl.DrawText(RARITY_NAMES[character.rarity], CHAR_PANEL_X, CHAR_PANEL_Y + 24, 14, rl.GRAY)

	if character.has_rolled {
		draw_rolled_dice(character)
	} else {
		draw_assigned_dice(character, drag, hover_slot)

		// Roll button (only when dice are assigned and not dragging)
		if character.assigned_count > 0 && !drag.active {
			draw_roll_button(mouse_x, mouse_y)
		}
	}
}

draw_assigned_dice :: proc(character: ^Character, drag: ^Drag_State, hover_slot: int) {
	// Is the character a valid drop target for the current drag?
	is_drop_target := drag.active && drag.source == .Hand && character_can_assign(character, drag.die_type)

	for i in 0 ..< character.max_dice {
		x, y := char_slot_position(i)

		if i < character.assigned_count {
			is_dragged := drag.active && drag.source == .Character && drag.index == i

			if is_dragged {
				// Ghost the slot being dragged
				rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{60, 60, 70, 120})
				rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{255, 255, 255, 40})
			} else {
				die_type := character.assigned[i]
				color := DIE_TYPE_COLORS[die_type]
				rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, color)

				label := DIE_TYPE_NAMES[die_type]
				text_w := rl.MeasureText(label, 12)
				rl.DrawText(label, x + (CHAR_SLOT_SIZE - text_w) / 2, y + (CHAR_SLOT_SIZE - 12) / 2, 12, rl.WHITE)

				// Hover highlight (only when not dragging)
				if i == hover_slot && !drag.active {
					rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{255, 255, 255, 40})
					rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.WHITE)
				}
			}
		} else {
			// Empty slot
			border_color := rl.Color{255, 255, 255, 30}
			if is_drop_target {
				border_color = rl.Color{60, 200, 80, 180}
			}
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, border_color)

			if is_drop_target && i == hover_slot {
				rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{60, 200, 80, 40})
			}
		}
	}
}

draw_rolled_dice :: proc(character: ^Character) {
	roll := &character.roll

	for i in 0 ..< roll.count {
		x, y := char_slot_position(i)

		die_type := character.assigned[i]
		base_color := DIE_TYPE_COLORS[die_type]

		if roll.matched[i] {
			// Matched die — bright with gold border
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, base_color)
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.YELLOW)
			rl.DrawRectangleLines(x + 1, y + 1, CHAR_SLOT_SIZE - 2, CHAR_SLOT_SIZE - 2, rl.YELLOW)
		} else {
			// Unmatched die — dimmed
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, DIE_TYPE_COLORS_DIM[die_type])
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{255, 255, 255, 40})
		}

		// Show rolled value
		val_str := fmt.ctprintf("%d", roll.values[i])
		text_w := rl.MeasureText(val_str, 18)
		rl.DrawText(val_str, x + (CHAR_SLOT_SIZE - text_w) / 2, y + (CHAR_SLOT_SIZE - 18) / 2, 18, rl.WHITE)
	}

	// Show match result below dice
	btn_rect := roll_button_rect()
	result_y := i32(btn_rect.y)

	if roll.pattern != .None {
		pattern_str := MATCH_PATTERN_NAMES[roll.pattern]
		rl.DrawText(pattern_str, CHAR_PANEL_X, result_y, 16, rl.YELLOW)

		potency_str := fmt.ctprintf("Potency: %d", roll.matched_value)
		rl.DrawText(potency_str, CHAR_PANEL_X, result_y + 20, 14, rl.RAYWHITE)
	} else {
		rl.DrawText("No Match", CHAR_PANEL_X, result_y, 16, rl.Color{180, 80, 80, 255})
	}

	if roll.unmatched_count > 0 {
		meter_str := fmt.ctprintf("Super: +%d", roll.unmatched_count)
		rl.DrawText(meter_str, CHAR_PANEL_X, result_y + 40, 14, rl.Color{150, 120, 220, 255})
	}

	// Clear button
	clear_y := result_y + 64
	rl.DrawRectangle(CHAR_PANEL_X, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.Color{80, 80, 80, 255})
	rl.DrawRectangleLines(CHAR_PANEL_X, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.GRAY)
	clear_w := rl.MeasureText("Clear", 14)
	rl.DrawText("Clear", CHAR_PANEL_X + (ROLL_BTN_WIDTH - clear_w) / 2, clear_y + 7, 14, rl.RAYWHITE)
}

draw_roll_button :: proc(mouse_x, mouse_y: i32) {
	r := roll_button_rect()
	hovered := mouse_on_roll_button(mouse_x, mouse_y)

	bg_color := rl.Color{50, 120, 50, 255}
	if hovered {
		bg_color = rl.Color{70, 160, 70, 255}
	}

	rl.DrawRectangle(i32(r.x), i32(r.y), i32(r.width), i32(r.height), bg_color)
	rl.DrawRectangleLines(i32(r.x), i32(r.y), i32(r.width), i32(r.height), rl.Color{100, 200, 100, 255})

	text_w := rl.MeasureText("Roll", 14)
	rl.DrawText("Roll", i32(r.x) + (i32(r.width) - text_w) / 2, i32(r.y) + 7, 14, rl.WHITE)
}

// Get clear button rect (for click detection)
clear_button_rect :: proc() -> rl.Rectangle {
	btn := roll_button_rect()
	return rl.Rectangle{
		x      = btn.x,
		y      = btn.y + 64,
		width  = ROLL_BTN_WIDTH,
		height = ROLL_BTN_HEIGHT,
	}
}

mouse_on_clear_button :: proc(mouse_x, mouse_y: i32) -> bool {
	r := clear_button_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

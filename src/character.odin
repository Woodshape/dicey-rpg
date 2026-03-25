package game

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

// Draw a character panel
character_draw :: proc(character: ^Character, selection: ^Selection) {
	if !character_is_active(character) {
		return
	}

	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hover_slot := mouse_to_char_slot(mouse_x, mouse_y, character.max_dice)

	// Name and rarity
	rl.DrawText(character.name, CHAR_PANEL_X, CHAR_PANEL_Y, 20, rl.RAYWHITE)
	rl.DrawText(RARITY_NAMES[character.rarity], CHAR_PANEL_X, CHAR_PANEL_Y + 24, 14, rl.GRAY)

	// Die slots
	for i in 0 ..< character.max_dice {
		x, y := char_slot_position(i)

		if i < character.assigned_count {
			// Filled slot
			die_type := character.assigned[i]
			color := DIE_TYPE_COLORS[die_type]
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, color)

			// Die type label
			label := DIE_TYPE_NAMES[die_type]
			text_w := rl.MeasureText(label, 12)
			rl.DrawText(label, x + (CHAR_SLOT_SIZE - text_w) / 2, y + (CHAR_SLOT_SIZE - 12) / 2, 12, rl.WHITE)

			// Hover
			if i == hover_slot && selection.source == .None {
				rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{255, 255, 255, 40})
				rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.WHITE)
			}
		} else {
			// Empty slot — show if a selected hand die can be assigned here
			border_color := rl.Color{255, 255, 255, 30}

			if selection.source == .Hand {
				border_color = rl.Color{60, 200, 80, 180}  // green = valid target
			}

			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, border_color)

			// Hover highlight on empty slots when hand die is selected
			if i == hover_slot && selection.source == .Hand {
				rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{60, 200, 80, 40})
			}
		}
	}
}

package game

import "core:fmt"
import rl "vendor:raylib"

// Create a character with the given name, rarity, and stats.
character_create :: proc(name: cstring, rarity: Character_Rarity, stats: Character_Stats) -> Character {
	return Character{
		state    = .Alive,
		name     = name,
		rarity   = rarity,
		max_dice = RARITY_MAX_DICE[rarity],
		stats    = stats,
	}
}

// Calculate damage from skull dice: attacker attacks N times at Attack stat.
// Returns total damage dealt (after defense).
apply_skull_damage :: proc(attacker: ^Character, target: ^Character) -> int {
	if attacker.roll.skull_count <= 0 {
		return 0
	}
	damage_per_hit := max(attacker.stats.attack - target.stats.defense, 0)
	total := attacker.roll.skull_count * damage_per_hit
	target.stats.hp = max(target.stats.hp - total, 0)
	return total
}

// Get the normal (non-skull) die type currently assigned to a character, if any.
character_assigned_die_type :: proc(character: ^Character) -> (Die_Type, bool) {
	for i in 0 ..< character.assigned_count {
		if die_type_is_normal(character.assigned[i]) {
			return character.assigned[i], true
		}
	}
	return .None, false
}

// Check if a die type can be assigned to a character.
// Skull dice are always compatible. Normal dice must all be the same type.
character_can_assign_die :: proc(character: ^Character, die_type: Die_Type) -> bool {
	if character.assigned_count >= character.max_dice {
		return false
	}
	// Skull dice are always compatible
	if die_type == .Skull {
		return true
	}
	// First normal die — check if there's already a normal type assigned
	assigned_type, has_type := character_assigned_die_type(character)
	if !has_type {
		return true
	}
	return assigned_type == die_type
}

// Assign a die to a character. Returns false if invalid.
character_assign_die :: proc(character: ^Character, die_type: Die_Type) -> bool {
	assert(die_type != .None, "cannot assign Die_Type.None to character")
	if !character_can_assign_die(character, die_type) {
		return false
	}
	character.assigned[character.assigned_count] = die_type
	character.assigned_count += 1
	return true
}

// Remove a die from a character by index. Returns the die type.
character_unassign_die :: proc(character: ^Character, index: int) -> (Die_Type, bool) {
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
	y := i32(CHAR_PANEL_Y) + 66  // below name/rarity/HP bar
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

	// HP bar
	draw_hp_bar(character, CHAR_PANEL_X, CHAR_PANEL_Y + 42)

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
	is_drop_target := drag.active && (drag.source == .Hand || drag.source == .Board) && character_can_assign_die(character, drag.die_type)

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

		if roll.is_skull[i] {
			// Skull die — distinct look, dark red border
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, DIE_TYPE_COLORS[.Skull])
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{200, 60, 60, 255})
			rl.DrawRectangleLines(x + 1, y + 1, CHAR_SLOT_SIZE - 2, CHAR_SLOT_SIZE - 2, rl.Color{200, 60, 60, 255})
			skull_w := rl.MeasureText("Skl", 14)
			rl.DrawText("Skl", x + (CHAR_SLOT_SIZE - skull_w) / 2, y + (CHAR_SLOT_SIZE - 14) / 2, 14, rl.Color{60, 0, 0, 255})
		} else if roll.matched[i] {
			// Matched die — bright with gold border
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, DIE_TYPE_COLORS[die_type])
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.YELLOW)
			rl.DrawRectangleLines(x + 1, y + 1, CHAR_SLOT_SIZE - 2, CHAR_SLOT_SIZE - 2, rl.YELLOW)
			val_str := fmt.ctprintf("%d", roll.values[i])
			text_w := rl.MeasureText(val_str, 18)
			rl.DrawText(val_str, x + (CHAR_SLOT_SIZE - text_w) / 2, y + (CHAR_SLOT_SIZE - 18) / 2, 18, rl.WHITE)
		} else {
			// Unmatched die — dimmed
			rl.DrawRectangle(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, DIE_TYPE_COLORS_DIM[die_type])
			rl.DrawRectangleLines(x, y, CHAR_SLOT_SIZE, CHAR_SLOT_SIZE, rl.Color{255, 255, 255, 40})
			val_str := fmt.ctprintf("%d", roll.values[i])
			text_w := rl.MeasureText(val_str, 18)
			rl.DrawText(val_str, x + (CHAR_SLOT_SIZE - text_w) / 2, y + (CHAR_SLOT_SIZE - 18) / 2, 18, rl.Color{180, 180, 180, 255})
		}
	}

	// Show results below dice
	btn_rect := roll_button_rect()
	result_y := i32(btn_rect.y)
	line := result_y

	// Skull damage
	if roll.skull_count > 0 {
		dmg_str := fmt.ctprintf("Skull x%d -> ATK %d", roll.skull_count, character.stats.attack)
		rl.DrawText(dmg_str, CHAR_PANEL_X, line, 14, rl.Color{200, 60, 60, 255})
		line += 18
	}

	// Match result
	if roll.pattern != .None {
		pattern_str := MATCH_PATTERN_NAMES[roll.pattern]
		rl.DrawText(pattern_str, CHAR_PANEL_X, line, 16, rl.YELLOW)
		line += 18

		potency_str := fmt.ctprintf("Potency: %d", roll.matched_value)
		rl.DrawText(potency_str, CHAR_PANEL_X, line, 14, rl.RAYWHITE)
		line += 18
	} else if roll.skull_count == 0 {
		rl.DrawText("No Match", CHAR_PANEL_X, line, 16, rl.Color{180, 80, 80, 255})
		line += 18
	}

	if roll.unmatched_count > 0 {
		meter_str := fmt.ctprintf("Super: +%d", roll.unmatched_count)
		rl.DrawText(meter_str, CHAR_PANEL_X, line, 14, rl.Color{150, 120, 220, 255})
		line += 18
	}

	// Clear button — use the same rect as click detection
	r := clear_button_rect()
	clear_x := i32(r.x)
	clear_y := i32(r.y)
	rl.DrawRectangle(clear_x, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.Color{80, 80, 80, 255})
	rl.DrawRectangleLines(clear_x, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.GRAY)
	clear_w := rl.MeasureText("Clear", 14)
	rl.DrawText("Clear", clear_x + (ROLL_BTN_WIDTH - clear_w) / 2, clear_y + 7, 14, rl.RAYWHITE)
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

// Clear button: positioned generously below roll results area.
// Uses a fixed max offset since the exact line position varies with content.
clear_button_rect :: proc() -> rl.Rectangle {
	btn := roll_button_rect()
	return rl.Rectangle{
		x      = btn.x,
		y      = btn.y + 90,
		width  = ROLL_BTN_WIDTH,
		height = ROLL_BTN_HEIGHT,
	}
}

mouse_on_clear_button :: proc(mouse_x, mouse_y: i32) -> bool {
	r := clear_button_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

// Draw HP bar
HP_BAR_WIDTH  :: 140
HP_BAR_HEIGHT :: 12

draw_hp_bar :: proc(character: ^Character, x, y: i32) {
	// Background
	rl.DrawRectangle(x, y, HP_BAR_WIDTH, HP_BAR_HEIGHT, rl.Color{40, 40, 40, 255})

	// Fill
	if character.stats.max_hp > 0 {
		fill := i32(f32(HP_BAR_WIDTH) * f32(character.stats.hp) / f32(character.stats.max_hp))
		bar_color: rl.Color
		ratio := f32(character.stats.hp) / f32(character.stats.max_hp)
		if ratio > 0.5 {
			bar_color = rl.Color{60, 180, 60, 255}
		} else if ratio > 0.25 {
			bar_color = rl.Color{220, 180, 40, 255}
		} else {
			bar_color = rl.Color{200, 50, 50, 255}
		}
		rl.DrawRectangle(x, y, fill, HP_BAR_HEIGHT, bar_color)
	}

	// Border
	rl.DrawRectangleLines(x, y, HP_BAR_WIDTH, HP_BAR_HEIGHT, rl.Color{100, 100, 100, 255})

	// Text
	hp_str := fmt.ctprintf("%d/%d", character.stats.hp, character.stats.max_hp)
	text_w := rl.MeasureText(hp_str, 10)
	rl.DrawText(hp_str, x + (HP_BAR_WIDTH - text_w) / 2, y + 1, 10, rl.WHITE)
}

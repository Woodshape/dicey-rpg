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

// Apply skull dice damage: each skull die is a separate attack.
// Looped per-hit so future per-hit triggers (passives, abilities) can hook in.
// Returns total damage dealt (after defense).
apply_skull_damage :: proc(attacker: ^Character, target: ^Character) -> int {
	if attacker.roll.skull_count <= 0 {
		return 0
	}

	damage_per_hit := max(attacker.stats.attack - target.stats.defense, 0)
	total := 0

	for _ in 0 ..< attacker.roll.skull_count {
		target.stats.hp = max(target.stats.hp - damage_per_hit, 0)
		total += damage_per_hit
	}

	return total
}

// Get the normal (non-skull) die type currently assigned to a character, if any.
character_assigned_normal_die_type :: proc(character: ^Character) -> (Die_Type, bool) {
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
	assigned_type, has_type := character_assigned_normal_die_type(character)
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

// --- Position helpers (parameterized by panel origin) ---

// Get pixel position for a die slot relative to a panel origin.
panel_slot_position :: proc(panel_x, panel_y: i32, slot_index: int) -> (i32, i32) {
	slot_stride := i32(CHAR_SLOT_SIZE + CHAR_SLOT_GAP)
	x := panel_x + i32(slot_index) * slot_stride
	y := panel_y + 80  // below name/rarity/stats
	return x, y
}

// Player-side convenience wrappers (used for hit-testing player interaction)
char_slot_position :: proc(slot_index: int) -> (i32, i32) {
	return panel_slot_position(CHAR_PANEL_X, CHAR_PANEL_Y, slot_index)
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

// Clear button: positioned generously below roll results area.
// Extra space for ability result lines.
clear_button_rect :: proc() -> rl.Rectangle {
	btn := roll_button_rect()
	return rl.Rectangle{
		x      = btn.x,
		y      = btn.y + 140,
		width  = ROLL_BTN_WIDTH,
		height = ROLL_BTN_HEIGHT,
	}
}

mouse_on_clear_button :: proc(mouse_x, mouse_y: i32) -> bool {
	r := clear_button_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

// --- Drawing (parameterized by panel position) ---

// Draw a character panel at the given position.
// interactive: true for the player (shows drag interaction, roll/clear buttons).
character_draw_at :: proc(character: ^Character, panel_x, panel_y: i32, drag: ^Drag_State, interactive: bool, name_color: rl.Color) {
	if !character_is_active(character) {
		return
	}

	// Name and rarity
	rl.DrawText(character.name, panel_x, panel_y, 20, name_color)
	rl.DrawText(RARITY_NAMES[character.rarity], panel_x, panel_y + 24, 14, rl.GRAY)

	// Stats
	hp_str := fmt.ctprintf("HP  %d", character.stats.hp)
	rl.DrawText(hp_str, panel_x, panel_y + 44, 14, rl.Color{100, 220, 100, 255})
	stats_str := fmt.ctprintf("ATK %d  DEF %d  RSV %d/%d",
		character.stats.attack, character.stats.defense,
		character.resolve, character.resolve_max)
	rl.DrawText(stats_str, panel_x, panel_y + 60, 14, rl.Color{180, 180, 180, 255})

	if character.has_rolled {
		draw_rolled_dice_at(character, panel_x, panel_y, interactive)
	} else {
		draw_assigned_dice_at(character, panel_x, panel_y, drag, interactive)

		// Roll button (only for interactive/player side)
		if interactive && character.assigned_count > 0 && !drag.active {
			mouse_x := rl.GetMouseX()
			mouse_y := rl.GetMouseY()
			draw_roll_button(mouse_x, mouse_y)
		}
	}
}

// Player-side draw (convenience wrapper)
character_draw :: proc(character: ^Character, drag: ^Drag_State) {
	character_draw_at(character, CHAR_PANEL_X, CHAR_PANEL_Y, drag, true, rl.RAYWHITE)
}

draw_assigned_dice_at :: proc(character: ^Character, panel_x, panel_y: i32, drag: ^Drag_State, interactive: bool) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	// Hover slot only matters for interactive side
	hover_slot := -1
	if interactive {
		hover_slot = mouse_to_char_slot(mouse_x, mouse_y, character.max_dice)
	}

	// Drop target highlight only for interactive side
	is_drop_target := interactive && drag.active && (drag.source == .Hand || drag.source == .Board) && character_can_assign_die(character, drag.die_type)

	for i in 0 ..< character.max_dice {
		x, y := panel_slot_position(panel_x, panel_y, i)

		if i < character.assigned_count {
			is_dragged := interactive && drag.active && drag.source == .Character && drag.index == i

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

				// Hover highlight (only when not dragging, interactive side only)
				if interactive && i == hover_slot && !drag.active {
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

draw_rolled_dice_at :: proc(character: ^Character, panel_x, panel_y: i32, interactive: bool) {
	roll := &character.roll

	for i in 0 ..< roll.count {
		x, y := panel_slot_position(panel_x, panel_y, i)
		die_type := character.assigned[i]

		if roll.skulls[i] > 0 {
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
	_, slot_y := panel_slot_position(panel_x, panel_y, 0)
	line := slot_y + CHAR_SLOT_SIZE + 10

	// Skull damage
	if roll.skull_count > 0 {
		dmg_str := fmt.ctprintf("Skull x%d -> ATK %d", roll.skull_count, character.stats.attack)
		rl.DrawText(dmg_str, panel_x, line, 14, rl.Color{200, 60, 60, 255})
		line += 18
	}

	// Match result: [MATCHES] and [VALUE]
	if roll.matched_count > 0 {
		match_str := fmt.ctprintf("Matched: %d x %d", roll.matched_count, roll.matched_value)
		rl.DrawText(match_str, panel_x, line, 16, rl.YELLOW)
		line += 18
	} else if roll.skull_count == 0 {
		rl.DrawText("No Match", panel_x, line, 16, rl.Color{180, 80, 80, 255})
		line += 18
	}

	if roll.unmatched_count > 0 {
		meter_str := fmt.ctprintf("Resolve: +%d  (%d/%d)", roll.unmatched_count, character.resolve, character.resolve_max)
		rl.DrawText(meter_str, panel_x, line, 14, rl.Color{150, 120, 220, 255})
		line += 18
	}

	// Ability result
	if character.ability_fired {
		rl.DrawText(character.ability.name, panel_x, line, 14, rl.Color{100, 200, 255, 255})
		line += 16
		if character.ability.describe != nil {
			desc := character.ability.describe(roll)
			rl.DrawText(desc, panel_x + 8, line, 12, rl.Color{140, 180, 220, 255})
			line += 14
		}
	}

	// Resolve ability fired
	if character.resolve_fired {
		resolve_str := fmt.ctprintf("RESOLVE: %s!", character.resolve_ability.name)
		rl.DrawText(resolve_str, panel_x, line, 14, rl.Color{255, 200, 50, 255})
		line += 16
		if character.resolve_ability.describe != nil {
			desc := character.resolve_ability.describe(roll)
			rl.DrawText(desc, panel_x + 8, line, 12, rl.Color{220, 180, 60, 255})
			line += 14
		}
	}

	// Clear button (player side only)
	if interactive {
		r := clear_button_rect()
		clear_x := i32(r.x)
		clear_y := i32(r.y)
		rl.DrawRectangle(clear_x, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.Color{80, 80, 80, 255})
		rl.DrawRectangleLines(clear_x, clear_y, ROLL_BTN_WIDTH, ROLL_BTN_HEIGHT, rl.GRAY)
		clear_w := rl.MeasureText("Clear", 14)
		rl.DrawText("Clear", clear_x + (ROLL_BTN_WIDTH - clear_w) / 2, clear_y + 7, 14, rl.RAYWHITE)
	}
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



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

// Get Y position for the Nth character panel on a side.
char_panel_y :: proc(char_index: int) -> i32 {
	return CHAR_PANEL_Y + i32(char_index) * CHAR_PANEL_STRIDE
}

// Get pixel position for a die slot relative to a panel origin.
panel_slot_position :: proc(panel_x, panel_y: i32, slot_index: int) -> (i32, i32) {
	slot_stride := i32(CHAR_SLOT_SIZE + CHAR_SLOT_GAP)
	x := panel_x + i32(slot_index) * slot_stride
	y := panel_y + 80  // below name/rarity/stats
	return x, y
}

// Returns the character index if mouse is over the header area (name/rarity/stats, above die slots)
// of any active character in the party. Returns -1 if no hit.
// Die slots start at panel_y+80, so the header region is panel_y to panel_y+76.
mouse_on_party_header :: proc(party: ^Party, panel_x: i32, mouse_x, mouse_y: i32) -> int {
	for ci in 0 ..< party.count {
		ch := &party.characters[ci]
		if ch.state == .Empty { continue } // allow dead characters — inspect is still useful
		py := char_panel_y(ci)
		if mouse_x >= panel_x && mouse_x < panel_x + CHAR_PANEL_WIDTH &&
		   mouse_y >= py && mouse_y < py + 76 {
			return ci
		}
	}
	return -1
}

// Check if mouse is over a die slot for a panel at (panel_x, panel_y). Returns slot index or -1.
mouse_to_char_slot_at :: proc(mouse_x, mouse_y: i32, panel_x, panel_y: i32, max_dice: int) -> int {
	for i in 0 ..< max_dice {
		x, y := panel_slot_position(panel_x, panel_y, i)
		if mouse_x >= x && mouse_x < x + CHAR_SLOT_SIZE &&
		   mouse_y >= y && mouse_y < y + CHAR_SLOT_SIZE {
			return i
		}
	}
	return -1
}

// Find which player character and slot the mouse is over.
// Returns (char_index, slot_index). Both are -1 if not over any.
mouse_to_party_char_slot :: proc(party: ^Party, panel_x: i32, mouse_x, mouse_y: i32) -> (int, int) {
	for ci in 0 ..< party.count {
		ch := &party.characters[ci]
		if !character_is_alive(ch) { continue }
		py := char_panel_y(ci)
		slot := mouse_to_char_slot_at(mouse_x, mouse_y, panel_x, py, ch.max_dice)
		if slot >= 0 {
			return ci, slot
		}
	}
	return -1, -1
}

// Roll button position for a panel at (panel_x, panel_y).
ROLL_BTN_WIDTH  :: 70
ROLL_BTN_HEIGHT :: 28

roll_button_rect_at :: proc(panel_x, panel_y: i32) -> rl.Rectangle {
	_, slot_y := panel_slot_position(panel_x, panel_y, 0)
	return rl.Rectangle {
		x      = f32(panel_x),
		y      = f32(slot_y + CHAR_SLOT_SIZE + 10),
		width  = ROLL_BTN_WIDTH,
		height = ROLL_BTN_HEIGHT,
	}
}

// Find which player character's roll button the mouse is over. Returns char_index or -1.
mouse_on_party_roll_button :: proc(party: ^Party, panel_x: i32, mouse_x, mouse_y: i32) -> int {
	for ci in 0 ..< party.count {
		ch := &party.characters[ci]
		if !character_is_alive(ch) || ch.assigned_count <= 0 || ch.has_rolled { continue }
		py := char_panel_y(ci)
		r := roll_button_rect_at(panel_x, py)
		if f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
		   f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height {
			return ci
		}
	}
	return -1
}


// --- Drawing (parameterized by panel position) ---

// Draw a character panel at the given position.
// interactive: true for the player (shows drag interaction, roll/clear buttons).
character_draw_at :: proc(character: ^Character, panel_x, panel_y: i32, drag: ^Drag_State, interactive: bool, name_color: rl.Color) {
	if character.state == .Empty {
		return
	}

	// Dead characters: show name and defeated status only
	if character.state == .Dead {
		rl.DrawText(character.name, panel_x, panel_y, 20, rl.Color{120, 60, 60, 255})
		rl.DrawText("Defeated", panel_x, panel_y + 24, 14, rl.Color{100, 50, 50, 255})
		return
	}

	// Alive: full panel
	rl.DrawText(character.name, panel_x, panel_y, 20, name_color)
	rl.DrawText(RARITY_NAMES[character.rarity], panel_x, panel_y + 24, 14, rl.GRAY)

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

		if interactive && character.assigned_count > 0 && !drag.active {
			mouse_x := rl.GetMouseX()
			mouse_y := rl.GetMouseY()
			draw_roll_button_at(panel_x, panel_y, mouse_x, mouse_y)
		}
	}
}

// Draw all characters in a party, stacked vertically.
party_draw :: proc(party: ^Party, panel_x: i32, drag: ^Drag_State, interactive: bool, name_color: rl.Color) {
	for i in 0 ..< party.count {
		py := char_panel_y(i)
		character_draw_at(&party.characters[i], panel_x, py, drag, interactive, name_color)
	}
}

draw_assigned_dice_at :: proc(character: ^Character, panel_x, panel_y: i32, drag: ^Drag_State, interactive: bool) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()

	// Hover slot only matters for interactive side
	hover_slot := -1
	if interactive {
		hover_slot = mouse_to_char_slot_at(mouse_x, mouse_y, panel_x, panel_y, character.max_dice)
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
		if roll.ability_desc[0] != 0 {
			rl.DrawText(cstring(raw_data(roll.ability_desc[:])), panel_x + 8, line, 12, rl.Color{140, 180, 220, 255})
			line += 14
		}
	}

	// Resolve ability fired
	if character.resolve_fired {
		resolve_str := fmt.ctprintf("RESOLVE: %s!", character.resolve_ability.name)
		rl.DrawText(resolve_str, panel_x, line, 14, rl.Color{255, 200, 50, 255})
		line += 16
		if roll.resolve_desc[0] != 0 {
			rl.DrawText(cstring(raw_data(roll.resolve_desc[:])), panel_x + 8, line, 12, rl.Color{220, 180, 60, 255})
			line += 14
		}
	}

}

// --- Character inspect overlay ---

// Draw one ability card (main or resolve) inside the inspect overlay.
@(private = "file")
draw_ability_panel :: proc(x, y, w, h: i32, ability: ^Ability, is_resolve: bool) {
	// Background + border
	rl.DrawRectangle(x, y, w, h, rl.Color{25, 28, 42, 200})
	border_col := rl.Color{80, 80, 120, 200}
	if is_resolve {
		border_col = rl.Color{160, 130, 30, 200}
	}
	rl.DrawRectangleLines(x, y, w, h, border_col)

	// Panel label
	label: cstring
	label_col: rl.Color
	if is_resolve {
		label = "RESOLVE"
		label_col = rl.Color{220, 180, 50, 255}
	} else {
		label = "ABILITY"
		label_col = rl.Color{120, 180, 240, 255}
	}
	rl.DrawText(label, x + 10, y + 8, 11, label_col)

	cur_y := y + 26

	// Ability name
	if ability.name != nil {
		rl.DrawText(ability.name, x + 10, cur_y, 18, rl.RAYWHITE)
		cur_y += 24
	} else {
		rl.DrawText("(none)", x + 10, cur_y, 16, rl.GRAY)
		cur_y += 22
	}

	// Scaling axis
	scaling_str: cstring
	scaling_col: rl.Color
	switch ability.scaling {
	case .Match:
		scaling_str = "[MATCHES] scaling"
		scaling_col = rl.Color{100, 200, 100, 255}
	case .Value:
		scaling_str = "[VALUE] scaling"
		scaling_col = rl.Color{210, 160, 60, 255}
	case .Hybrid:
		scaling_str = "[MATCHES] x [VALUE] scaling"
		scaling_col = rl.Color{180, 100, 230, 255}
	}
	rl.DrawText(scaling_str, x + 10, cur_y, 12, scaling_col)
	cur_y += 18

	// Min matches threshold — only shown when unusually high (>= 3).
	// Requiring >= 2 is the default for all abilities and not worth surfacing.
	if !is_resolve && ability.min_matches >= 3 {
		mm_str := fmt.ctprintf("Requires [MATCHES] >= %d", ability.min_matches)
		rl.DrawText(mm_str, x + 10, cur_y, 12, rl.Color{160, 160, 160, 255})
		cur_y += 18
	}

	// Static formula
	if ability.static_describe != nil {
		rl.DrawRectangle(x + 8, cur_y + 2, w - 16, 22, rl.Color{40, 44, 60, 220})
		rl.DrawText(ability.static_describe, x + 14, cur_y + 6, 12, rl.Color{200, 220, 255, 255})
	}
}

// Draw the full-screen character inspect overlay.
// Called from game_draw when gs.inspect_active is true.
draw_character_detail :: proc(ch: ^Character) {
	card_w: i32 = 900
	card_h: i32 = 450
	card_x: i32 = (WINDOW_WIDTH - card_w) / 2  // 190
	card_y: i32 = (WINDOW_HEIGHT - card_h) / 2 // 135

	// Portrait block (centered horizontally in the card)
	por_w: i32 = 130
	por_h: i32 = 180
	por_x: i32 = card_x + (card_w - por_w) / 2
	por_y: i32 = card_y + 80

	// Ability panels flanking the portrait
	panel_y: i32 = por_y
	panel_h: i32 = por_h
	l_x: i32 = card_x + 15
	l_w: i32 = por_x - l_x - 15
	r_x: i32 = por_x + por_w + 15
	r_w: i32 = (card_x + card_w - 15) - r_x

	// Stats row below the portrait
	stats_y: i32 = panel_y + panel_h + 16

	// Dim overlay
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 175})

	// Card background + border
	rl.DrawRectangle(card_x, card_y, card_w, card_h, rl.Color{18, 20, 32, 250})
	rl.DrawRectangleLines(card_x, card_y, card_w, card_h, rl.Color{80, 80, 130, 255})

	// Header: name
	name_w := rl.MeasureText(ch.name, 28)
	rl.DrawText(ch.name, card_x + (card_w - name_w) / 2, card_y + 14, 28, rl.RAYWHITE)

	// Header: rarity
	rar_str := RARITY_NAMES[ch.rarity]
	rar_w := rl.MeasureText(rar_str, 14)
	rl.DrawText(rar_str, card_x + (card_w - rar_w) / 2, card_y + 48, 14, rl.GRAY)

	// Header divider
	rl.DrawLine(card_x + 20, card_y + 70, card_x + card_w - 20, card_y + 70, rl.Color{60, 60, 90, 255})

	// Portrait block
	rl.DrawRectangle(por_x, por_y, por_w, por_h, rl.Color{35, 40, 65, 255})
	rl.DrawRectangleLines(por_x, por_y, por_w, por_h, rl.Color{100, 100, 170, 255})
	por_name_w := rl.MeasureText(ch.name, 14)
	rl.DrawText(ch.name, por_x + (por_w - por_name_w) / 2, por_y + por_h / 2 - 10, 14, rl.RAYWHITE)

	// Ability panels
	draw_ability_panel(l_x, panel_y, l_w, panel_h, &ch.ability, false)
	draw_ability_panel(r_x, panel_y, r_w, panel_h, &ch.resolve_ability, true)

	// Stats
	stats_str := fmt.ctprintf(
		"HP: %d  |  ATK: %d  |  DEF: %d  |  RSV: %d/%d",
		ch.stats.hp, ch.stats.attack, ch.stats.defense, ch.resolve, ch.resolve_max,
	)
	stats_w := rl.MeasureText(stats_str, 14)
	rl.DrawText(stats_str, card_x + (card_w - stats_w) / 2, stats_y, 14, rl.Color{180, 220, 180, 255})

	// Passive (placeholder — not yet wired)
	// TODO: wire passive ability system
	passive_str: cstring = "Passive: (none)"
	passive_w := rl.MeasureText(passive_str, 13)
	rl.DrawText(passive_str, card_x + (card_w - passive_w) / 2, stats_y + 22, 13, rl.Color{120, 120, 120, 255})

	// Dismiss hint
	hint: cstring = "Click anywhere to dismiss"
	hint_w := rl.MeasureText(hint, 12)
	rl.DrawText(hint, card_x + (card_w - hint_w) / 2, card_y + card_h - 22, 12, rl.Color{100, 100, 120, 255})
}

draw_roll_button_at :: proc(panel_x, panel_y, mouse_x, mouse_y: i32) {
	r := roll_button_rect_at(panel_x, panel_y)
	hovered := f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	           f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height

	bg_color := rl.Color{50, 120, 50, 255}
	if hovered {
		bg_color = rl.Color{70, 160, 70, 255}
	}

	rl.DrawRectangle(i32(r.x), i32(r.y), i32(r.width), i32(r.height), bg_color)
	rl.DrawRectangleLines(i32(r.x), i32(r.y), i32(r.width), i32(r.height), rl.Color{100, 200, 100, 255})

	text_w := rl.MeasureText("Roll", 14)
	rl.DrawText("Roll", i32(r.x) + (i32(r.width) - text_w) / 2, i32(r.y) + 7, 14, rl.WHITE)
}



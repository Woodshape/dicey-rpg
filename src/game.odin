package game

import "core:fmt"
import rl "vendor:raylib"

// Enemy panel position (right side)
ENEMY_PANEL_X :: WINDOW_WIDTH - CHAR_PANEL_X - CHAR_PANEL_WIDTH
ENEMY_PANEL_Y :: CHAR_PANEL_Y

Game_State :: struct {
	running:             bool,
	pool:                Draft_Pool,
	round:               Round_State,
	hand:                Hand,
	enemy_hand:          Hand,
	player_party:        Party,
	enemy_party:         Party,
	drag:                Drag_State,
	turn:                Turn_Phase,
	turn_timer:          f32,
	rolling_index:       int, // which character is currently showing roll results
	log:                 Combat_Log,
	// Character inspect overlay
	inspect_active:      bool,
	inspect_party_enemy: bool, // false = player party, true = enemy party
	inspect_char_index:  int,
}

game_init :: proc(encounter: string = "tutorial", prev_log: ^Combat_Log = nil, skull_chance: int = SKULL_CHANCE, pool_size: int = DEFAULT_POOL_SIZE) -> (Game_State, bool) {
	round := round_state_init(pool_size, skull_chance)
	pool := pool_generate(&round)

	gs := Game_State {
		running = true,
		pool    = pool,
		round   = round,
	}

	// Start on draft phase — player picks first in round 1
	if round.first_pick {
		gs.turn = .Draft_Player_Pick
	} else {
		gs.turn = .Draft_Enemy_Pick
	}

	// Preserve log across restarts
	if prev_log != nil {
		gs.log = prev_log^
	}
	combat_log_new_game(&gs.log)

	player_party, enemy_party, ok := config_load_encounter(encounter)
	if !ok {
		return gs, false
	}
	gs.player_party = player_party
	gs.enemy_party = enemy_party

	return gs, true
}

game_update :: proc(gs: ^Game_State) {
	input := Input_State {
		mouse_x       = rl.GetMouseX(),
		mouse_y       = rl.GetMouseY(),
		left_pressed  = rl.IsMouseButtonPressed(.LEFT),
		left_released = rl.IsMouseButtonReleased(.LEFT),
		right_pressed = rl.IsMouseButtonPressed(.RIGHT),
		delta_time    = rl.GetFrameTime(),
	}
	combat_update(gs, input)
}

// Returns the character currently selected for inspect, or nil if index is out of range.
inspect_get_character :: proc(gs: ^Game_State) -> ^Character {
	party := &gs.player_party
	if gs.inspect_party_enemy {
		party = &gs.enemy_party
	}
	if gs.inspect_char_index >= 0 && gs.inspect_char_index < party.count {
		return &party.characters[gs.inspect_char_index]
	}
	return nil
}

// Check if we're in the draft phase (pool drags allowed)
is_draft_phase :: proc(turn: Turn_Phase) -> bool {
	return turn == .Draft_Player_Pick || turn == .Draft_Enemy_Pick
}

try_start_drag :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) {
	// Pool drag (only during draft phase)
	if is_draft_phase(gs.turn) {
		slot := mouse_to_pool_slot(&gs.pool, mouse_x, mouse_y)
		if slot >= 0 {
			gs.drag = Drag_State{
				active     = true,
				source     = .Pool,
				die_type   = gs.pool.dice[slot],
				pool_index = slot,
			}
			return
		}
	}

	// Hand drag
	hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
	if hand_slot >= 0 && hand_slot < gs.hand.count {
		gs.drag = Drag_State{
			active   = true,
			source   = .Hand,
			die_type = gs.hand.dice[hand_slot],
			index    = hand_slot,
		}
		return
	}

	// Character die drag — check all player characters
	ci, slot := mouse_to_party_char_slot(&gs.player_party, CHAR_PANEL_X, mouse_x, mouse_y)
	if ci >= 0 {
		ch := &gs.player_party.characters[ci]
		if !ch.has_rolled && slot < ch.assigned_count {
			gs.drag = Drag_State {
				active     = true,
				source     = .Character,
				die_type   = ch.assigned[slot],
				index      = slot,
				char_index = ci,
			}
		}
	}
}

// Returns true if a Pick action was consumed (ends draft turn), false for free Assign moves.
try_drop :: proc(gs: ^Game_State, mouse_x, mouse_y: i32) -> bool {
	#partial switch gs.drag.source {
	case .Pool:
		// Pool drops go to hand (Pick action — ends draft turn)
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			pool_remove_die(&gs.pool, gs.drag.pool_index)
			hand_add(&gs.hand, gs.drag.die_type)
			combat_log_write(&gs.log, "You pick %s -> hand", DIE_TYPE_NAMES[gs.drag.die_type])
			return true
		}

		// Pool to character (Pick action — ends draft turn)
		ci, _ := mouse_to_party_char_slot(&gs.player_party, CHAR_PANEL_X, mouse_x, mouse_y)
		if ci >= 0 && character_can_assign_die(&gs.player_party.characters[ci], gs.drag.die_type) {
			pool_remove_die(&gs.pool, gs.drag.pool_index)
			character_assign_die(&gs.player_party.characters[ci], gs.drag.die_type)
			combat_log_write(&gs.log, "You pick %s -> %s", DIE_TYPE_NAMES[gs.drag.die_type], gs.player_party.characters[ci].name)
			return true
		}

	case .Hand:
		// Hand to character is a free Assign — check all player characters
		ci, _ := mouse_to_party_char_slot(&gs.player_party, CHAR_PANEL_X, mouse_x, mouse_y)
		if ci >= 0 && character_can_assign_die(&gs.player_party.characters[ci], gs.drag.die_type) {
			hand_remove(&gs.hand, gs.drag.index)
			character_assign_die(&gs.player_party.characters[ci], gs.drag.die_type)
		}

	case .Character:
		// Character to hand is a free Assign
		hand_slot := mouse_to_hand_slot(mouse_x, mouse_y)
		in_hand := hand_slot >= 0 || mouse_in_hand_region(mouse_x, mouse_y)
		if in_hand && !hand_is_full(&gs.hand) {
			character_unassign_die(&gs.player_party.characters[gs.drag.char_index], gs.drag.index)
			hand_add(&gs.hand, gs.drag.die_type)
		}
	}

	return false
}

game_draw :: proc(gs: ^Game_State) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.Color{30, 30, 40, 255})

	pool_draw(&gs.pool, &gs.drag)
	hand_draw(&gs.hand, &gs.drag)
	in_combat := gs.turn == .Combat_Player_Turn || gs.turn == .Player_Roll_Result
	party_draw(&gs.player_party, CHAR_PANEL_X, &gs.drag, true, rl.RAYWHITE, in_combat)
	party_draw(&gs.enemy_party, ENEMY_PANEL_X, &gs.drag, false, rl.Color{220, 100, 100, 255})
	hand_draw_at(&gs.enemy_hand, ENEMY_HAND_CENTER_X, &gs.drag, false)

	// Dragged die follows cursor
	if gs.drag.active {
		mx := rl.GetMouseX()
		my := rl.GetMouseY()
		draw_dragged_die(gs.drag.die_type, mx, my)
	}

	// HUD
	rl.DrawText("Dicey RPG", 20, 20, 24, rl.RAYWHITE)

	count_str := fmt.ctprintf("Pool: %d/%d  |  Hand: %d/%d  |  Round: %d",
		gs.pool.remaining, gs.pool.count,
		gs.hand.count, MAX_HAND_SIZE,
		gs.round.round_number,
	)
	rl.DrawText(count_str, 20, 50, 16, rl.GRAY)

	// Turn indicator
	draw_turn_indicator(gs.turn)

	// Done button during combat player turn (only when characters have dice to skip)
	if gs.turn == .Combat_Player_Turn && party_has_assigned_dice(&gs.player_party) {
		draw_done_button()
	}

	// Combat log
	combat_log_draw(&gs.log)

	// Character inspect overlay (above pool/UI, below game-over)
	if gs.inspect_active {
		ch := inspect_get_character(gs)
		if ch != nil {
			draw_character_detail(ch)
		}
	}

	// Game over overlay
	if gs.turn == .Victory || gs.turn == .Defeat {
		draw_game_over(gs.turn)
	}
}

// Draw turn phase indicator at top-centre of screen
draw_turn_indicator :: proc(turn: Turn_Phase) {
	label: cstring
	color: rl.Color

	#partial switch turn {
	case .Draft_Player_Pick:
		label = "Your Pick"
		color = rl.Color{80, 200, 80, 255}
	case .Draft_Enemy_Pick:
		label = "Enemy Pick"
		color = rl.Color{220, 80, 80, 255}
	case .Combat_Player_Turn:
		label = "Your Turn"
		color = rl.Color{80, 200, 80, 255}
	case .Player_Roll_Result:
		label = "Roll Result"
		color = rl.Color{220, 200, 60, 255}
	case .Combat_Enemy_Turn:
		label = "Enemy Turn"
		color = rl.Color{220, 80, 80, 255}
	case .Enemy_Roll_Result:
		label = "Enemy Roll"
		color = rl.Color{220, 120, 80, 255}
	case .Round_End:
		label = "Round End"
		color = rl.Color{180, 180, 100, 255}
	}

	text_w := rl.MeasureText(label, 20)
	x := (WINDOW_WIDTH - text_w) / 2
	rl.DrawText(label, x, 20, 20, color)
}

// --- Game Over ---

PLAY_AGAIN_WIDTH  :: 160
PLAY_AGAIN_HEIGHT :: 40

play_again_rect :: proc() -> rl.Rectangle {
	return rl.Rectangle {
		x      = f32(WINDOW_WIDTH / 2 - PLAY_AGAIN_WIDTH / 2),
		y      = f32(WINDOW_HEIGHT / 2 + 30),
		width  = PLAY_AGAIN_WIDTH,
		height = PLAY_AGAIN_HEIGHT,
	}
}

mouse_on_play_again :: proc(mouse_x, mouse_y: i32) -> bool {
	r := play_again_rect()
	return f32(mouse_x) >= r.x && f32(mouse_x) < r.x + r.width &&
	       f32(mouse_y) >= r.y && f32(mouse_y) < r.y + r.height
}

draw_game_over :: proc(turn: Turn_Phase) {
	// Dim overlay
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 160})

	// Result text
	label: cstring
	color: rl.Color
	if turn == .Victory {
		label = "VICTORY"
		color = rl.Color{80, 220, 80, 255}
	} else {
		label = "DEFEAT"
		color = rl.Color{220, 60, 60, 255}
	}

	text_w := rl.MeasureText(label, 48)
	rl.DrawText(label, (WINDOW_WIDTH - text_w) / 2, WINDOW_HEIGHT / 2 - 40, 48, color)

	// Play Again button
	r := play_again_rect()
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hovered := mouse_on_play_again(mouse_x, mouse_y)

	bg := rl.Color{60, 60, 80, 255}
	if hovered {
		bg = rl.Color{80, 80, 110, 255}
	}
	rl.DrawRectangle(i32(r.x), i32(r.y), i32(r.width), i32(r.height), bg)
	rl.DrawRectangleLines(i32(r.x), i32(r.y), i32(r.width), i32(r.height), rl.RAYWHITE)

	btn_label: cstring = "Play Again"
	btn_w := rl.MeasureText(btn_label, 20)
	rl.DrawText(btn_label, i32(r.x) + (i32(r.width) - btn_w) / 2, i32(r.y) + 10, 20, rl.RAYWHITE)
}

// Draw the die being dragged at the cursor position
draw_dragged_die :: proc(die_type: Die_Type, mouse_x, mouse_y: i32) {
	size :: HAND_SLOT_SIZE
	x := mouse_x - size / 2
	y := mouse_y - size / 2

	color := DIE_TYPE_COLORS[die_type]
	rl.DrawRectangle(x, y, size, size, color)
	rl.DrawRectangleLines(x, y, size, size, rl.WHITE)

	label := DIE_TYPE_NAMES[die_type]
	text_w := rl.MeasureText(label, 14)
	rl.DrawText(label, x + (size - text_w) / 2, y + (size - 14) / 2, 14, rl.WHITE)
}

// Draw the Done button — small, unobtrusive
draw_done_button :: proc() {
	r := done_button_rect()
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hovered := mouse_on_done_button(mouse_x, mouse_y)

	bg := rl.Color{45, 45, 60, 255}
	if hovered {
		bg = rl.Color{65, 65, 90, 255}
	}
	rl.DrawRectangle(i32(r.x), i32(r.y), i32(r.width), i32(r.height), bg)
	rl.DrawRectangleLines(i32(r.x), i32(r.y), i32(r.width), i32(r.height), rl.Color{100, 100, 120, 255})

	label: cstring = "Done"
	text_w := rl.MeasureText(label, 16)
	rl.DrawText(label, i32(r.x) + (i32(r.width) - text_w) / 2, i32(r.y) + 6, 16, rl.Color{160, 160, 180, 255})
}


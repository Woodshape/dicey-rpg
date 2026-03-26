package game

// AI turn logic. Called during Enemy_Turn phase.
// Decides and executes one action (pick or roll), then advances the turn.
ai_take_turn :: proc(gs: ^Game_State) {
	// Assign any compatible dice from enemy hand to character first (free)
	ai_assign_from_hand(gs)

	// Decide: roll or pick
	if ai_should_roll(gs) {
		character_roll(&gs.enemy)
		apply_skull_damage(&gs.enemy, &gs.player)
		resolve_abilities(&gs.enemy, &gs.player)
		gs.turn = .Enemy_Roll_Result
		gs.turn_timer = 0
		return
	}

	// Try to pick a die from the board
	row, col, found := ai_pick_best_die(gs)
	if found {
		die_type := gs.board.cells[row][col].die_type
		board_remove_die(&gs.board, row, col)
		hand_add(&gs.enemy_hand, die_type)
		ai_assign_from_hand(gs)
		gs.turn = .Player_Turn
		return
	}

	// No valid action — skip turn
	gs.turn = .Player_Turn
}

// Assign all compatible dice from enemy hand to enemy character.
ai_assign_from_hand :: proc(gs: ^Game_State) {
	// Iterate backwards so removal doesn't skip indices
	for i := gs.enemy_hand.count - 1; i >= 0; i -= 1 {
		die_type := gs.enemy_hand.dice[i]
		if character_can_assign_die(&gs.enemy, die_type) {
			hand_remove(&gs.enemy_hand, i)
			character_assign_die(&gs.enemy, die_type)
		}
	}
}

// Decide whether the enemy should roll (vs pick another die).
ai_should_roll :: proc(gs: ^Game_State) -> bool {
	if gs.enemy.assigned_count <= 0 {
		return false
	}
	// Roll if character is full
	if gs.enemy.assigned_count >= gs.enemy.max_dice {
		return true
	}
	// Roll if at least 2 dice and nothing left to pick
	if gs.enemy.assigned_count >= 2 && !can_pick(gs, &gs.enemy_hand) {
		return true
	}
	return false
}

// Find the best die on the board for the enemy to pick.
// Returns (row, col, found).
ai_pick_best_die :: proc(gs: ^Game_State) -> (int, int, bool) {
	if hand_is_full(&gs.enemy_hand) {
		return 0, 0, false
	}

	best_row, best_col := -1, -1
	best_score := -1

	// What type is the enemy building?
	enemy_type, enemy_has_type := character_assigned_normal_die_type(&gs.enemy)
	// What type is the player building?
	player_type, player_has_type := character_assigned_normal_die_type(&gs.player)

	for row in 0 ..< gs.board.size {
		for col in 0 ..< gs.board.size {
			if !cell_is_pickable(&gs.board, row, col) {
				continue
			}
			die_type := gs.board.cells[row][col].die_type
			score := ai_score_die(die_type, enemy_type, enemy_has_type, player_type, player_has_type)
			if score > best_score {
				best_score = score
				best_row = row
				best_col = col
			}
		}
	}

	return best_row, best_col, best_row >= 0
}

// Score a die type for the enemy AI.
// Higher score = more desirable to pick.
ai_score_die :: proc(
	die_type: Die_Type,
	enemy_type: Die_Type, enemy_has_type: bool,
	player_type: Die_Type, player_has_type: bool,
) -> int {
	score := 1  // base score for any die

	// Skull dice are always useful
	if die_type == .Skull {
		score += 5
		return score
	}

	// Strong preference for matching enemy's committed type
	if enemy_has_type && die_type == enemy_type {
		score += 10
	}

	// Moderate denial bonus for grabbing what the player is building
	if player_has_type && die_type == player_type {
		score += 4
	}

	// Slight preference for smaller dice (easier to match)
	if die_type == .D4 || die_type == .D6 {
		score += 1
	}

	return score
}

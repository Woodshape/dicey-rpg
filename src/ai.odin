package game

// AI turn logic. Called during Enemy_Turn phase.
// Decides and executes one action (pick or roll), then advances the turn.
ai_take_turn :: proc(gs: ^Game_State) {
	// Assign any compatible dice from enemy hand to character first (free)
	ai_assign_from_hand(gs)

	// Decide: roll or pick
	should_roll, roll_ci := ai_should_roll(gs)
	if should_roll {
		attacker := &gs.enemy_party.characters[roll_ci]
		target := get_target(&gs.player_party, roll_ci)
		character_roll(attacker)
		resolve_roll(gs, attacker, target)
		gs.rolling_index = roll_ci
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
		combat_log_write(&gs.log, "Enemy picks %s", DIE_TYPE_NAMES[die_type])
		ai_assign_from_hand(gs)
		gs.turn = .Player_Turn
		return
	}

	// No valid action — skip turn
	combat_log_write(&gs.log, "Enemy skips turn")
	gs.turn = .Player_Turn
}

// Assign all compatible dice from enemy hand to enemy characters.
ai_assign_from_hand :: proc(gs: ^Game_State) {
	// Iterate hand backwards so removal doesn't skip indices
	for i := gs.enemy_hand.count - 1; i >= 0; i -= 1 {
		die_type := gs.enemy_hand.dice[i]
		// Try each alive enemy character
		for ci in 0 ..< gs.enemy_party.count {
			ch := &gs.enemy_party.characters[ci]
			if ch.stats.hp <= 0 { continue }
			if character_can_assign_die(ch, die_type) {
				hand_remove(&gs.enemy_hand, i)
				character_assign_die(ch, die_type)
				break
			}
		}
	}
}

// Decide whether the enemy should roll and which character.
// Returns (should_roll, char_index).
ai_should_roll :: proc(gs: ^Game_State) -> (bool, int) {
	for ci in 0 ..< gs.enemy_party.count {
		ch := &gs.enemy_party.characters[ci]
		if ch.stats.hp <= 0 || ch.assigned_count <= 0 { continue }
		// Roll if character is full
		if ch.assigned_count >= ch.max_dice {
			return true, ci
		}
		// Roll if at least 2 dice and nothing left to pick
		if ch.assigned_count >= 2 && !can_pick(gs, &gs.enemy_hand) {
			return true, ci
		}
	}
	return false, 0
}

// Find the best die on the board for the enemy to pick.
// Returns (row, col, found).
ai_pick_best_die :: proc(gs: ^Game_State) -> (int, int, bool) {
	if hand_is_full(&gs.enemy_hand) {
		return 0, 0, false
	}

	best_row, best_col := -1, -1
	best_score := -1

	// What type is the first alive enemy building?
	enemy_type: Die_Type = .None
	enemy_has_type := false
	for ci in 0 ..< gs.enemy_party.count {
		ch := &gs.enemy_party.characters[ci]
		if ch.stats.hp <= 0 { continue }
		t, has := character_assigned_normal_die_type(ch)
		if has {
			enemy_type = t
			enemy_has_type = true
			break
		}
	}
	// What type is the first alive player building? (for denial)
	player_type: Die_Type = .None
	player_has_type := false
	for ci in 0 ..< gs.player_party.count {
		ch := &gs.player_party.characters[ci]
		if ch.stats.hp <= 0 { continue }
		t, has := character_assigned_normal_die_type(ch)
		if has {
			player_type = t
			player_has_type = true
			break
		}
	}

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

package game

// AI turn logic. Called during Enemy_Turn phase.
// Decides and executes one action (pick or roll), then advances the turn.
ai_take_turn :: proc(gs: ^Game_State) {
	// Assign any compatible dice from enemy hand to characters first (free)
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
		hand_before := gs.enemy_hand.count
		ai_assign_from_hand(gs)
		if gs.enemy_hand.count < hand_before {
			// Die was assigned — find which character got it
			assigned_to: cstring = "hand"
			for ci in 0 ..< gs.enemy_party.count {
				ch := &gs.enemy_party.characters[ci]
				if ch.stats.hp <= 0 { continue }
				// Check if this character's last assigned die matches
				if ch.assigned_count > 0 && ch.assigned[ch.assigned_count - 1] == die_type {
					assigned_to = ch.name
					break
				}
			}
			combat_log_write(&gs.log, "Enemy picks %s -> %s", DIE_TYPE_NAMES[die_type], assigned_to)
		} else {
			combat_log_write(&gs.log, "Enemy picks %s -> hand", DIE_TYPE_NAMES[die_type])
		}
		gs.turn = .Player_Turn
		return
	}

	// No useful pick — but if hand isn't full and the board has dice, pick any die
	// rather than skipping. A useless die can be discarded later; skipping wastes tempo.
	if !hand_is_full(&gs.enemy_hand) {
		row, col, any_found := ai_pick_any_die(gs)
		if any_found {
			die_type := gs.board.cells[row][col].die_type
			board_remove_die(&gs.board, row, col)
			hand_add(&gs.enemy_hand, die_type)
			ai_assign_from_hand(gs)
			combat_log_write(&gs.log, "Enemy picks %s -> hand", DIE_TYPE_NAMES[die_type])
			gs.turn = .Player_Turn
			return
		}
	}

	// Hand is full and stuck — discard an unusable die to free a slot
	if hand_is_full(&gs.enemy_hand) && !ai_hand_has_usable_die(&gs.enemy_party, &gs.enemy_hand) {
		discard_idx := ai_pick_discard(&gs.enemy_party, &gs.enemy_hand)
		if discard_idx >= 0 {
			die_type := gs.enemy_hand.dice[discard_idx]
			hand_discard(&gs.enemy_hand, discard_idx)
			combat_log_write(&gs.log, "Enemy discards %s", DIE_TYPE_NAMES[die_type])
		}
	}

	// No valid action — skip turn
	combat_log_write(&gs.log, "Enemy skips turn")
	gs.turn = .Player_Turn
}

// Assign all compatible dice from enemy hand to enemy characters.
// Prefers the character with fewer assigned dice (load balance).
// Within tied counts, prefers the character whose committed type matches.
ai_assign_from_hand :: proc(gs: ^Game_State) {
	for i := gs.enemy_hand.count - 1; i >= 0; i -= 1 {
		die_type := gs.enemy_hand.dice[i]

		best_ci := -1
		best_score := -1

		for ci in 0 ..< gs.enemy_party.count {
			ch := &gs.enemy_party.characters[ci]
			if ch.stats.hp <= 0 {continue}
			if !character_can_assign_die(ch, die_type) {continue}

			// Score: prefer fewer assigned dice (more room), prefer type match
			score := (ch.max_dice - ch.assigned_count) * 10
			assigned_type, has_type := character_assigned_normal_die_type(ch)
			if has_type && die_type_is_normal(die_type) && assigned_type == die_type {
				score += 20 // strong preference for matching type
			}
			if score > best_score {
				best_score = score
				best_ci = ci
			}
		}

		if best_ci >= 0 {
			hand_remove(&gs.enemy_hand, i)
			character_assign_die(&gs.enemy_party.characters[best_ci], die_type)
		}
	}
}

// Decide whether the enemy should roll and which character.
// Only rolls if the character has >= 2 normal (non-skull) dice assigned, OR is completely full.
// Also rolls if there are no useful dice left to pick (prevents infinite skipping).
// Returns (should_roll, char_index).
ai_should_roll :: proc(gs: ^Game_State) -> (bool, int) {
	// Check if any useful dice can be picked from the board
	_, _, has_useful_pick := ai_pick_best_die(gs)

	for ci in 0 ..< gs.enemy_party.count {
		ch := &gs.enemy_party.characters[ci]
		if ch.stats.hp <= 0 || ch.assigned_count <= 0 {continue}

		// Roll if character is full
		if ch.assigned_count >= ch.max_dice {
			return true, ci
		}

		// Count normal (non-skull) dice
		normal_count := 0
		for di in 0 ..< ch.assigned_count {
			if die_type_is_normal(ch.assigned[di]) {
				normal_count += 1
			}
		}

		// Roll if at least 2 normal dice and nothing useful to pick
		if normal_count >= 2 && !has_useful_pick {
			return true, ci
		}
	}
	return false, 0
}

// Find the best die on the board for the enemy to pick.
// Scores each (die, character) pair and picks the best overall.
// Returns (row, col, found).
ai_pick_best_die :: proc(gs: ^Game_State) -> (int, int, bool) {
	if hand_is_full(&gs.enemy_hand) {
		return 0, 0, false
	}

	best_row, best_col := -1, -1
	best_score := 0  // skip dice that score 0 (no character can use them)

	// Collect player types for denial scoring
	player_types: [MAX_PARTY_SIZE]Die_Type
	player_type_count := 0
	for ci in 0 ..< gs.player_party.count {
		ch := &gs.player_party.characters[ci]
		if ch.stats.hp <= 0 {continue}
		t, has := character_assigned_normal_die_type(ch)
		if has {
			player_types[player_type_count] = t
			player_type_count += 1
		}
	}

	for row in 0 ..< gs.board.size {
		for col in 0 ..< gs.board.size {
			if !cell_is_pickable(&gs.board, row, col) {
				continue
			}
			die_type := gs.board.cells[row][col].die_type

			// Score this die against each alive enemy character, take the best
			score := ai_score_die_for_party(
				die_type,
				&gs.enemy_party,
				player_types[:player_type_count],
			)

			if score > best_score {
				best_score = score
				best_row = row
				best_col = col
			}
		}
	}

	return best_row, best_col, best_row >= 0
}

// Score a die type considering all alive enemy characters.
// Returns the best score across all characters that could use this die.
// Returns 0 if no character can accept this die — prevents hand clogging.
ai_score_die_for_party :: proc(
	die_type: Die_Type,
	enemy_party: ^Party,
	player_types: []Die_Type,
) -> int {
	// Denial bonus: does any player character want this type?
	denial := 0
	for pt in player_types {
		if die_type_is_normal(die_type) && pt == die_type {
			denial = 4
			break
		}
	}

	// Check if any alive character can accept this die
	any_can_accept := false
	for ci in 0 ..< enemy_party.count {
		ch := &enemy_party.characters[ci]
		if ch.stats.hp <= 0 { continue }
		if character_can_assign_die(ch, die_type) {
			any_can_accept = true
			break
		}
	}

	// Don't pick dice no one can use — returns 0 to prevent hand clogging
	if !any_can_accept {
		return 0
	}

	// Skull dice: moderate bonus, useful for any character
	if die_type == .Skull {
		return 1 + 2 + denial
	}

	// Score against each alive enemy character
	best := 0
	for ci in 0 ..< enemy_party.count {
		ch := &enemy_party.characters[ci]
		if ch.stats.hp <= 0 { continue }
		if !character_can_assign_die(ch, die_type) { continue }

		score := 1 + denial

		// Strong preference for matching committed type
		assigned_type, has_type := character_assigned_normal_die_type(ch)
		if has_type && assigned_type == die_type {
			score += 10
		}

		// Moderate bonus for a character with no type yet (first normal die)
		if !has_type {
			score += 3
		}

		// Slight preference for smaller dice (easier to match)
		if die_type == .D4 || die_type == .D6 {
			score += 1
		}

		if score > best {
			best = score
		}
	}

	return best
}

// Keep the old standalone scorer for tests that call it directly.
ai_score_die :: proc(
	die_type: Die_Type,
	enemy_type: Die_Type,
	enemy_has_type: bool,
	player_type: Die_Type,
	player_has_type: bool,
) -> int {
	score := 1

	if die_type == .Skull {
		score += 2
		if player_has_type {
			score += 4
		}
		return score
	}

	if enemy_has_type && die_type == enemy_type {
		score += 10
	}

	if player_has_type && die_type == player_type {
		score += 4
	}

	if die_type == .D4 || die_type == .D6 {
		score += 1
	}

	return score
}

// Fallback: pick any pickable die from the board (no scoring).
// Used when ai_pick_best_die finds nothing useful but the AI shouldn't skip.
ai_pick_any_die :: proc(gs: ^Game_State) -> (int, int, bool) {
	for row in 0 ..< gs.board.size {
		for col in 0 ..< gs.board.size {
			if cell_is_pickable(&gs.board, row, col) {
				return row, col, true
			}
		}
	}
	return 0, 0, false
}

// Check if any die in the hand can be assigned to any alive character.
ai_hand_has_usable_die :: proc(party: ^Party, hand: ^Hand) -> bool {
	for i in 0 ..< hand.count {
		for ci in 0 ..< party.count {
			ch := &party.characters[ci]
			if ch.stats.hp <= 0 {continue}
			if character_can_assign_die(ch, hand.dice[i]) {
				return true
			}
		}
	}
	return false
}

// Pick the least useful die in the enemy hand to discard.
// Returns the index to discard, or -1 if no die can be discarded.
// Prefers dice that no alive character can accept.
ai_pick_discard :: proc(party: ^Party, hand: ^Hand) -> int {
	worst_idx := -1
	worst_score := max(int) // lower = more discardable

	for i in 0 ..< hand.count {
		if !hand_can_discard(hand, i) {
			continue
		}

		die_type := hand.dice[i]
		score := 0

		// Check if any alive character can use this die
		for ci in 0 ..< party.count {
			ch := &party.characters[ci]
			if ch.stats.hp <= 0 {continue}
			if character_can_assign_die(ch, die_type) {
				score += 10 // useful die — less desirable to discard
			}
		}

		if score < worst_score {
			worst_score = score
			worst_idx = i
		}
	}

	return worst_idx
}

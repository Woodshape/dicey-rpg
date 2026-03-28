package game

// --- Draft Phase AI ---

// AI picks the best die from the pool during Draft_Enemy_Pick.
// Picks, assigns from hand, and advances the turn phase.
ai_draft_pick :: proc(gs: ^Game_State) {
	// Assign any compatible dice from enemy hand first (free)
	ai_assign_from_hand(gs)

	idx, found := ai_pick_best_pool_die(gs)
	if !found {
		// Pool is empty or hand is full — should not happen during draft, but handle gracefully
		if pool_is_empty(&gs.pool) {
			gs.turn = .Combat_Enemy_Turn
		} else {
			// Hand full — discard to make room, then try again next frame
			if hand_is_full(&gs.enemy_hand) {
				discard_idx := ai_pick_discard(&gs.enemy_party, &gs.enemy_hand)
				if discard_idx >= 0 {
					die_type := gs.enemy_hand.dice[discard_idx]
					hand_discard(&gs.enemy_hand, discard_idx)
					combat_log_write(&gs.log, "Enemy discards %s", DIE_TYPE_NAMES[die_type])
				}
			}
			// Pick any die as fallback
			if !hand_is_full(&gs.enemy_hand) && !pool_is_empty(&gs.pool) {
				die_type, ok := pool_remove_die(&gs.pool, 0)
				if ok {
					hand_add(&gs.enemy_hand, die_type)
					ai_assign_from_hand(gs)
					combat_log_write(&gs.log, "Enemy picks %s -> hand", DIE_TYPE_NAMES[die_type])
				}
			}
		}
	} else {
		die_type, ok := pool_remove_die(&gs.pool, idx)
		if ok {
			hand_add(&gs.enemy_hand, die_type)
			hand_before := gs.enemy_hand.count
			ai_assign_from_hand(gs)
			if gs.enemy_hand.count < hand_before {
				assigned_to: cstring = "hand"
				for ci in 0 ..< gs.enemy_party.count {
					ch := &gs.enemy_party.characters[ci]
					if !character_is_alive(ch) { continue }
					if ch.assigned_count > 0 && ch.assigned[ch.assigned_count - 1] == die_type {
						assigned_to = ch.name
						break
					}
				}
				combat_log_write(&gs.log, "Enemy picks %s -> %s", DIE_TYPE_NAMES[die_type], assigned_to)
			} else {
				combat_log_write(&gs.log, "Enemy picks %s -> hand", DIE_TYPE_NAMES[die_type])
			}
		}
	}

	// Advance phase
	if pool_is_empty(&gs.pool) {
		// Draft complete — enter combat phase
		// First combat turn goes to player if player picked first this round, enemy otherwise
		if gs.round.first_pick {
			gs.turn = .Combat_Player_Turn
		} else {
			gs.turn = .Combat_Enemy_Turn
		}
	} else {
		gs.turn = .Draft_Player_Pick
	}
}

// --- Combat Phase AI ---

// AI assigns dice and rolls characters one at a time.
// When nothing left to roll, advances to Round_End.
ai_combat_turn :: proc(gs: ^Game_State) {
	ai_assign_from_hand(gs)

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

	// Discard unusable dice if stuck
	if hand_is_full(&gs.enemy_hand) && !ai_hand_has_usable_die(&gs.enemy_party, &gs.enemy_hand) {
		discard_idx := ai_pick_discard(&gs.enemy_party, &gs.enemy_hand)
		if discard_idx >= 0 {
			die_type := gs.enemy_hand.dice[discard_idx]
			hand_discard(&gs.enemy_hand, discard_idx)
			combat_log_write(&gs.log, "Enemy discards %s", DIE_TYPE_NAMES[die_type])
		}
	}

	// Nothing left to roll — end the round
	gs.turn = .Round_End
}

// --- Shared AI Logic ---

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
			if !character_is_alive(ch) {continue}
			if !character_can_assign_die(ch, die_type) {continue}

			// Score: prefer fewer assigned dice (more room), prefer type match, prefer scaling fit
			score := (ch.max_dice - ch.assigned_count) * 10
			assigned_type, has_type := character_assigned_normal_die_type(ch)
			if has_type && die_type_is_normal(die_type) && assigned_type == die_type {
				score += 20 // strong preference for matching type
			}
			// Route dice to characters whose abilities benefit from this die type
			score += ai_scaling_fit(ch.ability.scaling, die_type) * 2
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
// In the combat phase, drafting is already complete — roll any character with >= 2 normal dice.
// Returns (should_roll, char_index).
ai_should_roll :: proc(gs: ^Game_State) -> (bool, int) {
	for ci in 0 ..< gs.enemy_party.count {
		ch := &gs.enemy_party.characters[ci]
		if !character_is_alive(ch) || ch.assigned_count <= 0 {continue}

		// Count normal (non-skull) dice
		normal_count := 0
		for di in 0 ..< ch.assigned_count {
			if die_type_is_normal(ch.assigned[di]) {
				normal_count += 1
			}
		}

		// Roll if character has at least 2 normal dice
		if normal_count >= 2 {
			return true, ci
		}

		// Roll if character is full (even skulls-only — skull damage is better than nothing)
		if ch.assigned_count >= ch.max_dice {
			return true, ci
		}
	}
	return false, 0
}

// Find the best die in the pool for the enemy to pick.
// Scores each die against all enemy characters and picks the best overall.
// Returns (pool_index, found).
ai_pick_best_pool_die :: proc(gs: ^Game_State) -> (int, bool) {
	if hand_is_full(&gs.enemy_hand) {
		return 0, false
	}

	best_idx := -1
	best_score := 0 // skip dice that score 0 (no character can use them)

	// Collect player types for denial scoring
	player_types: [MAX_PARTY_SIZE]Die_Type
	player_type_count := 0
	for ci in 0 ..< gs.player_party.count {
		ch := &gs.player_party.characters[ci]
		if !character_is_alive(ch) {continue}
		t, has := character_assigned_normal_die_type(ch)
		if has {
			player_types[player_type_count] = t
			player_type_count += 1
		}
	}

	for i in 0 ..< gs.pool.remaining {
		die_type := gs.pool.dice[i]

		score := ai_score_die_for_party(
			die_type,
			&gs.enemy_party,
			player_types[:player_type_count],
		)

		if score > best_score {
			best_score = score
			best_idx = i
		}
	}

	return best_idx, best_idx >= 0
}

// How well does a die type fit a character's ability scaling axis?
// Match-scaling wants small dice (d4/d6), value-scaling wants big dice (d10/d12),
// hybrid wants mid-range (d6/d8). Returns 0-5.
ai_scaling_fit :: proc(scaling: Ability_Scaling, die_type: Die_Type) -> int {
	if !die_type_is_normal(die_type) {return 0}
	switch scaling {
	case .Match:
		switch die_type {
		case .D4:  return 5
		case .D6:  return 3
		case .D8:  return 1
		case .D10, .D12: return 0
		case .None, .Skull: return 0
		}
	case .Value:
		switch die_type {
		case .D12: return 5
		case .D10: return 3
		case .D8:  return 1
		case .D4, .D6: return 0
		case .None, .Skull: return 0
		}
	case .Hybrid:
		switch die_type {
		case .D6, .D8: return 4
		case .D4, .D10: return 2
		case .D12: return 1
		case .None, .Skull: return 0
		}
	case .None:
		return 0
	}
	return 0
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
		if !character_is_alive(ch) { continue }
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
		if !character_is_alive(ch) { continue }
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

		// Ability-aware preference: score by how well this die fits the character's scaling
		score += ai_scaling_fit(ch.ability.scaling, die_type)

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

// Check if any die in the hand can be assigned to any alive character.
ai_hand_has_usable_die :: proc(party: ^Party, hand: ^Hand) -> bool {
	for i in 0 ..< hand.count {
		for ci in 0 ..< party.count {
			ch := &party.characters[ci]
			if !character_is_alive(ch) {continue}
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
			if !character_is_alive(ch) {continue}
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

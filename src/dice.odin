package game

import "core:math/rand"

// Roll a single die, returning a value from 1 to faces.
roll_die :: proc(die_type: Die_Type) -> int {
	assert(die_type_is_normal(die_type), "can only roll normal dice")
	faces := DIE_FACES[die_type]
	return rand.int_max(faces) + 1
}

// Roll all assigned dice on a character and detect matches.
// Skull dice are separated from normal dice: skulls count attacks,
// normal dice are evaluated for match patterns.
character_roll :: proc(character: ^Character) {
	assert(character.assigned_count > 0, "cannot roll with no assigned dice")

	result: Roll_Result
	result.count = character.assigned_count

	// Separate skull and normal dice, roll normal dice
	normal_values: [MAX_CHARACTER_DICE]int
	normal_count := 0

	for i in 0 ..< character.assigned_count {
		if character.assigned[i] == .Skull {
			result.skulls[i] = 1	// 1 if this die is a skull (for now, we can think of even bigger skull dice that have a different value)
			result.skull_count += 1
		} else {
			val := roll_die(character.assigned[i])
			result.values[i] = val
			normal_values[normal_count] = val
			normal_count += 1
		}
	}

	// Detect matches on normal dice only
	if normal_count > 0 {
		match_result := detect_match(normal_values[:normal_count])

		result.matched_value = match_result.matched_value

		// Map matched flags back to full array (skipping skull slots)
		normal_idx := 0
		for i in 0 ..< result.count {
			if result.skulls[i] == 0 {
				result.matched[i] = match_result.matched[normal_idx]
				if result.matched[i] {
					result.matched_count += 1
				} else {
					result.unmatched_count += 1
				}
				normal_idx += 1
			}
		}
	}

	assert(result.matched_count + result.unmatched_count + result.skull_count == result.count, "matched, unmatched, and skull dice must add up to the total roll")

	character.roll = result
	character.has_rolled = true
}

// Clear roll state and consume assigned dice.
character_clear_roll :: proc(character: ^Character) {
	character.has_rolled = false
	character.roll = {}
	character.assigned_count = 0
	for i in 0 ..< MAX_CHARACTER_DICE {
		character.assigned[i] = {}
	}
	// Clear ability resolution state
	character.ability_fired = false
	character.resolve_fired = false
}

// Detect matches from rolled values. Returns [MATCHES], [VALUE], and per-die flags.
// Pure function — no side effects, no randomness.
// Only receives normal dice values (no skull dice).
detect_match :: proc(values: []int) -> Roll_Result {
	result: Roll_Result
	result.count = len(values)
	for i in 0 ..< result.count {
		result.values[i] = values[i]
	}

	// Count frequency of each value
	freq: [MAX_DIE_VALUE + 1]int
	for i in 0 ..< result.count {
		freq[values[i]] += 1
	}

	// Find the highest frequency (tie-break by higher value) for [VALUE]
	best_freq, best_val := 0, 0

	for val in 1 ..= MAX_DIE_VALUE {
		f := freq[val]
		if f <= 0 {
			continue
		}
		if f > best_freq || (f == best_freq && val > best_val) {
			best_freq = f
			best_val = val
		}
	}

	// [VALUE] = face value of the best match group
	result.matched_value = best_val

	// [MATCHES] = count of all dice in any match group (freq >= 2).
	// Multiple groups are additive: two pairs gives [MATCHES]=4.
	for i in 0 ..< result.count {
		if freq[values[i]] >= 2 {
			result.matched[i] = true
			result.matched_count += 1
		} else {
			result.unmatched_count += 1
		}
	}

	assert(result.matched_count + result.unmatched_count == result.count, "normal matched and unmatched dice must add up to the total roll")

	return result
}

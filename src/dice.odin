package game

import "core:math/rand"

// Roll a single die, returning a value from 1 to faces.
roll_die :: proc(die_type: Die_Type) -> int {
	assert(die_type != .None, "cannot roll Die_Type.None")
	faces := DIE_FACES[die_type]
	return rand.int_max(faces) + 1
}

// Roll all assigned dice on a character and detect matches.
character_roll :: proc(character: ^Character) {
	assert(character.assigned_count > 0, "cannot roll with no assigned dice")

	result: Roll_Result
	result.count = character.assigned_count

	// Roll each die
	for i in 0 ..< character.assigned_count {
		result.values[i] = roll_die(character.assigned[i])
	}

	// Detect matches
	result = detect_match(result.values[:result.count])

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
}

// Detect the best match pattern from rolled values.
// Pure function — no side effects, no randomness.
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

	// Find the two highest frequencies (tie-break by higher value)
	best_freq, best_val := 0, 0
	second_freq, second_val := 0, 0

	for val in 1 ..= MAX_DIE_VALUE {
		f := freq[val]
		if f <= 0 {
			continue
		}
		if f > best_freq || (f == best_freq && val > best_val) {
			second_freq = best_freq
			second_val = best_val
			best_freq = f
			best_val = val
		} else if f > second_freq || (f == second_freq && val > second_val) {
			second_freq = f
			second_val = val
		}
	}

	// Determine pattern from top two frequencies
	if best_freq >= 5 {
		result.pattern = .Five_Of_A_Kind
	} else if best_freq == 4 {
		result.pattern = .Four_Of_A_Kind
	} else if best_freq == 3 && second_freq >= 2 {
		result.pattern = .Full_House
	} else if best_freq == 3 {
		result.pattern = .Three_Of_A_Kind
	} else if best_freq == 2 && second_freq == 2 {
		result.pattern = .Two_Pairs
	} else if best_freq == 2 {
		result.pattern = .Pair
	} else {
		result.pattern = .None
	}

	// Matched value is the value of the best (largest) match group
	result.matched_value = best_val

	// Mark matched/unmatched dice.
	// A die is "matched" if its value appears at least twice.
	for i in 0 ..< result.count {
		if freq[values[i]] >= 2 {
			result.matched[i] = true
			result.matched_count += 1
		} else {
			result.unmatched_count += 1
		}
	}

	assert(result.matched_count + result.unmatched_count == result.count)

	return result
}

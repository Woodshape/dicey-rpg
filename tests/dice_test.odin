package tests

import "core:testing"
import game "../src"

// Invariant: matched + unmatched must equal the number of dice rolled, not the array size.
expect_counts_equal_total :: proc(t: ^testing.T, result: game.Roll_Result) {
	total := result.matched_count + result.unmatched_count
	testing.expectf(t, total == result.count,
		"matched_count (%d) + unmatched_count (%d) = %d, expected count (%d)",
		result.matched_count, result.unmatched_count, total, result.count)
}

// --- Match detection: each pattern ---

@(test)
match_no_match :: proc(t: ^testing.T) {
	result := game.detect_match({1, 3, 5, 7, 9})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.None)
	testing.expect_value(t, result.matched_count, 0)
	testing.expect_value(t, result.unmatched_count, 5)

	// All dice should be unmatched
	for i in 0 ..< result.count {
		testing.expectf(t, !result.matched[i], "die %d should be unmatched", i)
	}
}

@(test)
match_pair :: proc(t: ^testing.T) {
	result := game.detect_match({3, 7, 3, 11, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Pair)
	testing.expect_value(t, result.matched_value, 3)
	testing.expect_value(t, result.matched_count, 2)
	testing.expect_value(t, result.unmatched_count, 3)
}

@(test)
match_pair_highest_value_wins :: proc(t: ^testing.T) {
	// Two possible pairs (2s and 9s) — but this is Two Pairs, not Pair
	// Single pair where value matters
	result := game.detect_match({9, 1, 9, 3, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Pair)
	testing.expect_value(t, result.matched_value, 9)
}

@(test)
match_two_pairs :: proc(t: ^testing.T) {
	result := game.detect_match({3, 7, 3, 7, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Two_Pairs)
	testing.expect_value(t, result.matched_count, 4)
	testing.expect_value(t, result.unmatched_count, 1)  // the 5 is unmatched

	// Both pairs' dice should be marked as matched
	testing.expect(t, result.matched[0], "first 3 should be matched")
	testing.expect(t, result.matched[1], "first 7 should be matched")
	testing.expect(t, result.matched[2], "second 3 should be matched")
	testing.expect(t, result.matched[3], "second 7 should be matched")
	testing.expect(t, !result.matched[4], "5 should be unmatched")
}

@(test)
match_three_of_a_kind :: proc(t: ^testing.T) {
	result := game.detect_match({4, 4, 4, 8, 2})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Three_Of_A_Kind)
	testing.expect_value(t, result.matched_value, 4)
	testing.expect_value(t, result.matched_count, 3)
	testing.expect_value(t, result.unmatched_count, 2)
}

@(test)
match_full_house :: proc(t: ^testing.T) {
	result := game.detect_match({3, 3, 3, 7, 7})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Full_House)
	testing.expect_value(t, result.matched_value, 3)  // triple's value
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)

	// All dice matched
	for i in 0 ..< result.count {
		testing.expectf(t, result.matched[i], "die %d should be matched in full house", i)
	}
}

@(test)
match_four_of_a_kind :: proc(t: ^testing.T) {
	result := game.detect_match({6, 6, 6, 6, 2})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Four_Of_A_Kind)
	testing.expect_value(t, result.matched_value, 6)
	testing.expect_value(t, result.matched_count, 4)
	testing.expect_value(t, result.unmatched_count, 1)
}

@(test)
match_five_of_a_kind :: proc(t: ^testing.T) {
	result := game.detect_match({5, 5, 5, 5, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Five_Of_A_Kind)
	testing.expect_value(t, result.matched_value, 5)
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- Match detection: edge cases ---

@(test)
match_minimum_hand_pair :: proc(t: ^testing.T) {
	// Common character: only 3 dice
	result := game.detect_match({2, 2, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Pair)
	testing.expect_value(t, result.matched_value, 2)
	testing.expect_value(t, result.unmatched_count, 1)
}

@(test)
match_minimum_hand_triple :: proc(t: ^testing.T) {
	result := game.detect_match({3, 3, 3})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Three_Of_A_Kind)
	testing.expect_value(t, result.matched_value, 3)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_minimum_hand_no_match :: proc(t: ^testing.T) {
	result := game.detect_match({1, 2, 3})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.None)
	testing.expect_value(t, result.unmatched_count, 3)
}

@(test)
match_six_dice_five_of_a_kind :: proc(t: ^testing.T) {
	// Legendary: 6 dice, 5+ of same value caps at Five_Of_A_Kind
	result := game.detect_match({7, 7, 7, 7, 7, 7})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Five_Of_A_Kind)
	testing.expect_value(t, result.matched_value, 7)
	testing.expect_value(t, result.matched_count, 6)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_six_dice_full_house :: proc(t: ^testing.T) {
	// Double triple (3+3) evaluates as Full House
	result := game.detect_match({2, 2, 2, 8, 8, 8})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Full_House)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_six_dice_three_pairs_is_two_pairs :: proc(t: ^testing.T) {
	// Three pairs (2+2+2) — best pattern is Two Pairs
	result := game.detect_match({1, 1, 4, 4, 9, 9})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Two_Pairs)
	// All dice are in pairs, so all matched
	testing.expect_value(t, result.matched_count, 6)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- Matched value tie-breaking ---

@(test)
match_value_higher_value_wins_tie :: proc(t: ^testing.T) {
	// Two triples: 3s and 8s — 8 has higher value
	result := game.detect_match({3, 8, 3, 8, 3, 8})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.pattern, game.Match_Pattern.Full_House)
	testing.expect_value(t, result.matched_value, 8)  // higher value triple wins
}

// --- Unmatched counting ---

@(test)
match_all_unmatched_feeds_super_meter :: proc(t: ^testing.T) {
	result := game.detect_match({1, 2, 3, 4, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 0)
	testing.expect_value(t, result.unmatched_count, 5)
}

@(test)
match_full_house_zero_unmatched :: proc(t: ^testing.T) {
	result := game.detect_match({10, 10, 10, 4, 4})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- Vacated slot integrity ---

@(test)
roll_result_cleared_properly :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common)
	game.character_assign(&ch, .D8)
	game.character_assign(&ch, .D8)
	game.character_assign(&ch, .D8)

	game.character_roll(&ch)
	testing.expect(t, ch.has_rolled, "should be rolled")
	testing.expect_value(t, ch.roll.count, 3)

	game.character_clear_roll(&ch)
	testing.expect(t, !ch.has_rolled, "should not be rolled after clear")
	testing.expect_value(t, ch.roll.count, 0)
	testing.expect_value(t, ch.assigned_count, 0)

	// Assigned dice should be cleared
	for i in 0 ..< game.MAX_CHARACTER_DICE {
		testing.expectf(t, ch.assigned[i] == .None, "assigned slot %d should be .None after clear, got %v", i, ch.assigned[i])
	}
}

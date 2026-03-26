package tests

import "core:testing"
import game "../src"

// Invariant: matched + unmatched + skull must equal the number of dice rolled.
expect_counts_equal_total :: proc(t: ^testing.T, result: game.Roll_Result) {
	total := result.matched_count + result.unmatched_count + result.skull_count
	testing.expectf(t, total == result.count,
		"matched(%d) + unmatched(%d) + skull(%d) = %d, expected count(%d)",
		result.matched_count, result.unmatched_count, result.skull_count, total, result.count)
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
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})
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

// --- Skull dice ---

@(test)
skull_exempt_from_pure_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})

	// Assign a normal die first
	game.character_assign(&ch, .D8)

	// Skull should be accepted alongside D8
	testing.expect(t, game.character_can_assign(&ch, .Skull), "skull should be compatible with any normal type")
	ok := game.character_assign(&ch, .Skull)
	testing.expect(t, ok, "skull assignment should succeed")
	testing.expect_value(t, ch.assigned_count, 2)

	// Another D8 should still be accepted
	testing.expect(t, game.character_can_assign(&ch, .D8), "D8 should still be accepted alongside skull")
}

@(test)
skull_only_hand_is_valid :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})

	// All skulls should be fine
	game.character_assign(&ch, .Skull)
	game.character_assign(&ch, .Skull)
	testing.expect_value(t, ch.assigned_count, 2)

	// Normal die should be accepted after skulls
	testing.expect(t, game.character_can_assign(&ch, .D12), "normal die should be accepted after only skulls")
}

@(test)
skull_does_not_set_normal_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})

	game.character_assign(&ch, .Skull)

	// assigned_type should return None (no normal type set)
	_, has_type := game.character_assigned_type(&ch)
	testing.expect(t, !has_type, "skull-only character should have no normal assigned type")

	// Should accept any normal type
	testing.expect(t, game.character_can_assign(&ch, .D4), "should accept D4")
	testing.expect(t, game.character_can_assign(&ch, .D12), "should accept D12")
}

@(test)
skull_mixed_type_rejected :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})

	game.character_assign(&ch, .D6)
	game.character_assign(&ch, .Skull)

	// Different normal type should still be rejected
	testing.expect(t, !game.character_can_assign(&ch, .D10), "different normal type should be rejected even with skull present")
}

@(test)
skull_roll_mixed :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})
	game.character_assign(&ch, .Skull)
	game.character_assign(&ch, .D6)
	game.character_assign(&ch, .D6)

	game.character_roll(&ch)

	testing.expect_value(t, ch.roll.count, 3)
	testing.expect_value(t, ch.roll.skull_count, 1)
	testing.expect(t, ch.roll.is_skull[0], "first die should be skull")
	testing.expect(t, !ch.roll.is_skull[1], "second die should not be skull")
	testing.expect(t, !ch.roll.is_skull[2], "third die should not be skull")

	// Invariant: matched + unmatched + skull == count
	total := ch.roll.matched_count + ch.roll.unmatched_count + ch.roll.skull_count
	testing.expect_value(t, total, ch.roll.count)

	// Skull values should be 0
	testing.expect_value(t, ch.roll.values[0], 0)
	// Normal values should be 1-6
	testing.expect(t, ch.roll.values[1] >= 1 && ch.roll.values[1] <= 6, "D6 value should be 1-6")
	testing.expect(t, ch.roll.values[2] >= 1 && ch.roll.values[2] <= 6, "D6 value should be 1-6")
}

@(test)
skull_roll_all_skulls :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, max_hp = 20, attack = 3, defense = 1})
	game.character_assign(&ch, .Skull)
	game.character_assign(&ch, .Skull)
	game.character_assign(&ch, .Skull)

	game.character_roll(&ch)

	testing.expect_value(t, ch.roll.skull_count, 3)
	testing.expect_value(t, ch.roll.matched_count, 0)
	testing.expect_value(t, ch.roll.unmatched_count, 0)
	testing.expect_value(t, ch.roll.pattern, game.Match_Pattern.None)
}

// --- Skull damage ---

@(test)
skull_damage_calculation :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, max_hp = 20, attack = 5, defense = 0})
	target := game.character_create("Target", .Common, {hp = 20, max_hp = 20, attack = 2, defense = 1})

	// Simulate a roll with 2 skull dice
	attacker.has_rolled = true
	attacker.roll.skull_count = 2

	dmg := game.apply_skull_damage(&attacker, &target)

	// damage per hit = attack(5) - defense(1) = 4, x2 skulls = 8
	testing.expect_value(t, dmg, 8)
	testing.expect_value(t, target.stats.hp, 12)  // 20 - 8
}

@(test)
skull_damage_respects_defense :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, max_hp = 20, attack = 2, defense = 0})
	target := game.character_create("Tank", .Common, {hp = 20, max_hp = 20, attack = 1, defense = 5})

	attacker.has_rolled = true
	attacker.roll.skull_count = 3

	dmg := game.apply_skull_damage(&attacker, &target)

	// damage per hit = attack(2) - defense(5) = 0 (clamped), x3 = 0
	testing.expect_value(t, dmg, 0)
	testing.expect_value(t, target.stats.hp, 20)
}

@(test)
skull_damage_cannot_go_below_zero_hp :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, max_hp = 20, attack = 10, defense = 0})
	target := game.character_create("Weak", .Common, {hp = 5, max_hp = 5, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.skull_count = 3

	game.apply_skull_damage(&attacker, &target)

	// damage = 10 x 3 = 30, but HP floors at 0
	testing.expect_value(t, target.stats.hp, 0)
}

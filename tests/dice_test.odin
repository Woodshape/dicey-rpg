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

// --- Match detection: [MATCHES] and [VALUE] ---

@(test)
match_no_match :: proc(t: ^testing.T) {
	result := game.detect_match({1, 3, 5, 7, 9})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 0)
	testing.expect_value(t, result.unmatched_count, 5)

	for i in 0 ..< result.count {
		testing.expectf(t, !result.matched[i], "die %d should be unmatched", i)
	}
}

@(test)
match_pair :: proc(t: ^testing.T) {
	result := game.detect_match({3, 7, 3, 11, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 3)
	testing.expect_value(t, result.matched_count, 2)
	testing.expect_value(t, result.unmatched_count, 3)
}

@(test)
match_pair_highest_value_wins :: proc(t: ^testing.T) {
	result := game.detect_match({9, 1, 9, 3, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 9)
	testing.expect_value(t, result.matched_count, 2)
}

@(test)
match_two_pairs_gives_four_matches :: proc(t: ^testing.T) {
	// Two pairs: [MATCHES]=4 (all four paired dice), [VALUE]=7 (higher pair)
	result := game.detect_match({3, 7, 3, 7, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 7)
	testing.expect_value(t, result.matched_count, 4)
	testing.expect_value(t, result.unmatched_count, 1)

	testing.expect(t, result.matched[0], "first 3 should be matched")
	testing.expect(t, result.matched[1], "first 7 should be matched")
	testing.expect(t, result.matched[2], "second 3 should be matched")
	testing.expect(t, result.matched[3], "second 7 should be matched")
	testing.expect(t, !result.matched[4], "5 should be unmatched")
}

@(test)
match_triple :: proc(t: ^testing.T) {
	result := game.detect_match({4, 4, 4, 8, 2})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 4)
	testing.expect_value(t, result.matched_count, 3)
	testing.expect_value(t, result.unmatched_count, 2)
}

@(test)
match_triple_plus_pair_gives_five_matches :: proc(t: ^testing.T) {
	// 3+2 shape: [MATCHES]=5, [VALUE]=3 (triple is best group)
	result := game.detect_match({3, 3, 3, 7, 7})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 3)
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)

	for i in 0 ..< result.count {
		testing.expectf(t, result.matched[i], "die %d should be matched", i)
	}
}

@(test)
match_four_of_a_kind :: proc(t: ^testing.T) {
	result := game.detect_match({6, 6, 6, 6, 2})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 6)
	testing.expect_value(t, result.matched_count, 4)
	testing.expect_value(t, result.unmatched_count, 1)
}

@(test)
match_five_of_a_kind :: proc(t: ^testing.T) {
	result := game.detect_match({5, 5, 5, 5, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 5)
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- Match detection: edge cases ---

@(test)
match_minimum_hand_pair :: proc(t: ^testing.T) {
	result := game.detect_match({2, 2, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 2)
	testing.expect_value(t, result.matched_count, 2)
	testing.expect_value(t, result.unmatched_count, 1)
}

@(test)
match_minimum_hand_triple :: proc(t: ^testing.T) {
	result := game.detect_match({3, 3, 3})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 3)
	testing.expect_value(t, result.matched_count, 3)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_minimum_hand_no_match :: proc(t: ^testing.T) {
	result := game.detect_match({1, 2, 3})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 0)
	testing.expect_value(t, result.unmatched_count, 3)
}

@(test)
match_six_dice_all_same :: proc(t: ^testing.T) {
	// Legendary: 6 dice all same value → [MATCHES]=6
	result := game.detect_match({7, 7, 7, 7, 7, 7})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 7)
	testing.expect_value(t, result.matched_count, 6)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_six_dice_double_triple :: proc(t: ^testing.T) {
	// Double triple (3+3): [MATCHES]=6, [VALUE]=8 (higher triple)
	result := game.detect_match({2, 2, 2, 8, 8, 8})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 8)
	testing.expect_value(t, result.matched_count, 6)
	testing.expect_value(t, result.unmatched_count, 0)
}

@(test)
match_six_dice_three_pairs :: proc(t: ^testing.T) {
	// Three pairs (2+2+2): [MATCHES]=6, [VALUE]=9 (highest pair)
	result := game.detect_match({1, 1, 4, 4, 9, 9})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 9)
	testing.expect_value(t, result.matched_count, 6)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- [VALUE] tie-breaking ---

@(test)
match_value_higher_value_wins_tie :: proc(t: ^testing.T) {
	// Two triples: 3s and 8s — both freq=3, higher value wins [VALUE]
	result := game.detect_match({3, 8, 3, 8, 3, 8})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_value, 8)
	testing.expect_value(t, result.matched_count, 6)
}

// --- Unmatched counting ---

@(test)
match_all_unmatched_feeds_resolve :: proc(t: ^testing.T) {
	result := game.detect_match({1, 2, 3, 4, 5})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 0)
	testing.expect_value(t, result.unmatched_count, 5)
}

@(test)
match_all_matched_zero_unmatched :: proc(t: ^testing.T) {
	// 3+2 shape: all 5 dice are in match groups, zero unmatched
	result := game.detect_match({10, 10, 10, 4, 4})
	expect_counts_equal_total(t, result)
	testing.expect_value(t, result.matched_count, 5)
	testing.expect_value(t, result.unmatched_count, 0)
}

// --- Vacated slot integrity ---

@(test)
roll_result_cleared_properly :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .D8)
	game.character_assign_die(&ch, .D8)
	game.character_assign_die(&ch, .D8)

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
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	// Assign a normal die first
	game.character_assign_die(&ch, .D8)

	// Skull should be accepted alongside D8
	testing.expect(t, game.character_can_assign_die(&ch, .Skull), "skull should be compatible with any normal type")
	ok := game.character_assign_die(&ch, .Skull)
	testing.expect(t, ok, "skull assignment should succeed")
	testing.expect_value(t, ch.assigned_count, 2)

	// Another D8 should still be accepted
	testing.expect(t, game.character_can_assign_die(&ch, .D8), "D8 should still be accepted alongside skull")
}

@(test)
skull_only_hand_is_valid :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	// All skulls should be fine
	game.character_assign_die(&ch, .Skull)
	game.character_assign_die(&ch, .Skull)
	testing.expect_value(t, ch.assigned_count, 2)

	// Normal die should be accepted after skulls
	testing.expect(t, game.character_can_assign_die(&ch, .D12), "normal die should be accepted after only skulls")
}

@(test)
skull_does_not_set_normal_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	game.character_assign_die(&ch, .Skull)

	// assigned_type should return None (no normal type set)
	_, has_type := game.character_assigned_normal_die_type(&ch)
	testing.expect(t, !has_type, "skull-only character should have no normal assigned type")

	// Should accept any normal type
	testing.expect(t, game.character_can_assign_die(&ch, .D4), "should accept D4")
	testing.expect(t, game.character_can_assign_die(&ch, .D12), "should accept D12")
}

@(test)
skull_mixed_type_rejected :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	game.character_assign_die(&ch, .D6)
	game.character_assign_die(&ch, .Skull)

	// Different normal type should still be rejected
	testing.expect(t, !game.character_can_assign_die(&ch, .D10), "different normal type should be rejected even with skull present")
}

@(test)
skull_roll_mixed :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .Skull)
	game.character_assign_die(&ch, .D6)
	game.character_assign_die(&ch, .D6)

	game.character_roll(&ch)

	testing.expect_value(t, ch.roll.count, 3)
	testing.expect_value(t, ch.roll.skull_count, 1)
	testing.expect(t, ch.roll.skulls[0] > 0, "first die should be skull")
	testing.expect(t, ch.roll.skulls[1] == 0, "second die should not be skull")
	testing.expect(t, ch.roll.skulls[2] == 0, "third die should not be skull")

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
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .Skull)
	game.character_assign_die(&ch, .Skull)
	game.character_assign_die(&ch, .Skull)

	game.character_roll(&ch)

	testing.expect_value(t, ch.roll.skull_count, 3)
	testing.expect_value(t, ch.roll.matched_count, 0)
	testing.expect_value(t, ch.roll.unmatched_count, 0)
}

// --- Skull damage ---

@(test)
skull_damage_calculation :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, attack = 5, defense = 0})
	target := game.character_create("Target", .Common, {hp = 20, attack = 2, defense = 1})

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
	attacker := game.character_create("Attacker", .Common, {hp = 20, attack = 2, defense = 0})
	target := game.character_create("Tank", .Common, {hp = 20, attack = 1, defense = 5})

	attacker.has_rolled = true
	attacker.roll.skull_count = 3

	dmg := game.apply_skull_damage(&attacker, &target)

	// damage per hit = attack(2) - defense(5) = 0 (clamped), x3 = 0
	testing.expect_value(t, dmg, 0)
	testing.expect_value(t, target.stats.hp, 20)
}

@(test)
skull_damage_cannot_go_below_zero_hp :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, attack = 10, defense = 0})
	target := game.character_create("Weak", .Common, {hp = 5, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.skull_count = 3

	game.apply_skull_damage(&attacker, &target)

	// damage = 10 x 3 = 30, but HP floors at 0
	testing.expect_value(t, target.stats.hp, 0)
}

// --- Enhanced mode check ---

@(test)
ability_is_enhanced_below_threshold :: proc(t: ^testing.T) {
	ability := game.Ability { value_threshold = 8 }
	testing.expect(t, !game.ability_is_enhanced(&ability, 0), "should not be enhanced at 0")
	testing.expect(t, !game.ability_is_enhanced(&ability, 7), "should not be enhanced at 7")
}

@(test)
ability_is_enhanced_at_threshold :: proc(t: ^testing.T) {
	ability := game.Ability { value_threshold = 8 }
	testing.expect(t, game.ability_is_enhanced(&ability, 8), "should be enhanced at 8")
	testing.expect(t, game.ability_is_enhanced(&ability, 12), "should be enhanced at 12")
}

@(test)
ability_is_enhanced_zero_threshold :: proc(t: ^testing.T) {
	ability := game.Ability {} // threshold=0
	testing.expect(t, !game.ability_is_enhanced(&ability, 12), "should not be enhanced with threshold=0")
}

package tests

import "core:testing"
import game "../src"

// --- Character slot state ---

@(test)
empty_character_slot_is_inactive :: proc(t: ^testing.T) {
	ch: game.Character  // zero-initialized
	testing.expect_value(t, ch.state, game.Character_State.Empty)
	testing.expect(t, !game.character_is_alive(&ch), "zero-initialized character should be inactive")
}

@(test)
created_character_is_active :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	testing.expect_value(t, ch.state, game.Character_State.Alive)
	testing.expect(t, game.character_is_alive(&ch), "created character should be active")
}

// --- Pure die type constraint ---

@(test)
character_assign_first_die_any_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	testing.expect(t, game.character_can_assign_die(&ch, .D4), "empty character should accept any type")
	testing.expect(t, game.character_can_assign_die(&ch, .D12), "empty character should accept any type")

	ok := game.character_assign_die(&ch, .D8)
	testing.expect(t, ok, "first assignment should succeed")
	testing.expect_value(t, ch.assigned_count, 1)
}

@(test)
character_assign_same_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .D6)

	ok := game.character_assign_die(&ch, .D6)
	testing.expect(t, ok, "same type should be accepted")
	testing.expect_value(t, ch.assigned_count, 2)
}

@(test)
character_rejects_mixed_type :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .D4)

	testing.expect(t, !game.character_can_assign_die(&ch, .D8), "different type should be rejected")
	ok := game.character_assign_die(&ch, .D8)
	testing.expect(t, !ok, "mixed type assignment should fail")
	testing.expect_value(t, ch.assigned_count, 1)
}

@(test)
character_respects_rarity_max :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	max := game.RARITY_MAX_DICE[game.Character_Rarity.Common]

	for _ in 0 ..< max {
		game.character_assign_die(&ch, .D6)
	}

	testing.expect(t, !game.character_can_assign_die(&ch, .D6), "should be full at rarity max")
	ok := game.character_assign_die(&ch, .D6)
	testing.expect(t, !ok, "should not exceed rarity max")
	testing.expect_value(t, ch.assigned_count, max)
}

@(test)
character_unassign_returns_die :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Rare, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .D10)
	game.character_assign_die(&ch, .D10)

	die, ok := game.character_unassign_die(&ch, 0)
	testing.expect(t, ok, "unassign should succeed")
	testing.expect_value(t, die, game.Die_Type.D10)
	testing.expect_value(t, ch.assigned_count, 1)
}

@(test)
character_unassign_clears_vacated_slots :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Rare, {hp = 20, attack = 3, defense = 1})  // max 4
	// Use non-zero die types so stale data is distinguishable from zeroed memory
	game.character_assign_die(&ch, .D10)
	game.character_assign_die(&ch, .D10)
	game.character_assign_die(&ch, .D10)

	// Remove from the middle
	game.character_unassign_die(&ch, 1)
	testing.expect_value(t, ch.assigned_count, 2)
	testing.expectf(t, ch.assigned[ch.assigned_count] == .None, "vacated character slot should be .None, got %v", ch.assigned[ch.assigned_count])

	// Remove last
	game.character_unassign_die(&ch, 1)
	testing.expect_value(t, ch.assigned_count, 1)
	testing.expectf(t, ch.assigned[ch.assigned_count] == .None, "vacated character slot should be .None, got %v", ch.assigned[ch.assigned_count])
}

@(test)
character_accepts_new_type_after_clearing :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.character_assign_die(&ch, .D4)
	game.character_assign_die(&ch, .D4)

	// Remove all
	game.character_unassign_die(&ch, 0)
	game.character_unassign_die(&ch, 0)

	testing.expect_value(t, ch.assigned_count, 0)

	// Should now accept a different type
	ok := game.character_assign_die(&ch, .D12)
	testing.expect(t, ok, "empty character should accept new type after clearing")
}

@(test)
character_assigned_type_tracks_correctly :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})

	_, has_type := game.character_assigned_normal_die_type(&ch)
	testing.expect(t, !has_type, "empty character should have no assigned type")

	game.character_assign_die(&ch, .D8)
	dt, ok := game.character_assigned_normal_die_type(&ch)
	testing.expect(t, ok, "should have assigned type after assignment")
	testing.expect_value(t, dt, game.Die_Type.D8)
}

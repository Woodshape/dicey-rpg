package tests

import "core:testing"
import game "../src"

// --- Condition apply/remove ---

@(test)
condition_apply_adds_to_character :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	ok := game.condition_apply(&ch, .Shield, 5, .On_Hit_Taken, 1)
	testing.expect(t, ok, "should apply successfully")
	testing.expect_value(t, ch.condition_count, 1)
	testing.expect_value(t, ch.conditions[0].kind, game.Condition_Kind.Shield)
}

@(test)
condition_apply_fails_when_full :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	// Manually fill all condition slots with distinct entries to simulate a full array.
	ch.condition_count = game.MAX_CONDITIONS
	for i in 0 ..< game.MAX_CONDITIONS {
		ch.conditions[i] = game.Condition{kind = .Shield, value = i + 1, expiry = .On_Hit_Taken, remaining = 1}
	}
	// Applying a different kind should fail when array is full.
	ok := game.condition_apply(&ch, .Hex, 1, .Turns, 3)
	testing.expect(t, !ok, "should fail when condition array is full")
	testing.expect_value(t, ch.condition_count, game.MAX_CONDITIONS)
}

@(test)
condition_remove_shifts_remaining :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.condition_apply(&ch, .Shield, 5, .On_Hit_Taken, 1)
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)
	testing.expect_value(t, ch.condition_count, 2)

	game.condition_remove(&ch, 0) // remove Shield
	testing.expect_value(t, ch.condition_count, 1)
	testing.expect_value(t, ch.conditions[0].kind, game.Condition_Kind.Hex)
	// Vacated slot should be zeroed
	testing.expect_value(t, ch.conditions[1].kind, game.Condition_Kind.None)
}

// --- Shield ---

@(test)
shield_absorbs_damage :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	// Shield with 8 absorption pool
	game.condition_apply(&ch, .Shield, 8, .On_Hit_Taken, 1)

	// 5 damage incoming — Shield absorbs all of it, 3 pool remaining
	absorbed := game.condition_absorb_damage(&ch, 5)
	testing.expect_value(t, absorbed, 5)
	testing.expect_value(t, ch.condition_count, 1) // Shield still alive
	testing.expect_value(t, ch.conditions[0].value, 3) // 8 - 5 = 3 remaining

	// 4 damage incoming — Shield absorbs 3, breaks, 1 damage passes through
	absorbed2 := game.condition_absorb_damage(&ch, 4)
	testing.expect_value(t, absorbed2, 3)
	testing.expect_value(t, ch.condition_count, 0) // Shield consumed
}

@(test)
shield_reduces_skull_damage :: proc(t: ^testing.T) {
	attacker := game.character_create("Attacker", .Common, {hp = 20, attack = 5, defense = 0})
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})
	// Shield with 7 absorption pool
	game.condition_apply(&target, .Shield, 7, .On_Hit_Taken, 1)

	// 2 skull dice with value 1 each. Per hit: 1+5-0 = 6 dmg.
	// First hit: 6 dmg, Shield absorbs 6, 1 pool left. 0 dealt.
	// Second hit: 6 dmg, Shield absorbs 1, breaks. 5 dealt.
	attacker.roll.count = 2
	attacker.roll.skull_count = 2
	attacker.roll.skulls[0] = 1
	attacker.roll.skulls[1] = 1
	dmg := game.apply_skull_damage(&attacker, &target)

	testing.expect_value(t, dmg, 5)
	testing.expect_value(t, target.stats.hp, 15)
	testing.expect_value(t, target.condition_count, 0) // Shield consumed
}

@(test)
condition_apply_refreshes_existing :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 1})
	game.condition_apply(&ch, .Shield, 5, .On_Hit_Taken, 1)
	testing.expect_value(t, ch.condition_count, 1)

	// Re-applying same kind refreshes, doesn't add a second slot.
	game.condition_apply(&ch, .Shield, 8, .On_Hit_Taken, 1)
	testing.expect_value(t, ch.condition_count, 1)
	testing.expect_value(t, ch.conditions[0].value, 8) // refreshed to new value
}

// --- Hex ---

@(test)
hex_reduces_effective_defense :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 2})
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)

	def := game.character_effective_defense(&ch)
	testing.expect_value(t, def, 1) // 2 - 1 = 1
}

@(test)
hex_refreshes_instead_of_stacking :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 3})
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)

	// Second apply refreshes the existing Hex — only one condition slot used.
	testing.expect_value(t, ch.condition_count, 1)
	def := game.character_effective_defense(&ch)
	testing.expect_value(t, def, 2) // 3 - 1 = 2
}

@(test)
hex_allows_negative_defense :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)

	def := game.character_effective_defense(&ch)
	testing.expect_value(t, def, -1) // Hex pushes DEF below zero
}

// --- Turn ticking ---

@(test)
condition_tick_decrements_turns :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 2})
	game.condition_apply(&ch, .Hex, 1, .Turns, 3)

	game.condition_tick_turns(&ch)
	testing.expect_value(t, ch.conditions[0].remaining, 2)

	game.condition_tick_turns(&ch)
	testing.expect_value(t, ch.conditions[0].remaining, 1)

	game.condition_tick_turns(&ch)
	testing.expect_value(t, ch.condition_count, 0) // expired and removed
}

@(test)
condition_tick_does_not_affect_on_hit :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	game.condition_apply(&ch, .Shield, 5, .On_Hit_Taken, 1)

	game.condition_tick_turns(&ch)
	testing.expect_value(t, ch.condition_count, 1) // Shield unaffected by turn tick
	testing.expect_value(t, ch.conditions[0].remaining, 1)
}

// --- Interval / periodic timer ---

@(test)
condition_interval_timer_advances :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	// interval=2 means effect fires every 2 ticks; duration=6 so it lasts long enough
	game.condition_apply(&ch, .Hex, 1, .Turns, 6, interval = 2)

	testing.expect_value(t, ch.conditions[0].timer, 0)

	game.condition_tick_turns(&ch) // tick 1: timer 0->1, no fire
	testing.expect_value(t, ch.conditions[0].timer, 1)

	game.condition_tick_turns(&ch) // tick 2: timer 1->2, fires, resets to 0
	testing.expect_value(t, ch.conditions[0].timer, 0)

	game.condition_tick_turns(&ch) // tick 3: timer 0->1
	testing.expect_value(t, ch.conditions[0].timer, 1)
}

@(test)
condition_interval_zero_means_no_periodic :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	game.condition_apply(&ch, .Hex, 1, .Turns, 3) // interval defaults to 0

	testing.expect_value(t, ch.conditions[0].interval, 0)
	testing.expect_value(t, ch.conditions[0].timer, 0)

	game.condition_tick_turns(&ch)
	// timer should stay 0 — no periodic logic runs
	testing.expect_value(t, ch.conditions[0].timer, 0)
}

// --- condition_has ---

@(test)
condition_has_finds_active_condition :: proc(t: ^testing.T) {
	ch := game.character_create("Test", .Common, {hp = 20, attack = 3, defense = 0})
	testing.expect(t, !game.condition_has(&ch, .Shield), "should not have Shield before apply")

	game.condition_apply(&ch, .Shield, 5, .On_Hit_Taken, 1)
	testing.expect(t, game.condition_has(&ch, .Shield), "should have Shield after apply")
}

package tests

import "core:testing"
import game "../src"

// --- Individual ability effects ---

@(test)
flurry_deals_one_per_match :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 3,
		matched_value = 5,
	}

	game.ability_flurry(&attacker, &target, &roll)

	// 3 hits of max(1 - 0, 0) = 1 each = 3 damage
	testing.expect_value(t, target.stats.hp, 17)
}

@(test)
flurry_respects_defense :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Tank", .Common, {hp = 20, attack = 1, defense = 5})
	roll := game.Roll_Result {
		matched_count = 4,
		matched_value = 2,
	}

	game.ability_flurry(&attacker, &target, &roll)

	// max(1 - 5, 0) = 0 per hit, no damage
	testing.expect_value(t, target.stats.hp, 20)
}

@(test)
smite_deals_value_damage :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 1})
	roll := game.Roll_Result {
		matched_count = 2,
		matched_value = 8,
	}

	game.ability_smite(&attacker, &target, &roll)

	// max(8 - 1, 0) = 7 damage
	testing.expect_value(t, target.stats.hp, 13)
}

@(test)
fireball_deals_matches_times_value :: proc(t: ^testing.T) {
	attacker := game.goblin_create()
	target := game.character_create("Target", .Common, {hp = 30, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 4,
		matched_value = 5,
	}

	game.ability_fireball(&attacker, &target, &roll)

	// max(4*5 - 0, 0) = 20 damage
	testing.expect_value(t, target.stats.hp, 10)
}

@(test)
heal_restores_value_hp :: proc(t: ^testing.T) {
	attacker := game.goblin_create()
	attacker.stats.hp = 5
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 2,
		matched_value = 7,
	}

	game.ability_heal(&attacker, &target, &roll)

	testing.expect_value(t, attacker.stats.hp, 12)
}

// --- Ability resolution ---

@(test)
resolve_fires_ability_when_threshold_met :: proc(t: ^testing.T) {
	attacker := game.warrior_create()  // Flurry, min_matches=2
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 3
	attacker.roll.matched_value = 4

	game.resolve_abilities(&attacker, &target)

	testing.expect(t, attacker.ability_fired, "Flurry should fire with 3 matches")
	// Flurry: 3 hits of 1 dmg = 3
	testing.expect_value(t, target.stats.hp, 47)
}

@(test)
resolve_skips_ability_when_threshold_not_met :: proc(t: ^testing.T) {
	attacker := game.warrior_create()  // min_matches=2
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 1
	attacker.roll.matched_value = 6

	game.resolve_abilities(&attacker, &target)

	testing.expect(t, !attacker.ability_fired, "Flurry should not fire with 1 match")
	testing.expect_value(t, target.stats.hp, 50)
}

@(test)
resolve_zero_matches_skips_ability :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 0
	attacker.roll.matched_value = 0
	attacker.roll.unmatched_count = 3

	game.resolve_abilities(&attacker, &target)

	testing.expect(t, !attacker.ability_fired, "ability should not fire with 0 matches")
	testing.expect_value(t, target.stats.hp, 20)
	// But resolve should charge
	testing.expect_value(t, attacker.resolve, 3)
}

// --- Resolve meter ---

@(test)
resolve_charges_from_unmatched :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.unmatched_count = 3
	attacker.roll.matched_count = 0

	game.resolve_abilities(&attacker, &target)

	testing.expect_value(t, attacker.resolve, 3)
}

@(test)
resolve_accumulates_across_rolls :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	// First roll: 2 unmatched
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 2
	game.resolve_abilities(&attacker, &target)
	testing.expect_value(t, attacker.resolve, 2)

	// Second roll: 2 more unmatched
	attacker.roll.unmatched_count = 2
	game.resolve_abilities(&attacker, &target)
	testing.expect_value(t, attacker.resolve, 4)
}

@(test)
resolve_triggers_at_threshold :: proc(t: ^testing.T) {
	attacker := game.warrior_create()  // resolve_max = 5
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	// Pre-charge to 4
	attacker.resolve = 4
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 1  // pushes to 5 = resolve_max

	game.resolve_abilities(&attacker, &target)

	testing.expect(t, attacker.resolve_fired, "resolve should fire at threshold")
	testing.expect_value(t, attacker.resolve, 0)  // reset after firing
	// Heroic Strike deals 10 flat damage ignoring defense
	testing.expect_value(t, target.stats.hp, 40)
}

@(test)
resolve_does_not_trigger_below_threshold :: proc(t: ^testing.T) {
	attacker := game.warrior_create()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.resolve = 3
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 1  // pushes to 4, below resolve_max=5

	game.resolve_abilities(&attacker, &target)

	testing.expect(t, !attacker.resolve_fired, "resolve should not fire below threshold")
	testing.expect_value(t, attacker.resolve, 4)
	testing.expect_value(t, target.stats.hp, 50)
}

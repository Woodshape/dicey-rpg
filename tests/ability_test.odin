package tests

import game "../src"
import "core:testing"

// --- Test helpers ---

// Build a warrior-like character for ability tests.
// Stats and abilities match data/characters/warrior.cfg.
test_warrior :: proc() -> game.Character {
	ch := game.character_create("Warrior", .Common, {hp = 20, attack = 3, defense = 1})
	ch.ability = game.Ability {
		name        = "Flurry",
		scaling     = .Hybrid,
		min_matches = 2,
		effect      = game.ability_flurry,
		describe    = game.describe_flurry,
		description = "{VALUE} dmg x {MATCHES} hits",
	}
	ch.resolve_ability = game.Ability {
		name        = "Heroic Strike",
		scaling     = .None,
		min_matches = 0,
		effect      = game.ability_resolve_warrior,
		describe    = game.describe_resolve_warrior,
		description = "10 dmg, ignores DEF",
	}
	ch.resolve_max = 10
	return ch
}

// Build a goblin-like character for ability tests.
test_goblin :: proc() -> game.Character {
	ch := game.character_create("Goblin", .Common, {hp = 15, attack = 3, defense = 0})
	ch.ability = game.Ability {
		name        = "Fireball",
		scaling     = .Hybrid,
		min_matches = 2,
		effect      = game.ability_fireball,
		describe    = game.describe_fireball,
		description = "{MATCHES} x {VALUE} dmg",
	}
	ch.resolve_ability = game.Ability {
		name        = "Goblin Explosion",
		scaling     = .None,
		min_matches = 0,
		effect      = game.ability_resolve_goblin_explosion,
		describe    = game.describe_resolve_goblin_explosion,
		description = "6 dmg to all enemies",
	}
	ch.resolve_max = 10
	return ch
}

// --- Individual ability effects ---

@(test)
flurry_deals_value_per_match :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 3,
		matched_value = 5,
	}

	game.ability_flurry(nil, &attacker, &target, &roll)

	// [VALUE]=5, target DEF=0: 3 hits of max(5 - 0, 0) = 5 each = 15 damage
	testing.expect_value(t, target.stats.hp, 5)
}

@(test)
flurry_respects_defense :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Tank", .Common, {hp = 20, attack = 1, defense = 5})
	roll := game.Roll_Result {
		matched_count = 4,
		matched_value = 2,
	}

	game.ability_flurry(nil, &attacker, &target, &roll)

	// [VALUE]=2, DEF=5: max(2 - 5, 0) = 0 per hit, no damage
	testing.expect_value(t, target.stats.hp, 20)
}

@(test)
smite_deals_value_damage :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 1})
	roll := game.Roll_Result {
		matched_count = 2,
		matched_value = 8,
	}

	game.ability_smite(nil, &attacker, &target, &roll)

	// max(8 - 1, 0) = 7 damage
	testing.expect_value(t, target.stats.hp, 13)
}

@(test)
fireball_deals_matches_times_value :: proc(t: ^testing.T) {
	attacker := test_goblin()
	target := game.character_create("Target", .Common, {hp = 30, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 4,
		matched_value = 5,
	}

	game.ability_fireball(nil, &attacker, &target, &roll)

	// max(4*5 - 0, 0) = 20 damage
	testing.expect_value(t, target.stats.hp, 10)
}

@(test)
heal_restores_value_hp :: proc(t: ^testing.T) {
	attacker := test_goblin()
	attacker.stats.hp = 5
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})
	roll := game.Roll_Result {
		matched_count = 2,
		matched_value = 7,
	}

	game.ability_heal(nil, &attacker, &target, &roll)

	testing.expect_value(t, attacker.stats.hp, 12)
}

// Test-local helper that replicates the inlined handle_abilities logic in resolve_roll.
// Does not emit trace events (no Game_State available in tests).
handle_abilities_test :: proc(attacker: ^game.Character, target: ^game.Character) {
	roll := &attacker.roll

	// Main ability
	if roll.matched_count >= attacker.ability.min_matches && attacker.ability.effect != nil {
		attacker.ability.effect(nil, attacker, target, roll)
		attacker.ability_fired = true
	} else {
		attacker.ability_fired = false
	}

	// Charge resolve from unmatched dice
	attacker.resolve += roll.unmatched_count

	// Auto-trigger resolve ability when meter is full
	if attacker.resolve >= attacker.resolve_max && attacker.resolve_ability.effect != nil {
		attacker.resolve_ability.effect(nil, attacker, target, roll)
		attacker.resolve_fired = true
		attacker.resolve = 0
	} else {
		attacker.resolve_fired = false
	}
}

// --- Ability resolution ---

@(test)
resolve_fires_ability_when_threshold_met :: proc(t: ^testing.T) {
	attacker := test_warrior() // Flurry, min_matches=2
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 3
	attacker.roll.matched_value = 4

	handle_abilities_test(&attacker, &target)

	testing.expect(t, attacker.ability_fired, "Flurry should fire with 3 matches")
	// [VALUE]=4, target DEF=0: 3 hits of max(4 - 0, 0) = 4 each = 12 damage
	testing.expect_value(t, target.stats.hp, 38)
}

@(test)
resolve_skips_ability_when_threshold_not_met :: proc(t: ^testing.T) {
	attacker := test_warrior() // min_matches=2
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 1
	attacker.roll.matched_value = 6

	handle_abilities_test(&attacker, &target)

	testing.expect(t, !attacker.ability_fired, "Flurry should not fire with 1 match")
	testing.expect_value(t, target.stats.hp, 50)
}

@(test)
resolve_zero_matches_skips_ability :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 20, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.matched_count = 0
	attacker.roll.matched_value = 0
	attacker.roll.unmatched_count = 3

	handle_abilities_test(&attacker, &target)

	testing.expect(t, !attacker.ability_fired, "ability should not fire with 0 matches")
	testing.expect_value(t, target.stats.hp, 20)
	// But resolve should charge
	testing.expect_value(t, attacker.resolve, 3)
}

// --- Resolve meter ---

@(test)
resolve_charges_from_unmatched :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.has_rolled = true
	attacker.roll.unmatched_count = 3
	attacker.roll.matched_count = 0

	handle_abilities_test(&attacker, &target)

	testing.expect_value(t, attacker.resolve, 3)
}

@(test)
resolve_accumulates_across_rolls :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	// First roll: 2 unmatched
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 2
	handle_abilities_test(&attacker, &target)
	testing.expect_value(t, attacker.resolve, 2)

	// Second roll: 2 more unmatched
	attacker.roll.unmatched_count = 2
	handle_abilities_test(&attacker, &target)
	testing.expect_value(t, attacker.resolve, 4)
}

@(test)
resolve_triggers_at_threshold :: proc(t: ^testing.T) {
	attacker := test_warrior() // resolve_max = 10
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	// Pre-charge to 9
	attacker.resolve = 9
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 1 // pushes to 10 = resolve_max

	handle_abilities_test(&attacker, &target)

	testing.expect(t, attacker.resolve_fired, "resolve should fire at threshold")
	testing.expect_value(t, attacker.resolve, 0) // reset after firing
	// Heroic Strike deals 10 flat damage ignoring defense
	testing.expect_value(t, target.stats.hp, 40)
}

@(test)
resolve_does_not_trigger_below_threshold :: proc(t: ^testing.T) {
	attacker := test_warrior()
	target := game.character_create("Target", .Common, {hp = 50, attack = 1, defense = 0})

	attacker.resolve = 8
	attacker.has_rolled = true
	attacker.roll.unmatched_count = 1 // pushes to 9, below resolve_max=10

	handle_abilities_test(&attacker, &target)

	testing.expect(t, !attacker.resolve_fired, "resolve should not fire below threshold")
	testing.expect_value(t, attacker.resolve, 9)
	testing.expect_value(t, target.stats.hp, 50)
}

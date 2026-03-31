package tests

import "core:testing"
import game "../src"

// Helper: create a minimal Game_State with two parties for passive testing.
@(private = "file")
make_passive_gs :: proc() -> game.Game_State {
	gs: game.Game_State
	gs.player_party.characters[0] = game.character_create("Warrior", .Common, {hp = 20, attack = 3, defense = 1})
	gs.player_party.characters[1] = game.character_create("Healer", .Common, {hp = 15, attack = 1, defense = 0})
	gs.player_party.count = 2
	gs.enemy_party.characters[0] = game.character_create("Goblin", .Common, {hp = 15, attack = 3, defense = 0})
	gs.enemy_party.characters[1] = game.character_create("Shaman", .Common, {hp = 12, attack = 2, defense = 0})
	gs.enemy_party.count = 2
	return gs
}

// --- Tenacity ---

@(test)
tenacity_heals_on_miss :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.stats.hp = 15 // damaged
	target := &gs.enemy_party.characters[0]
	roll := game.Roll_Result{count = 3, matched_count = 0, unmatched_count = 3}
	game.passive_tenacity(&gs, warrior, target, &roll)
	testing.expect_value(t, warrior.stats.hp, 16)
}

@(test)
tenacity_does_not_heal_on_match :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.stats.hp = 15
	target := &gs.enemy_party.characters[0]
	roll := game.Roll_Result{count = 3, matched_count = 2, unmatched_count = 1}
	game.passive_tenacity(&gs, warrior, target, &roll)
	testing.expect_value(t, warrior.stats.hp, 15)
}

@(test)
tenacity_does_not_heal_on_skulls_only :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.stats.hp = 15
	target := &gs.enemy_party.characters[0]
	roll := game.Roll_Result{count = 2, skull_count = 2, matched_count = 0, unmatched_count = 0}
	game.passive_tenacity(&gs, warrior, target, &roll)
	testing.expect_value(t, warrior.stats.hp, 15)
}

// --- Empathy ---

@(test)
empathy_charges_resolve_on_ally_damage :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	healer := &gs.player_party.characters[1]
	warrior := &gs.player_party.characters[0]
	healer.passive = game.Passive{
		name    = "Empathy",
		trigger = .On_Ally_Damaged,
		effect  = game.passive_empathy,
	}
	healer.resolve_max = 10

	resolve_before := healer.resolve
	// Simulate warrior taking damage — notify allies
	game.notify_ally_damaged(&gs, warrior)
	testing.expect_value(t, healer.resolve, resolve_before + 1)
}

@(test)
empathy_does_not_charge_for_self_damage :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	healer := &gs.player_party.characters[1]
	healer.passive = game.Passive{
		name    = "Empathy",
		trigger = .On_Ally_Damaged,
		effect  = game.passive_empathy,
	}
	healer.resolve_max = 10

	resolve_before := healer.resolve
	// Healer herself takes damage — should NOT trigger her own empathy
	game.notify_ally_damaged(&gs, healer)
	testing.expect_value(t, healer.resolve, resolve_before)
}

@(test)
empathy_does_not_exceed_resolve_max :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	healer := &gs.player_party.characters[1]
	warrior := &gs.player_party.characters[0]
	healer.passive = game.Passive{
		name    = "Empathy",
		trigger = .On_Ally_Damaged,
		effect  = game.passive_empathy,
	}
	healer.resolve_max = 10
	healer.resolve = 10 // already full

	game.notify_ally_damaged(&gs, warrior)
	testing.expect_value(t, healer.resolve, 10)
}

// --- Scavenger ---

@(test)
scavenger_deals_damage_on_miss :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	goblin := &gs.enemy_party.characters[0]
	target := &gs.player_party.characters[0]
	hp_before := target.stats.hp

	// Roll with no matches, some unmatched normal dice
	roll := game.Roll_Result{count = 3, matched_count = 0, unmatched_count = 3}
	game.passive_scavenger(&gs, goblin, target, &roll)
	testing.expect_value(t, target.stats.hp, hp_before - 2)
}

@(test)
scavenger_does_not_fire_on_match :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	goblin := &gs.enemy_party.characters[0]
	target := &gs.player_party.characters[0]
	hp_before := target.stats.hp

	// Roll with matches — scavenger should NOT fire
	roll := game.Roll_Result{count = 3, matched_count = 2, unmatched_count = 1}
	game.passive_scavenger(&gs, goblin, target, &roll)
	testing.expect_value(t, target.stats.hp, hp_before)
}

@(test)
scavenger_does_not_fire_on_skulls_only :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	goblin := &gs.enemy_party.characters[0]
	target := &gs.player_party.characters[0]
	hp_before := target.stats.hp

	// Roll with only skulls — matched=0 but unmatched=0 too
	roll := game.Roll_Result{count = 2, skull_count = 2, matched_count = 0, unmatched_count = 0}
	game.passive_scavenger(&gs, goblin, target, &roll)
	testing.expect_value(t, target.stats.hp, hp_before)
}

// --- Curse Weaver ---

@(test)
curse_weaver_deals_damage_per_condition :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	shaman := &gs.enemy_party.characters[1]
	target := &gs.player_party.characters[0]
	hp_before := target.stats.hp

	// Apply 2 distinct conditions to target
	game.condition_apply(target, .Hex, 1, .Turns, 3)
	game.condition_apply(target, .Shield, 5, .On_Hit_Taken, 1)

	roll := game.Roll_Result{count = 1}
	game.passive_curse_weaver(&gs, shaman, target, &roll)
	// 2 conditions = 2 damage, but Shield absorbs 2 of it — net 0 HP lost.
	// Curse Weaver computes dmg from condition_count (2), then Shield absorbs.
	testing.expect_value(t, target.stats.hp, hp_before)
	// Shield should have 3 pool remaining (5 - 2)
	testing.expect_value(t, target.conditions[1].value, 3)
}

@(test)
curse_weaver_no_damage_without_conditions :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	shaman := &gs.enemy_party.characters[1]
	target := &gs.player_party.characters[0]
	hp_before := target.stats.hp

	// No conditions on target
	roll := game.Roll_Result{count = 1}
	game.passive_curse_weaver(&gs, shaman, target, &roll)
	testing.expect_value(t, target.stats.hp, hp_before)
}

// --- fire_on_roll_passive ---

@(test)
fire_on_roll_passive_sets_fired_flag :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.passive = game.Passive{
		name    = "Tenacity",
		trigger = .On_Roll,
		effect  = game.passive_tenacity,
	}
	target := &gs.enemy_party.characters[0]
	warrior.roll = game.Roll_Result{count = 1, unmatched_count = 1}

	game.fire_on_roll_passive(&gs, warrior, target)
	testing.expect(t, warrior.passive_fired, "passive_fired should be true after On_Roll passive")
}

@(test)
fire_on_roll_passive_not_fired_on_match :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.passive = game.Passive{
		name    = "Tenacity",
		trigger = .On_Roll,
		effect  = game.passive_tenacity,
	}
	target := &gs.enemy_party.characters[0]
	// Matched roll — Tenacity should NOT fire
	warrior.roll = game.Roll_Result{count = 3, matched_count = 2, unmatched_count = 1}

	game.fire_on_roll_passive(&gs, warrior, target)
	testing.expect(t, !warrior.passive_fired, "passive_fired should be false when Tenacity skips on match")
}

@(test)
fire_on_roll_passive_not_fired_on_skulls_only :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	warrior := &gs.player_party.characters[0]
	warrior.passive = game.Passive{
		name    = "Tenacity",
		trigger = .On_Roll,
		effect  = game.passive_tenacity,
	}
	target := &gs.enemy_party.characters[0]
	// Skulls-only roll — Tenacity should NOT fire
	warrior.roll = game.Roll_Result{count = 1, skull_count = 1, matched_count = 0, unmatched_count = 0}

	game.fire_on_roll_passive(&gs, warrior, target)
	testing.expect(t, !warrior.passive_fired, "passive_fired should be false when Tenacity skips on skulls-only")
}

@(test)
fire_on_roll_passive_skips_non_roll_trigger :: proc(t: ^testing.T) {
	gs := make_passive_gs()
	healer := &gs.player_party.characters[1]
	healer.passive = game.Passive{
		name    = "Empathy",
		trigger = .On_Ally_Damaged,
		effect  = game.passive_empathy,
	}
	target := &gs.enemy_party.characters[0]

	game.fire_on_roll_passive(&gs, healer, target)
	testing.expect(t, !healer.passive_fired, "passive_fired should be false for On_Ally_Damaged trigger")
}

// --- Config loading ---

@(test)
passive_loads_from_config :: proc(t: ^testing.T) {
	ch, ok := game.config_load_character("warrior")
	defer game.character_free(&ch)
	testing.expect(t, ok, "warrior config should load")
	testing.expect(t, ch.passive.effect != nil, "warrior should have a passive effect")
	testing.expect_value(t, ch.passive.trigger, game.Passive_Trigger.On_Roll)
}

@(test)
passive_empathy_loads_correct_trigger :: proc(t: ^testing.T) {
	ch, ok := game.config_load_character("healer")
	defer game.character_free(&ch)
	testing.expect(t, ok, "healer config should load")
	testing.expect(t, ch.passive.effect != nil, "healer should have a passive effect")
	testing.expect_value(t, ch.passive.trigger, game.Passive_Trigger.On_Ally_Damaged)
}

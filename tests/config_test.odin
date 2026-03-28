package tests

import game "../src"
import "core:testing"

// --- Config parser ---

@(test)
parse_character_file :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/characters/warrior.cfg")
	defer game.config_free(&cf)

	testing.expect(t, ok, "warrior.cfg should parse")

	// Root scope
	name, name_ok := game.config_get_string(&cf, "", "name")
	testing.expect(t, name_ok, "root 'name' should exist")
	testing.expect_value(t, name, "Warrior")

	rarity, rar_ok := game.config_get_string(&cf, "", "rarity")
	testing.expect(t, rar_ok, "root 'rarity' should exist")
	testing.expect_value(t, rarity, "Common")

	resolve_max, rm_ok := game.config_get_int(&cf, "", "resolve_max")
	testing.expect(t, rm_ok, "root 'resolve_max' should exist")
	testing.expect_value(t, resolve_max, 10)

	// Stats section
	hp, hp_ok := game.config_get_int(&cf, "stats", "hp")
	testing.expect(t, hp_ok, "stats.hp should exist")
	testing.expect_value(t, hp, 20)

	// Ability section
	effect, eff_ok := game.config_get_string(&cf, "ability", "effect")
	testing.expect(t, eff_ok, "ability.effect should exist")
	testing.expect_value(t, effect, "flurry")
}

@(test)
parse_encounter_file :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/encounters/tutorial.cfg")
	defer game.config_free(&cf)

	testing.expect(t, ok, "tutorial.cfg should parse")

	player, p_ok := game.config_get_list(&cf, "player")
	testing.expect(t, p_ok, "player section should exist")
	testing.expect_value(t, len(player), 2)
	testing.expect_value(t, player[0], "warrior")
	testing.expect_value(t, player[1], "healer")

	enemy, e_ok := game.config_get_list(&cf, "enemy")
	testing.expect(t, e_ok, "enemy section should exist")
	testing.expect_value(t, len(enemy), 2)
	testing.expect_value(t, enemy[0], "goblin")
	testing.expect_value(t, enemy[1], "shaman")
}

@(test)
parse_missing_file_fails :: proc(t: ^testing.T) {
	_, ok := game.config_parse_file("data/characters/nonexistent.cfg")
	testing.expect(t, !ok, "missing file should fail")
}

@(test)
parse_missing_section_fails :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/characters/warrior.cfg")
	defer game.config_free(&cf)
	testing.expect(t, ok, "warrior.cfg should parse")

	_, s_ok := game.config_get_string(&cf, "bogus_section", "name")
	testing.expect(t, !s_ok, "missing section should fail")
}

@(test)
parse_missing_key_fails :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/characters/warrior.cfg")
	defer game.config_free(&cf)
	testing.expect(t, ok, "warrior.cfg should parse")

	_, k_ok := game.config_get_string(&cf, "stats", "bogus_key")
	testing.expect(t, !k_ok, "missing key should fail")
}

@(test)
get_int_or_returns_default_when_missing :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/characters/warrior.cfg")
	defer game.config_free(&cf)
	testing.expect(t, ok, "warrior.cfg should parse")

	val := game.config_get_int_or(&cf, "stats", "nonexistent", 42)
	testing.expect_value(t, val, 42)
}

@(test)
get_int_or_returns_value_when_present :: proc(t: ^testing.T) {
	cf, ok := game.config_parse_file("data/characters/warrior.cfg")
	defer game.config_free(&cf)
	testing.expect(t, ok, "warrior.cfg should parse")

	val := game.config_get_int_or(&cf, "stats", "hp", 999)
	testing.expect_value(t, val, 20)
}

// --- Character loading ---

@(test)
load_warrior_stats :: proc(t: ^testing.T) {
	ch, ok := game.config_load_character("warrior")
	testing.expect(t, ok, "warrior.cfg should load")
	testing.expect_value(t, ch.stats.hp, 20)
	testing.expect_value(t, ch.stats.attack, 3)
	testing.expect_value(t, ch.stats.defense, 1)
	testing.expect_value(t, ch.rarity, game.Character_Rarity.Common)
	testing.expect_value(t, ch.resolve_max, 10)
	testing.expect_value(t, ch.state, game.Character_State.Alive)
}

@(test)
load_warrior_abilities :: proc(t: ^testing.T) {
	ch, ok := game.config_load_character("warrior")
	testing.expect(t, ok, "warrior.cfg should load")

	testing.expect(t, ch.ability.effect != nil, "main ability effect should be set")
	testing.expect(t, ch.ability.describe != nil, "main ability describe should be set")
	testing.expect_value(t, ch.ability.scaling, game.Ability_Scaling.Hybrid)
	testing.expect_value(t, ch.ability.min_matches, 2)

	testing.expect(t, ch.resolve_ability.effect != nil, "resolve effect should be set")
	testing.expect(t, ch.resolve_ability.describe != nil, "resolve describe should be set")
	testing.expect_value(t, ch.resolve_ability.min_matches, 0)
}

@(test)
load_all_characters :: proc(t: ^testing.T) {
	// All four character files should load without error
	for name in ([?]string{"warrior", "healer", "goblin", "shaman"}) {
		_, ok := game.config_load_character(name)
		testing.expectf(t, ok, "%s.cfg should load", name)
	}
}

@(test)
load_missing_character_fails :: proc(t: ^testing.T) {
	_, ok := game.config_load_character("nonexistent")
	testing.expect(t, !ok, "missing character should fail")
}

@(test)
ability_min_matches_defaults :: proc(t: ^testing.T) {
	// Main ability defaults to min_matches=2, resolve defaults to 0.
	// healer.cfg may omit min_matches — should still load with defaults.
	ch, ok := game.config_load_character("healer")
	testing.expect(t, ok, "healer.cfg should load")
	testing.expect_value(t, ch.ability.min_matches, 2)
	testing.expect_value(t, ch.resolve_ability.min_matches, 0)
}

// --- Encounter loading ---

@(test)
load_tutorial_encounter :: proc(t: ^testing.T) {
	player, enemy, ok := game.config_load_encounter("tutorial")
	testing.expect(t, ok, "tutorial.cfg should load")
	testing.expect_value(t, player.count, 2)
	testing.expect_value(t, enemy.count, 2)

	// Verify characters loaded with correct abilities
	testing.expect(t, player.characters[0].ability.effect != nil, "player[0] should have an ability")
	testing.expect(t, enemy.characters[0].ability.effect != nil, "enemy[0] should have an ability")
}

@(test)
load_missing_encounter_fails :: proc(t: ^testing.T) {
	_, _, ok := game.config_load_encounter("nonexistent")
	testing.expect(t, !ok, "missing encounter should fail")
}

package game

import "core:fmt"

// --- Ability effect procedures ---
// Each takes (gs, attacker, target, roll) and applies its effect.
// gs provides full game context for abilities that need it (AoE, board, hands, etc.).

// Flurry: deal [attack] damage [MATCHES] times. Favors consistent dice.
ability_flurry :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	for _ in 0 ..< roll.matched_count {
		dmg := max(attacker.stats.attack - target.stats.defense, 0)
		target.stats.hp = max(target.stats.hp - dmg, 0)
	}
}

// Smite: deal [VALUE] damage. Favors big dice.
ability_smite :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	dmg := max(roll.matched_value - target.stats.defense, 0)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Fireball: deal [MATCHES] x [VALUE] damage. Rewards both axes.
ability_fireball :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	dmg := max(roll.matched_count * roll.matched_value - target.stats.defense, 0)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Heal: restore [VALUE] HP. Favors big dice.
ability_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	attacker.stats.hp += roll.matched_value
}

// --- Ability descriptions ---
// Same signature as Ability_Effect — full runtime context available.
// Returns a temporary cstring (ctprintf, valid for one frame).

describe_flurry :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return fmt.ctprintf("%d dmg x %d hits", attacker.stats.attack, roll.matched_count)
}

describe_smite :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return fmt.ctprintf("%d dmg", roll.matched_value)
}

describe_fireball :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return fmt.ctprintf(
		"%d x %d = %d dmg",
		roll.matched_count,
		roll.matched_value,
		roll.matched_count * roll.matched_value,
	)
}

describe_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return fmt.ctprintf("+%d HP", roll.matched_value)
}

describe_resolve_warrior :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return "10 dmg (ignores DEF)"
}

describe_resolve_mass_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return "+8 HP to all allies"
}

describe_resolve_goblin :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return "+10 HP"
}

// --- Resolve ability effects ---

// Warrior resolve: deal 10 flat damage ignoring defense.
ability_resolve_warrior :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	target.stats.hp = max(target.stats.hp - 10, 0)
}

// Healer resolve: heal all alive player party members for 8 HP.
ability_resolve_mass_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	for i in 0 ..< gs.player_party.count {
		ch := &gs.player_party.characters[i]
		if character_is_alive(ch) {
			ch.stats.hp += 8
		}
	}
}

// Goblin resolve: heal 10 HP.
ability_resolve_goblin :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	attacker.stats.hp += 10
}

// --- Ability resolution ---

// Resolve abilities after a roll. Checks the main ability's min_matches threshold
// and calls the effect if met. Charges resolve from unmatched dice.
// Auto-triggers resolve ability when meter is full.
handle_abilities :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character) {
	roll := &attacker.roll

	// Main ability
	if roll.matched_count >= attacker.ability.min_matches && attacker.ability.effect != nil {
		attacker.ability.effect(gs, attacker, target, roll)
		attacker.ability_fired = true
	} else {
		attacker.ability_fired = false
	}

	// Charge resolve from unmatched dice
	attacker.resolve += roll.unmatched_count

	// Auto-trigger resolve ability when meter is full
	if attacker.resolve >= attacker.resolve_max && attacker.resolve_ability.effect != nil {
		attacker.resolve_ability.effect(gs, attacker, target, roll)
		attacker.resolve_fired = true
		attacker.resolve = 0
	} else {
		attacker.resolve_fired = false
	}
}

// --- Character templates ---
//
// Character definitions have moved to data/characters/*.cfg.
// Templates are loaded via config_load_character() in config.odin.
// Effect procs above remain here; the config system references them by name
// through the lookup tables in config.odin.

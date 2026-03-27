package game

import "core:fmt"

// --- Ability effect procedures ---
// Each takes (gs, attacker, target, roll) and applies its effect.
// gs provides full game context for abilities that need it (AoE, board, hands, etc.).

// Flurry: deal [attack] damage [MATCHES] times. Favors consistent dice.
ability_flurry :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	for _ in 0 ..< roll.matched_count {
		dmg := max(attacker.stats.attack - target.stats.defense, 0)
		target.stats.hp = max(target.stats.hp - dmg, 0)
	}
}

// Smite: deal [VALUE] damage. Favors big dice.
ability_smite :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	dmg := max(roll.matched_value - target.stats.defense, 0)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Fireball: deal [MATCHES] x [VALUE] damage. Rewards both axes.
ability_fireball :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	dmg := max(roll.matched_count * roll.matched_value - target.stats.defense, 0)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Heal: restore [VALUE] HP. Favors big dice.
ability_heal :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	attacker.stats.hp += roll.matched_value
}

// --- Ability descriptions ---
// Same signature as Ability_Effect — full runtime context available.
// Returns a temporary cstring (ctprintf, valid for one frame).

describe_flurry :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return fmt.ctprintf("%d dmg x %d hits", attacker.stats.attack, roll.matched_count)
}

describe_smite :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return fmt.ctprintf("%d dmg", roll.matched_value)
}

describe_fireball :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return fmt.ctprintf("%d x %d = %d dmg", roll.matched_count, roll.matched_value, roll.matched_count * roll.matched_value)
}

describe_heal :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return fmt.ctprintf("+%d HP", roll.matched_value)
}

describe_resolve_warrior :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return "10 dmg (ignores DEF)"
}

describe_resolve_goblin :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
	return "+10 HP"
}

// --- Resolve ability effects ---

// Warrior resolve: deal 10 flat damage ignoring defense.
ability_resolve_warrior :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	target.stats.hp = max(target.stats.hp - 10, 0)
}

// Goblin resolve: heal 10 HP.
ability_resolve_goblin :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
	attacker.stats.hp += 10
}

// --- Ability resolution ---

// Resolve abilities after a roll. Checks the main ability's min_matches threshold
// and calls the effect if met. Charges resolve from unmatched dice.
// Auto-triggers resolve ability when meter is full.
resolve_abilities :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character) {
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

warrior_create :: proc() -> Character {
	ch := character_create("Warrior", .Common, Character_Stats {
		hp      = 20,
		attack  = 3,
		defense = 1,
	})
	ch.ability = Ability {
		name            = "Flurry",
		scaling         = .Match,
		min_matches     = 2,
		effect          = ability_flurry,
		describe        = describe_flurry,
		static_describe = "[attack] dmg x [MATCHES] hits",
	}
	ch.resolve_ability = Ability {
		name            = "Heroic Strike",
		scaling         = .Match,
		min_matches     = 0,
		effect          = ability_resolve_warrior,
		describe        = describe_resolve_warrior,
		static_describe = "10 dmg, ignores DEF",
	}
	ch.resolve_max = 5
	return ch
}

healer_create :: proc() -> Character {
	ch := character_create("Healer", .Common, Character_Stats {
		hp      = 16,
		attack  = 1,
		defense = 0,
	})
	ch.ability = Ability {
		name            = "Heal",
		scaling         = .Value,
		min_matches     = 2,
		effect          = ability_heal,
		describe        = describe_heal,
		static_describe = "+[VALUE] HP",
	}
	ch.resolve_ability = Ability {
		name            = "Mass Heal",
		scaling         = .Match,
		min_matches     = 0,
		effect          = ability_resolve_warrior, // placeholder: same as warrior for now
		describe        = describe_resolve_warrior,
		static_describe = "(not yet implemented)",
	}
	ch.resolve_max = 5
	return ch
}

goblin_create :: proc() -> Character {
	ch := character_create("Goblin", .Common, Character_Stats {
		hp      = 15,
		attack  = 2,
		defense = 0,
	})
	ch.ability = Ability {
		name            = "Fireball",
		scaling         = .Hybrid,
		min_matches     = 2,
		effect          = ability_fireball,
		describe        = describe_fireball,
		static_describe = "[MATCHES] x [VALUE] dmg",
	}
	ch.resolve_ability = Ability {
		name            = "Goblin Rally",
		scaling         = .Match,
		min_matches     = 0,
		effect          = ability_resolve_goblin,
		describe        = describe_resolve_goblin,
		static_describe = "+10 HP",
	}
	ch.resolve_max = 5
	return ch
}

shaman_create :: proc() -> Character {
	ch := character_create("Shaman", .Common, Character_Stats {
		hp      = 12,
		attack  = 1,
		defense = 0,
	})
	ch.ability = Ability {
		name            = "Smite",
		scaling         = .Value,
		min_matches     = 2,
		effect          = ability_smite,
		describe        = describe_smite,
		static_describe = "[VALUE] dmg",
	}
	ch.resolve_ability = Ability {
		name            = "Dark Ritual",
		scaling         = .Match,
		min_matches     = 0,
		effect          = ability_resolve_goblin,
		describe        = describe_resolve_goblin,
		static_describe = "+10 HP",
	}
	ch.resolve_max = 5
	return ch
}

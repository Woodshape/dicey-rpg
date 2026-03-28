package game

import "core:fmt"

// Find which party the attacker belongs to. Used by AoE abilities
// that need to heal/buff allies without hardcoding a side.
attacker_party :: proc(gs: ^Game_State, attacker: ^Character) -> ^Party {
	for i in 0 ..< gs.player_party.count {
		if &gs.player_party.characters[i] == attacker {
			return &gs.player_party
		}
	}
	for i in 0 ..< gs.enemy_party.count {
		if &gs.enemy_party.characters[i] == attacker {
			return &gs.enemy_party
		}
	}
	return nil
}

// --- Ability effect procedures ---
// Each takes (gs, attacker, target, roll) and applies its effect.
// gs provides full game context for abilities that need it (AoE, board, hands, etc.).

// Flurry: deal [VALUE] damage [MATCHES] times. Both axes matter:
// small dice = more hits (high [MATCHES]), big dice = harder hits (high [VALUE]).
ability_flurry :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	for _ in 0 ..< roll.matched_count {
		dmg := max(roll.matched_value - character_effective_defense(target), 0)
		dmg -= condition_absorb_damage(target, dmg)
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
	dmg := max(roll.matched_value - character_effective_defense(target), 0)
	dmg -= condition_absorb_damage(target, dmg)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Fireball: deal [MATCHES] x [VALUE] damage. Rewards both axes.
ability_fireball :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	dmg := max(roll.matched_count * roll.matched_value - character_effective_defense(target), 0)
	dmg -= condition_absorb_damage(target, dmg)
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

// Shield: apply Shield absorbing [VALUE] total damage to lowest-HP alive ally.
// Big dice = stronger shield. d4 Shield absorbs ~2-4; d12 Shield absorbs up to 12.
ability_shield :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	party := attacker_party(gs, attacker)
	if party == nil {return}

	// Find lowest-HP alive ally
	best: ^Character = nil
	for i in 0 ..< party.count {
		ch := &party.characters[i]
		if !character_is_alive(ch) {continue}
		if best == nil || ch.stats.hp < best.stats.hp {
			best = ch
		}
	}

	if best != nil {
		// value = absorption pool = [VALUE] from the roll
		condition_apply(best, .Shield, roll.matched_value, .On_Hit_Taken, 1)
	}
}

// Hex: reduce target's DEF by 1 for 3 turns.
ability_hex :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	condition_apply(target, .Hex, 1, .Turns, 3)
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
	return fmt.ctprintf("%d dmg x %d hits", roll.matched_value, roll.matched_count)
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

describe_shield :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	// Find who would be shielded (lowest HP alive ally)
	party := attacker_party(gs, attacker)
	if party != nil {
		best: ^Character = nil
		for i in 0 ..< party.count {
			ch := &party.characters[i]
			if !character_is_alive(ch) {continue}
			if best == nil || ch.stats.hp < best.stats.hp {
				best = ch
			}
		}
		if best != nil {
			return fmt.ctprintf("Shield %d -> %s", roll.matched_value, best.name)
		}
	}
	return fmt.ctprintf("Shield %d", roll.matched_value)
}

describe_hex :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return fmt.ctprintf("-1 DEF on %s (3 turns)", target.name)
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

describe_resolve_goblin_explosion :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return "6 dmg to all enemies"
}

describe_resolve_shaman_nuke :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	return "15 dmg (ignores DEF)"
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

// Healer resolve: heal all alive allies for 8 HP.
// Finds the attacker's party dynamically so it works for both sides.
ability_resolve_mass_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	party := attacker_party(gs, attacker)
	if party == nil {
		return
	}
	for i in 0 ..< party.count {
		ch := &party.characters[i]
		if character_is_alive(ch) {
			ch.stats.hp += 8
		}
	}
}

// Goblin resolve: deal 6 damage to all enemies.
ability_resolve_goblin_explosion :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	// Find the opposing party
	own_party := attacker_party(gs, attacker)
	enemy_party: ^Party
	if own_party == &gs.player_party {
		enemy_party = &gs.enemy_party
	} else {
		enemy_party = &gs.player_party
	}

	for i in 0 ..< enemy_party.count {
		ch := &enemy_party.characters[i]
		if !character_is_alive(ch) {continue}
		dmg := max(6 - character_effective_defense(ch), 0)
		dmg -= condition_absorb_damage(ch, dmg)
		ch.stats.hp = max(ch.stats.hp - dmg, 0)
	}
}

// Shaman resolve: deal 15 damage ignoring defense.
ability_resolve_shaman_nuke :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	dmg := 15
	dmg -= condition_absorb_damage(target, dmg)
	target.stats.hp = max(target.stats.hp - dmg, 0)
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

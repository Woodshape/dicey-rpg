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
// gs provides full game context for abilities that need it (AoE, pool, hands, etc.).

// Flurry: deal [VALUE] damage [MATCHES] times. Both axes matter.
// Enhanced: ignores DEF (piercing).
ability_flurry :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	for _ in 0 ..< roll.matched_count {
		dmg := enhanced ? roll.matched_value : max(roll.matched_value - character_effective_defense(target), 0)
		dmg -= condition_absorb_damage(target, dmg)
		target.stats.hp = max(target.stats.hp - dmg, 0)
	}
}

// Smite: deal [VALUE] damage. Favors big dice.
// Enhanced: ignores DEF (piercing).
ability_smite :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	dmg := enhanced ? roll.matched_value : max(roll.matched_value - character_effective_defense(target), 0)
	dmg -= condition_absorb_damage(target, dmg)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Fireball: deal [MATCHES] x [VALUE] damage. Rewards both axes.
// Enhanced: ignores DEF (piercing).
ability_fireball :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	raw := roll.matched_count * roll.matched_value
	dmg := enhanced ? raw : max(raw - character_effective_defense(target), 0)
	dmg -= condition_absorb_damage(target, dmg)
	target.stats.hp = max(target.stats.hp - dmg, 0)
}

// Heal: restore [VALUE] HP to self. Favors big dice.
// Enhanced: also heals lowest-HP alive ally for [VALUE].
ability_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	attacker.stats.hp += roll.matched_value

	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced && gs != nil {
		party := attacker_party(gs, attacker)
		if party != nil {
			best: ^Character = nil
			for i in 0 ..< party.count {
				ch := &party.characters[i]
				if !character_is_alive(ch) {continue}
				if ch == attacker {continue}
				if best == nil || ch.stats.hp < best.stats.hp {
					best = ch
				}
			}
			if best != nil {
				best.stats.hp += roll.matched_value
			}
		}
	}
}

// Shield: apply Shield absorbing [VALUE] total damage to lowest-HP alive ally.
// Enhanced: shields ALL alive allies instead of just lowest-HP.
ability_shield :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	party := attacker_party(gs, attacker)
	if party == nil {return}

	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)

	if enhanced {
		// Shield all alive allies
		for i in 0 ..< party.count {
			ch := &party.characters[i]
			if !character_is_alive(ch) {continue}
			ok := condition_apply(ch, .Shield, roll.matched_value, .On_Hit_Taken, 1)
			if ok { trace_cond(&gs.trace, find_char_tag(gs, ch), ch, &ch.conditions[ch.condition_count - 1]) }
		}
	} else {
		// Shield lowest-HP alive ally
		best: ^Character = nil
		for i in 0 ..< party.count {
			ch := &party.characters[i]
			if !character_is_alive(ch) {continue}
			if best == nil || ch.stats.hp < best.stats.hp {
				best = ch
			}
		}
		if best != nil {
			ok := condition_apply(best, .Shield, roll.matched_value, .On_Hit_Taken, 1)
			if ok { trace_cond(&gs.trace, find_char_tag(gs, best), best, &best.conditions[best.condition_count - 1]) }
		}
	}
}

// Hex: reduce target's DEF by 1 for 3 turns.
// Enhanced: -2 DEF instead of -1.
ability_hex :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	hex_value := enhanced ? 2 : 1
	ok := condition_apply(target, .Hex, hex_value, .Turns, 3)
	if ok && gs != nil { trace_cond(&gs.trace, find_char_tag(gs, target), target, &target.conditions[target.condition_count - 1]) }
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
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("%d dmg x %d hits (PIERCING)", roll.matched_value, roll.matched_count)
	}
	return fmt.ctprintf("%d dmg x %d hits", roll.matched_value, roll.matched_count)
}

describe_smite :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("%d dmg (PIERCING)", roll.matched_value)
	}
	return fmt.ctprintf("%d dmg", roll.matched_value)
}

describe_fireball :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	total := roll.matched_count * roll.matched_value
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("%d x %d = %d dmg (PIERCING)", roll.matched_count, roll.matched_value, total)
	}
	return fmt.ctprintf("%d x %d = %d dmg", roll.matched_count, roll.matched_value, total)
}

describe_heal :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("+%d HP (PARTY HEAL)", roll.matched_value)
	}
	return fmt.ctprintf("+%d HP", roll.matched_value)
}

describe_shield :: proc(
	gs: ^Game_State,
	attacker: ^Character,
	target: ^Character,
	roll: ^Roll_Result,
) -> cstring {
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("Shield %d (PARTY SHIELD)", roll.matched_value)
	}
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
	enhanced := ability_is_enhanced(&attacker.ability, roll.matched_value)
	if enhanced {
		return fmt.ctprintf("-2 DEF on %s (DEEP HEX, 3 turns)", target.name)
	}
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

// --- Passive ability effects ---
// Same signature as Passive_Effect. Called at trigger-specific points in the game loop.
// For On_Roll: owner=self, context_char=target, roll=self's roll.
// For On_Ally_Damaged: owner=passive owner, context_char=ally who took damage, roll=nil.

// Tenacity (Warrior): after rolling, if no match, heal 1 HP.
// Mirrors Scavenger (chip damage on miss) with chip sustain — Warrior outlasts opponents
// through sheer stubbornness. Only fires when normal dice miss (not skulls-only).
passive_tenacity :: proc(gs: ^Game_State, owner: ^Character, context_char: ^Character, roll: ^Roll_Result) {
	if roll == nil {return}
	if roll.matched_count > 0 {return}
	if roll.unmatched_count == 0 {return}
	owner.stats.hp += 1
	owner.passive_fired = true
}

// Empathy (Healer): when any ally takes damage, gain +1 resolve.
// Trigger: On_Ally_Damaged. context_char = the ally who took damage (not the attacker).
passive_empathy :: proc(gs: ^Game_State, owner: ^Character, context_char: ^Character, roll: ^Roll_Result) {
	// Don't charge if owner is dead or resolve is already full
	if !character_is_alive(owner) {return}
	if owner.resolve >= owner.resolve_max {return}
	owner.resolve = min(owner.resolve + 1, owner.resolve_max)
	owner.passive_fired = true
}

// Scavenger (Goblin): after rolling, if no match, deal 2 flat damage (ignores DEF).
passive_scavenger :: proc(gs: ^Game_State, owner: ^Character, context_char: ^Character, roll: ^Roll_Result) {
	if roll == nil || context_char == nil {return}
	if roll.matched_count > 0 {return}
	// Only fire if there were normal dice rolled (not skulls-only)
	if roll.unmatched_count == 0 {return}
	dmg := 2
	dmg -= condition_absorb_damage(context_char, dmg)
	context_char.stats.hp = max(context_char.stats.hp - dmg, 0)
	owner.passive_fired = true
}

// Curse Weaver (Shaman): after rolling, deal 1 damage per active condition on target (ignores DEF).
passive_curse_weaver :: proc(gs: ^Game_State, owner: ^Character, context_char: ^Character, roll: ^Roll_Result) {
	if context_char == nil {return}
	if context_char.condition_count <= 0 {return}
	dmg := context_char.condition_count
	dmg -= condition_absorb_damage(context_char, dmg)
	context_char.stats.hp = max(context_char.stats.hp - dmg, 0)
	owner.passive_fired = true
}

// --- Character templates ---
//
// Character definitions have moved to data/characters/*.cfg.
// Templates are loaded via config_load_character() in config.odin.
// Effect procs above remain here; the config system references them by name
// through the lookup tables in config.odin.

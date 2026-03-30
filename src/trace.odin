package game

import "core:fmt"
import "core:os"

TRACE_FILE_PATH :: "game_log.txt"

// Initialize the trace file. Writes the header (SEED, ENCOUNTER).
// Called once at game start. Enables trace recording.
// path defaults to TRACE_FILE_PATH ("game_log.txt").
trace_init :: proc(trace: ^Trace_Log, seed: u64, encounter: string, path: string = TRACE_FILE_PATH) {
	fd, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	if err != nil {
		fmt.eprintfln("trace: failed to open %s for writing", path)
		return
	}
	trace.file_handle = fd
	trace.file_enabled = true

	trace_write(trace, "SEED %d", seed)
	trace_write(trace, "ENCOUNTER %s", encounter)
}

// Write one line to the trace file.
trace_write :: proc(trace: ^Trace_Log, format: string, args: ..any) {
	if !trace.file_enabled {return}
	buf: [512]u8
	result := fmt.bprintf(buf[:], format, ..args)
	os.write(trace.file_handle, buf[:len(result)])
	os.write_string(trace.file_handle, "\n")
}

// Close the trace file handle.
trace_close :: proc(trace: ^Trace_Log) {
	if !trace.file_enabled {return}
	os.close(trace.file_handle)
	trace.file_enabled = false
}

// Return the stable identifier for a character: "p0"–"p3" for player, "e0"–"e3" for enemy.
// Uses the temp allocator — caller must not hold the string across a temp_allocator reset.
find_char_tag :: proc(gs: ^Game_State, ch: ^Character) -> string {
	if ch == nil {return "nil"}
	for i in 0 ..< gs.player_party.count {
		if &gs.player_party.characters[i] == ch {
			return fmt.tprintf("p%d", i)
		}
	}
	for i in 0 ..< gs.enemy_party.count {
		if &gs.enemy_party.characters[i] == ch {
			return fmt.tprintf("e%d", i)
		}
	}
	return "??"
}

// --- Trace helpers for recording specific actions ---

// Record a ROUND marker.
trace_round :: proc(trace: ^Trace_Log, round_number: int) {
	trace_write(trace, "ROUND %d", round_number)
}

// Record a PICK action: side tag, pool_index, die_type, destination.
// side: "p" or "e". dest_kind: "hand" or "char", dest_index: character index (only for "char").
trace_pick :: proc(trace: ^Trace_Log, side: string, pool_index: int, die_type: Die_Type, to_hand: bool, char_index: int = 0) {
	name := DIE_TYPE_NAMES[die_type]
	if to_hand {
		trace_write(trace, "PICK %s %d %s hand", side, pool_index, name)
	} else {
		trace_write(trace, "PICK %s %d %s char %d", side, pool_index, name, char_index)
	}
}

// Record a ROLL action: side tag, character index + assigned dice as ground truth.
trace_roll :: proc(trace: ^Trace_Log, side: string, char_index: int, character: ^Character) {
	if !trace.file_enabled {return}

	// Build the dice list string
	buf: [128]u8
	pos := 0
	result := fmt.bprintf(buf[:], "ROLL %s %d", side, char_index)
	pos = len(result)

	for i in 0 ..< character.assigned_count {
		name := DIE_TYPE_NAMES[character.assigned[i]]
		space := fmt.bprintf(buf[pos:], " %s", name)
		pos += len(space)
	}

	buf[pos] = 0
	os.write(trace.file_handle, buf[:pos])
	os.write_string(trace.file_handle, "\n")
}

// Record a DISCARD action: side tag, hand_index, die_type.
trace_discard :: proc(trace: ^Trace_Log, side: string, hand_index: int, die_type: Die_Type) {
	trace_write(trace, "DISCARD %s %d %s", side, hand_index, DIE_TYPE_NAMES[die_type])
}

// Record an ASSIGN action: side tag, hand die moved to a character slot (free action).
trace_assign :: proc(trace: ^Trace_Log, side: string, hand_index: int, die_type: Die_Type, char_index: int) {
	trace_write(trace, "ASSIGN %s %d %s char %d", side, hand_index, DIE_TYPE_NAMES[die_type], char_index)
}

// Record a DONE action: side tag (side finishes rolling).
trace_done :: proc(trace: ^Trace_Log, side: string) {
	trace_write(trace, "DONE %s", side)
}

// --- Event trace procs (diagnostics only, not used for replay) ---
//
// All event lines use a stable <tag> identifier ("p0"–"p3" for player,
// "e0"–"e3" for enemy) as the first token after the keyword.
// Names follow the tag for human readability, but only the tag is unique.

// VALUES <tag> <name> <v1> <v2> ...  (only normal dice values, skulls omitted)
trace_values :: proc(trace: ^Trace_Log, tag: string, attacker: ^Character) {
	if !trace.file_enabled {return}

	buf: [512]u8
	pos := 0
	roll := &attacker.roll

	name_part := fmt.bprintf(buf[:], "VALUES %s %s", tag, attacker.name)
	pos = len(name_part)

	for i in 0 ..< roll.count {
		if roll.skulls[i] == 1 {continue}
		v := roll.values[i]
		digit := fmt.bprintf(buf[pos:], " %d", v)
		pos += len(digit)
	}

	os.write(trace.file_handle, buf[:pos])
	os.write_string(trace.file_handle, "\n")
}

// SKULL <atag> <attacker> <count> <dmg> <ttag> <target>
trace_skull :: proc(trace: ^Trace_Log, atag: string, attacker: ^Character, ttag: string, target: ^Character, count: int, dmg: int) {
	trace_write(trace, "SKULL %s %s %d %d %s %s", atag, attacker.name, count, dmg, ttag, target.name)
}

// MATCH <tag> <name> <matched_count> <matched_value>  (0 0 if no match)
trace_match :: proc(trace: ^Trace_Log, tag: string, attacker: ^Character) {
	trace_write(
		trace,
		"MATCH %s %s %d %d",
		tag,
		attacker.name,
		attacker.roll.matched_count,
		attacker.roll.matched_value,
	)
}

// HP <tag> <name> <hp>
trace_hp :: proc(trace: ^Trace_Log, tag: string, ch: ^Character) {
	trace_write(trace, "HP %s %s %d", tag, ch.name, ch.stats.hp)
}

// DEAD <tag> <name>
trace_dead :: proc(trace: ^Trace_Log, tag: string, ch: ^Character) {
	trace_write(trace, "DEAD %s %s", tag, ch.name)
}

// Write an ability name with spaces replaced by underscores into buf starting at pos.
// Returns the new pos after writing.
@(private = "file")
write_ability_name :: proc(buf: []u8, pos: int, name: cstring) -> int {
	p := pos
	bytes := ([^]u8)(name)
	for i := 0; bytes[i] != 0; i += 1 {
		c := bytes[i]
		if c == ' ' {
			buf[p] = '_'
		} else {
			buf[p] = c
		}
		p += 1
	}
	return p
}

// ABILITY <atag> <attacker> <ability_name_underscored> <effect_type> <amount> <ttag> <target>
// effect_type: "DMG", "HEAL", or "NONE". amount is 0 for NONE.
// target may be nil — "nil" is written for both ttag and target name in that case.
trace_ability :: proc(trace: ^Trace_Log, atag: string, attacker: ^Character, ttag: string, target: ^Character, dmg: int, heal: int) {
	if !trace.file_enabled {return}

	effect_type: cstring
	amount: int
	if heal > 0 {
		effect_type = "HEAL"
		amount = heal
	} else if dmg > 0 {
		effect_type = "DMG"
		amount = dmg
	} else {
		effect_type = "NONE"
		amount = 0
	}

	target_name: cstring = "nil"
	if target != nil {
		target_name = target.name
	}

	buf: [512]u8
	pos := 0

	prefix := fmt.bprintf(buf[:], "ABILITY %s %s ", atag, attacker.name)
	pos = len(prefix)
	pos = write_ability_name(buf[:], pos, attacker.ability.name)
	suffix := fmt.bprintf(buf[pos:], " %s %d %s %s", effect_type, amount, ttag, target_name)
	pos += len(suffix)

	os.write(trace.file_handle, buf[:pos])
	os.write_string(trace.file_handle, "\n")
}

// RESOLVE <atag> <attacker> <resolve_ability_name_underscored> <effect_type> <amount> <ttag> <target>
trace_resolve_ability :: proc(trace: ^Trace_Log, atag: string, attacker: ^Character, ttag: string, target: ^Character, dmg: int, heal: int) {
	if !trace.file_enabled {return}

	effect_type: cstring
	amount: int
	if heal > 0 {
		effect_type = "HEAL"
		amount = heal
	} else if dmg > 0 {
		effect_type = "DMG"
		amount = dmg
	} else {
		effect_type = "NONE"
		amount = 0
	}

	target_name: cstring = "nil"
	if target != nil {
		target_name = target.name
	}

	buf: [512]u8
	pos := 0

	prefix := fmt.bprintf(buf[:], "RESOLVE %s %s ", atag, attacker.name)
	pos = len(prefix)
	pos = write_ability_name(buf[:], pos, attacker.resolve_ability.name)
	suffix := fmt.bprintf(buf[pos:], " %s %d %s %s", effect_type, amount, ttag, target_name)
	pos += len(suffix)

	os.write(trace.file_handle, buf[:pos])
	os.write_string(trace.file_handle, "\n")
}

// CHARGE <tag> <name> +<amount> <resolve>/<resolve_max>
// attacker.resolve has ALREADY been incremented before this is called.
trace_charge :: proc(trace: ^Trace_Log, tag: string, attacker: ^Character, amount: int) {
	trace_write(trace, "CHARGE %s %s +%d %d/%d", tag, attacker.name, amount, attacker.resolve, attacker.resolve_max)
}

// PASSIVE <tag> <name> <passive_name_underscored>
trace_passive :: proc(trace: ^Trace_Log, tag: string, attacker: ^Character) {
	if !trace.file_enabled {return}

	buf: [512]u8
	pos := 0

	prefix := fmt.bprintf(buf[:], "PASSIVE %s %s ", tag, attacker.name)
	pos = len(prefix)
	pos = write_ability_name(buf[:], pos, attacker.passive.name)

	os.write(trace.file_handle, buf[:pos])
	os.write_string(trace.file_handle, "\n")
}

// COND <tag> <name> <kind> <value> <remaining>
trace_cond :: proc(trace: ^Trace_Log, tag: string, ch: ^Character, cond: ^Condition) {
	trace_write(
		trace,
		"COND %s %s %s %d %d",
		tag,
		ch.name,
		CONDITION_NAMES[cond.kind],
		cond.value,
		cond.remaining,
	)
}


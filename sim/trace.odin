package sim

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import game "../src"

// --- Trace action types ---
//
// SEED and ENCOUNTER are parsed directly into Trace_Reader fields.
// Only replay-relevant actions appear in the actions array.

Trace_Round :: struct {
	number: int,
}

Trace_Pick :: struct {
	pool_index: int,
	die_type:   game.Die_Type,
	to_hand:    bool,
	char_index: int, // only valid when to_hand == false
}

Trace_Roll :: struct {
	char_index: int,
	dice:       [game.MAX_CHARACTER_DICE]game.Die_Type,
	dice_count: int,
}

Trace_Discard :: struct {
	hand_index: int,
	die_type:   game.Die_Type,
}

Trace_Done :: struct {}

Trace_Assign :: struct {
	hand_index: int,
	die_type:   game.Die_Type,
	char_index: int,
}

Trace_Action :: union {
	Trace_Round,
	Trace_Pick,
	Trace_Roll,
	Trace_Discard,
	Trace_Done,
	Trace_Assign,
}

// Loaded trace ready for sequential replay.
Trace_Reader :: struct {
	actions:     [dynamic]Trace_Action,
	pos:         int,
	seed:        u64,            // from SEED header
	encounter:   string,         // from ENCOUNTER header (owned)
	baseline_hp: map[string]int, // final HP per character name from HP event lines (owned keys)
}

// Load and parse a trace file. Returns false on any error.
trace_reader_load :: proc(path: string) -> (reader: Trace_Reader, ok: bool) {
	data, file_ok := os.read_entire_file(path)
	if !file_ok {
		fmt.eprintfln("trace: could not read '%s'", path)
		return
	}
	defer delete(data)

	reader.actions = make([dynamic]Trace_Action)
	reader.baseline_hp = make(map[string]int)

	line_num := 0
	text := string(data)
	for raw_line in strings.split_lines_iterator(&text) {
		line_num += 1
		line := strings.trim_space(raw_line)
		if len(line) == 0 {
			continue
		}

		parts := strings.split(line, " ")
		defer delete(parts)

		if len(parts) == 0 {
			continue
		}

		switch parts[0] {
		case "SEED":
			if len(parts) != 2 {
				fmt.eprintfln("trace: line %d: malformed SEED", line_num)
				return
			}
			seed_val, seed_ok := strconv.parse_u64(parts[1])
			if !seed_ok {
				fmt.eprintfln("trace: line %d: bad SEED value: %s", line_num, parts[1])
				return
			}
			reader.seed = seed_val

		case "ENCOUNTER":
			if len(parts) != 2 {
				fmt.eprintfln("trace: line %d: malformed ENCOUNTER", line_num)
				return
			}
			if reader.encounter != "" {
				delete(reader.encounter)
			}
			reader.encounter = strings.clone(parts[1])

		case "ROUND":
			if len(parts) != 2 {
				fmt.eprintfln("trace: line %d: malformed ROUND", line_num)
				return
			}
			n, n_ok := strconv.parse_int(parts[1])
			if !n_ok {
				fmt.eprintfln("trace: line %d: bad ROUND number: %s", line_num, parts[1])
				return
			}
			append(&reader.actions, Trace_Round{number = n})

		case "PICK":
			// PICK <pool_idx> <die_type> hand
			// PICK <pool_idx> <die_type> char <ci>
			if len(parts) < 4 {
				fmt.eprintfln("trace: line %d: malformed PICK", line_num)
				return
			}
			pool_idx, idx_ok := strconv.parse_int(parts[1])
			if !idx_ok {
				fmt.eprintfln("trace: line %d: bad PICK pool_index: %s", line_num, parts[1])
				return
			}
			die_type, dt_ok := trace_parse_die_type(parts[2])
			if !dt_ok {
				fmt.eprintfln("trace: line %d: unknown die type: %s", line_num, parts[2])
				return
			}
			pick := Trace_Pick{pool_index = pool_idx, die_type = die_type}
			switch parts[3] {
			case "hand":
				if len(parts) != 4 {
					fmt.eprintfln("trace: line %d: malformed PICK hand", line_num)
					return
				}
				pick.to_hand = true
			case "char":
				if len(parts) != 5 {
					fmt.eprintfln("trace: line %d: malformed PICK char", line_num)
					return
				}
				ci, ci_ok := strconv.parse_int(parts[4])
				if !ci_ok {
					fmt.eprintfln("trace: line %d: bad PICK char_index: %s", line_num, parts[4])
					return
				}
				pick.char_index = ci
			case:
				fmt.eprintfln("trace: line %d: unknown PICK destination: %s", line_num, parts[3])
				return
			}
			append(&reader.actions, pick)

		case "ROLL":
			// ROLL <ci> [<die> ...]
			if len(parts) < 2 {
				fmt.eprintfln("trace: line %d: malformed ROLL", line_num)
				return
			}
			ci, ci_ok := strconv.parse_int(parts[1])
			if !ci_ok {
				fmt.eprintfln("trace: line %d: bad ROLL char_index: %s", line_num, parts[1])
				return
			}
			roll := Trace_Roll{char_index = ci}
			for i in 2 ..< len(parts) {
				if roll.dice_count >= game.MAX_CHARACTER_DICE {
					fmt.eprintfln("trace: line %d: too many dice in ROLL", line_num)
					return
				}
				dt, dt_ok := trace_parse_die_type(parts[i])
				if !dt_ok {
					fmt.eprintfln("trace: line %d: unknown die type: %s", line_num, parts[i])
					return
				}
				roll.dice[roll.dice_count] = dt
				roll.dice_count += 1
			}
			append(&reader.actions, roll)

		case "DISCARD":
			if len(parts) != 3 {
				fmt.eprintfln("trace: line %d: malformed DISCARD", line_num)
				return
			}
			hand_idx, hi_ok := strconv.parse_int(parts[1])
			if !hi_ok {
				fmt.eprintfln("trace: line %d: bad DISCARD hand_index: %s", line_num, parts[1])
				return
			}
			die_type, dt_ok := trace_parse_die_type(parts[2])
			if !dt_ok {
				fmt.eprintfln("trace: line %d: unknown die type: %s", line_num, parts[2])
				return
			}
			append(&reader.actions, Trace_Discard{hand_index = hand_idx, die_type = die_type})

		case "DONE":
			if len(parts) != 1 {
				fmt.eprintfln("trace: line %d: malformed DONE", line_num)
				return
			}
			append(&reader.actions, Trace_Done{})

		case "ASSIGN":
			// ASSIGN <hand_idx> <die_type> char <ci>
			if len(parts) != 5 {
				fmt.eprintfln("trace: line %d: malformed ASSIGN", line_num)
				return
			}
			hand_idx, hi_ok := strconv.parse_int(parts[1])
			if !hi_ok {
				fmt.eprintfln("trace: line %d: bad ASSIGN hand_index: %s", line_num, parts[1])
				return
			}
			die_type, dt_ok := trace_parse_die_type(parts[2])
			if !dt_ok {
				fmt.eprintfln("trace: line %d: unknown die type: %s", line_num, parts[2])
				return
			}
			if parts[3] != "char" {
				fmt.eprintfln("trace: line %d: expected 'char' in ASSIGN, got: %s", line_num, parts[3])
				return
			}
			ci, ci_ok := strconv.parse_int(parts[4])
			if !ci_ok {
				fmt.eprintfln("trace: line %d: bad ASSIGN char_index: %s", line_num, parts[4])
				return
			}
			append(&reader.actions, Trace_Assign{hand_index = hand_idx, die_type = die_type, char_index = ci})

		case "HP":
			// Event line — HP <tag> <name> <hp>
			// Keyed by tag (e.g. "p0", "e1") which is unique unlike names.
			// Multiple HP lines per character are expected; last one wins.
			if len(parts) >= 4 {
				hp_val, hp_ok := strconv.parse_int(parts[3])
				if hp_ok {
					key := parts[1] // tag
					if key in reader.baseline_hp {
						reader.baseline_hp[key] = hp_val
					} else {
						reader.baseline_hp[strings.clone(key)] = hp_val
					}
				}
			}

		case "VALUES", "SKULL", "MATCH", "ABILITY", "RESOLVE", "CHARGE", "PASSIVE",
		     "DEAD", "COND", "EPICK", "EROLL", "EDONE":
			// Event lines — diagnostics only, not used for replay
			continue

		case:
			fmt.eprintfln("trace: line %d: unknown keyword: %s", line_num, parts[0])
			return
		}
	}

	ok = true
	return
}

// Free memory owned by the reader.
trace_reader_destroy :: proc(reader: ^Trace_Reader) {
	delete(reader.encounter)
	delete(reader.actions)
	for k in reader.baseline_hp {
		delete(k)
	}
	delete(reader.baseline_hp)
}

// Peek at the next action without consuming it. Returns nil union variant if exhausted.
trace_peek :: proc(reader: ^Trace_Reader) -> (Trace_Action, bool) {
	if reader.pos >= len(reader.actions) {
		return nil, false
	}
	return reader.actions[reader.pos], true
}

// Return the next action and advance position.
trace_next :: proc(reader: ^Trace_Reader) -> (Trace_Action, bool) {
	if reader.pos >= len(reader.actions) {
		return nil, false
	}
	action := reader.actions[reader.pos]
	reader.pos += 1
	return action, true
}

// Parse a die type name string into Die_Type. Returns (.None, false) on unknown name.
trace_parse_die_type :: proc(s: string) -> (game.Die_Type, bool) {
	for dt in game.Die_Type {
		if string(game.DIE_TYPE_NAMES[dt]) == s {
			return dt, true
		}
	}
	return .None, false
}

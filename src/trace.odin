package game

import "core:fmt"
import "core:os"

TRACE_FILE_PATH :: "decision_trace.txt"

// Initialize the trace file. Writes the header (SEED, ENCOUNTER).
// Called once at game start. Enables trace recording.
trace_init :: proc(trace: ^Trace_Log, seed: u64, encounter: string) {
	fd, err := os.open(TRACE_FILE_PATH, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	if err != nil {
		fmt.eprintfln("trace: failed to open %s for writing", TRACE_FILE_PATH)
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
	buf: [256]u8
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

// --- Trace helpers for recording specific actions ---

// Record a ROUND marker.
trace_round :: proc(trace: ^Trace_Log, round_number: int) {
	trace_write(trace, "ROUND %d", round_number)
}

// Record a PICK action: pool_index, die_type, destination.
// dest_kind: "hand" or "char", dest_index: character index (only for "char").
trace_pick :: proc(trace: ^Trace_Log, pool_index: int, die_type: Die_Type, to_hand: bool, char_index: int = 0) {
	name := DIE_TYPE_NAMES[die_type]
	if to_hand {
		trace_write(trace, "PICK %d %s hand", pool_index, name)
	} else {
		trace_write(trace, "PICK %d %s char %d", pool_index, name, char_index)
	}
}

// Record a ROLL action: character index + assigned dice as ground truth.
trace_roll :: proc(trace: ^Trace_Log, char_index: int, character: ^Character) {
	if !trace.file_enabled {return}

	// Build the dice list string
	buf: [128]u8
	pos := 0
	result := fmt.bprintf(buf[:], "ROLL %d", char_index)
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

// Record a DISCARD action.
trace_discard :: proc(trace: ^Trace_Log, hand_index: int, die_type: Die_Type) {
	trace_write(trace, "DISCARD %d %s", hand_index, DIE_TYPE_NAMES[die_type])
}

// Record a DONE action (player skips remaining rolls).
trace_done :: proc(trace: ^Trace_Log) {
	trace_write(trace, "DONE")
}

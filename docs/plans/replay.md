# Replay System — Implementation Plan

## Goal

Record player decisions during a real game into a machine-readable trace file. The simulator replays the trace with modified stats/abilities to show how balance changes affect the same game. Replaces `combat_log.txt` as the persistent debug record.

## Design Decisions

- **Trace file replaces combat_log.txt** — the trace is the persistent session record. The in-game scrolling log stays for player feedback but no longer writes to disk.
- **Pool index + die type** for human readability: `PICK 2 d6 hand`
- **Final assignment state** recorded inline with ROLL, not as individual ASSIGN actions. Self-verifying: if the assignments don't match, replay fails immediately.
- **Space-separated tokens** — simple to parse with `strings.split`.
- **Seed recorded in header** — replay uses the same seed for RNG.
- **Invalid decisions fail hard** — no silent skipping.

## Trace Format

```
SEED 1774786456
ENCOUNTER tutorial
ROUND 1
PICK 2 d6 hand
PICK 0 d8 char 1
ROUND 2
PICK 3 d10 hand
DISCARD 2 d4
ROLL 0 d6 d6 Skl
ROLL 1 d8 d8 d8
DONE
ROUND 3
PICK 1 Skl char 0
...
```

### Action Lines

| Action | Format | Description |
|--------|--------|-------------|
| `SEED` | `SEED <n>` | RNG seed for this game |
| `ENCOUNTER` | `ENCOUNTER <name>` | Encounter config name |
| `ROUND` | `ROUND <n>` | Round boundary marker |
| `PICK` | `PICK <pool_idx> <die_type> <dest>` | Pick from pool. `<dest>` = `hand` or `char <ci>` |
| `ROLL` | `ROLL <ci> <die> [<die> ...]` | Roll character `ci` with listed dice assigned. Dice list is the ground truth for validation. |
| `DISCARD` | `DISCARD <hand_idx> <die_type>` | Discard from hand. Die type for readability. |
| `DONE` | `DONE` | Player skips remaining rolls (Done button) |

### Validation on Replay

Before executing each action, verify the precondition:
- `PICK`: pool slot exists, die type matches, destination accepts the die
- `ROLL`: character index valid, assigned dice match the listed types exactly
- `DISCARD`: hand slot exists, die type matches
- `DONE`: it's the player's combat turn

On mismatch: print the expected vs actual state and abort.

## Implementation Steps

### Phase 1: Trace Writer (game side)

Add trace recording to the live game. Writes `decision_trace.txt` alongside gameplay.

1. Add `Trace_Log` struct to `types.odin` — file handle, enabled flag
2. Add `trace_log` field to `Game_State`
3. `trace_init(trace)` — open file, write SEED and ENCOUNTER header
4. `trace_write(trace, format, args)` — append one line
5. Wire trace calls into:
   - `draft_player_pick_update` → after successful pool pick: `PICK`
   - `combat_player_turn_update` → after roll button: `ROLL` (with assigned dice)
   - `combat_player_turn_update` → after done button: `DONE`
   - Discard sites → `DISCARD`
   - Round transitions → `ROUND`
6. Remove `combat_log_init_file` / file output from combat log (keep in-game ring buffer only)

### Phase 2: Trace Reader (simulator side)

Add `--replay=<file>` mode to the simulator. Reads the trace and feeds decisions instead of AI.

1. `Trace_Reader` struct — loaded actions array, current position
2. `trace_load(path)` — read file, parse into action array
3. `trace_next(reader)` → next action (or error if exhausted)
4. New `run_replay` proc in `sim/main.odin`:
   - Read SEED and ENCOUNTER from header
   - Init game with that seed
   - Game loop: for each phase, read the next trace action and execute it
   - Draft player picks → read PICK, execute `pool_remove_die` + `hand_add`/`character_assign_die`
   - Combat player turn → read ROLL/DONE, validate assignments, execute `character_roll` + `resolve_roll`
   - Enemy turns → still AI-driven (same as normal sim)
   - On ROUND marker → verify round number matches
5. Validation at each step: compare trace expectations against game state
6. On completion: print outcome, compare against original

### Phase 3: Diff Output

After replay, show what changed:
- Same outcome? Different HP values? Different round count?
- Per-character damage dealt/taken comparison
- Which rolls produced different results (if ability formulas changed)

This is a nice-to-have — Phase 1+2 are the core.

## File Changes

### Phase 1 (trace writer)
- `src/types.odin` — `Trace_Log` struct
- `src/game.odin` — init trace in `game_init`, add to `Game_State`
- `src/combat.odin` — trace calls at decision points
- `src/combat_log.odin` — remove file output (keep ring buffer)
- `src/main.odin` — init trace on startup

### Phase 2 (trace reader)
- `sim/trace.odin` — new file: `Trace_Reader`, `trace_load`, `trace_next`, action types
- `sim/main.odin` — `--replay` arg, `run_replay` proc

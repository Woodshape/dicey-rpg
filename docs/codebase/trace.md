# Trace — Unified Game Log

**File:** `src/trace.odin`
**Output:** `game_log.txt`

## Responsibilities

- Write every player decision (PICK, ROLL, DISCARD, DONE, ASSIGN) to `game_log.txt` for replay
- Write every outcome event (VALUES, SKULL, MATCH, ABILITY, RESOLVE, CHARGE, HP, etc.) to `game_log.txt` for diagnostics
- Provide the only persistent out-of-game record of a session

This replaces the old `combat_log.txt` file output. The in-game ring buffer (`Combat_Log`) remains for the player but no longer writes to disk.

## Architecture

### Trace_Log Struct

`Trace_Log` lives on `Game_State`. It holds the file handle and an `enabled` flag.

```odin
Trace_Log :: struct {
    file_handle:  os.Handle,
    file_enabled: bool,
}
```

### Lifecycle

- `trace_init(trace, seed, encounter)` — called once at startup. Opens `game_log.txt` (truncates if it exists), writes `SEED` and `ENCOUNTER` header lines, sets `file_enabled = true`.
- `trace_close(trace)` — called on exit. Closes the file handle.
- `trace_round(trace, n)` — called at the start of each round to write a `ROUND N` marker.

### Two Line Classes

Every line in `game_log.txt` is one of two classes:

**Decision lines** — drive replay in `sim/main.odin`:

Every decision line carries a side tag: `p` for player, `e` for enemy. This replaces the old `EPICK`/`EROLL`/`EDONE` prefixes — all decisions now use a unified format.

```
SEED <u64>
ENCOUNTER <name>
ROUND <n>
PICK <side> <pool_idx> <die_type> hand
PICK <side> <pool_idx> <die_type> char <ci>
ASSIGN <side> <hand_idx> <die_type> char <ci>
ROLL <side> <ci> <die1> <die2> ...
DISCARD <side> <hand_idx> <die_type>
DONE <side>
```

`<side>` is `p` (player) or `e` (enemy). Side-level actions like `DONE` and `PICK ... hand` use the bare side tag since they don't target a specific character. Character-level event lines (see below) use `p0`–`p3` / `e0`–`e3` tags instead.

`ASSIGN` records hand→character drag moves (free action, no turn cost). `ROLL` still records the final assigned dice as ground truth — the replay uses `ASSIGN` lines to build up the assignment incrementally and only falls back to force-assigning from `ROLL` for traces that pre-date this format.

The replay parser (`sim/trace.odin`) skips enemy-side (`e`) decision lines since the enemy is AI-driven during replay.

**Event lines** — diagnostics only; `HP` lines are also parsed for diff output:
```
VALUES <tag> <name> <v1> <v2> ...   (normal dice values only, skulls omitted)
SKULL <atag> <attacker> <count> <dmg> <ttag> <target>
MATCH <tag> <name> <matched_count> <matched_value>   (matched_value is 0 when matched_count == 0)
HP <tag> <name> <hp>                (also parsed: last HP per character used for replay diff)
DEAD <tag> <name>
ABILITY <atag> <attacker> <ability> <DMG|HEAL|NONE> <amount> <ttag> <target>
RESOLVE <atag> <attacker> <ability> <DMG|HEAL|NONE> <amount> <ttag> <target>
CHARGE <tag> <name> +<amount> <resolve>/<resolve_max>
PASSIVE <tag> <name> <passive_name>
COND <tag> <name> <kind> <value> <remaining>
```

**Note on MATCH:** `detect_match` returns the highest die rolled as `matched_value` even when no pair exists (used by `ability_is_enhanced`). `trace_match` suppresses this, emitting `0` for `matched_value` when `matched_count == 0`, so the log clearly shows no match formed.

Event lines use character tags (`p0`–`p3`, `e0`–`e3`) as the first token after the keyword. Names follow for human readability.

Ability and passive names with spaces have spaces replaced by underscores in event lines.

### Call Sites

Decision procs are called from `combat.odin` and `game.odin` at player action points.
Event procs are called from `combat.odin` (inside `resolve_roll`) and `ai.odin` (enemy actions).

| Proc | Called from | When |
|------|-------------|------|
| `trace_init` | `main.odin` | Application start |
| `trace_close` | `main.odin` | Application exit |
| `trace_round` | `combat.odin` | Round transition |
| `trace_pick` | `game.odin`, `ai.odin` | Player or enemy picks from pool |
| `trace_assign` | `game.odin` | Player drags hand die to character |
| `trace_roll` | `combat.odin`, `ai.odin` | Player or enemy rolls a character |
| `trace_discard` | `combat.odin` | Player discards from hand |
| `trace_done` | `combat.odin`, `ai.odin` | Player or enemy finishes rolling |
| `trace_values` | `combat.odin` | After rolling, before resolution |
| `trace_skull` | `combat.odin` | After skull damage applied |
| `trace_match` | `combat.odin` | After match detection |
| `trace_hp` | `combat.odin` | After HP changes |
| `trace_dead` | `combat.odin` | When a character dies |
| `trace_ability` | `combat.odin` | After main ability fires |
| `trace_resolve_ability` | `combat.odin` | After resolve ability fires |
| `trace_charge` | `combat.odin` | After resolve meter charges |
| `trace_passive` | `combat.odin` | After On_Roll passive fires (in `resolve_roll`) AND after On_Ally_Damaged passive fires (in `notify_ally_damaged`) |
| `trace_cond` | `ability.odin` | After a condition is applied |

## Replay

`sim/trace.odin` parses `game_log.txt` into a `Trace_Reader`:
- Decision lines (`PICK`, `ASSIGN`, `ROLL`, `DISCARD`, `DONE`, `ROUND`) are parsed; only player-side (`p`) decisions are added to the `[dynamic]Trace_Action` array. Enemy-side (`e`) decisions are validated but skipped since the enemy is AI-driven in replay.
- `HP` event lines are parsed into `Trace_Reader.baseline_hp` (a `map[string]int`, last HP per character tag) for diff output.
- All other event lines are explicitly recognised and skipped. Unknown keywords cause a parse error (no silent skipping).

`sim/main.odin` drives replay via `--replay=game_log.txt`. Player decisions come from the trace; the enemy side remains AI-driven. After the game ends, a diff table compares each character's final HP in the replay against the original run's last HP event.

## Best Practices

- The trace is append-free — only one file is ever open, opened with `O_TRUNC` at startup.
- Trace procs are no-ops when `file_enabled = false` (e.g., during tests).
- Event line values are snapshots: HP after the event, resolve after charging.
- Ability names use underscores (not spaces) so the parser can split on spaces.

## What NOT to Do

- Do not call `trace_init` in tests — it creates a file on disk.
- Do not add new keywords without also adding them to the `case` list in `sim/trace.odin` (prevents replay parse errors when event lines encounter unknown keywords).
- Do not use `trace_write` directly for new event types — add a dedicated proc for type safety and discoverability.

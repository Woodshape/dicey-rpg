# Replay System — Implementation Plan

## Goal

Record player decisions during a real game into a machine-readable trace file. The simulator
replays the trace with modified stats/abilities to show how balance changes affect the same game.

---

## Status

**Phase 1 (trace writer) — Done**
**Phase 2 (trace reader + replay) — Done**
**Phase 3 (diff output) — Done**
**Phase 4 (ASSIGN trace + extended replay) — Done**
**Phase 5 (extended replay modes) — Not started**

---

## Settled Decisions

- **One log file** (`game_log.txt`) for all out-of-game records. The in-game scrolling ring buffer
  stays for player feedback but no longer writes to disk (`combat_log.odin` file output removed).
- **Decision + event lines coexist** in the same file. Decision lines drive replay; event lines
  are explicitly recognised and skipped by the parser (no silent skipping, no unknown-keyword errors).
- **Pool index + die type** recorded together — machine precision + human readability.
- **Final assignment state** in ROLL lines — ground truth for the replay. Untraced hand→char moves
  are reconciled by force-assigning from the ROLL line before executing the roll.
- **Seed-based RNG** — same seed + same decisions = same rolls. Balance changes affect outcomes.
- **Fail hard** on unknown keywords — prevents silently replaying corrupted files.

---

## Trace Format

```
SEED 1774786456
ENCOUNTER tutorial
ROUND 1
PICK 2 d6 hand
PICK 0 d8 char 1
EPICK 3 d4 hand
EPICK 1 d6 goblin
ROUND 2
PICK 3 d10 hand
DISCARD 2 d4
ROLL 0 d6 d6 Skl
VALUES Warrior 3 5
SKULL Warrior 1 8 Goblin
MATCH Warrior 2 5
ABILITY Warrior Flurry DMG 10 Goblin
HP Goblin 32
DONE
EDONE
...
```

### Decision Lines (drive replay)

| Line | Format | Notes |
|------|--------|-------|
| `SEED` | `SEED <n>` | RNG seed for this game |
| `ENCOUNTER` | `ENCOUNTER <name>` | Encounter config name |
| `ROUND` | `ROUND <n>` | Round boundary marker |
| `PICK` | `PICK <pool_idx> <die_type> hand` or `PICK <pool_idx> <die_type> char <ci>` | Player draft pick |
| `ROLL` | `ROLL <ci> <die> [<die> ...]` | Player rolls character `ci`; dice list is ground truth |
| `DISCARD` | `DISCARD <hand_idx> <die_type>` | Player discards from hand |
| `DONE` | `DONE` | Player skips remaining rolls |

### Event Lines (diagnostics, skipped during replay)

| Line | Format | Notes |
|------|--------|-------|
| `VALUES` | `VALUES <name> <v1> ...` | Rolled normal die values |
| `SKULL` | `SKULL <attacker> <count> <dmg> <target>` | Total skull damage |
| `MATCH` | `MATCH <name> <matched_count> <matched_value>` | Match result (0 0 = no match) |
| `ABILITY` | `ABILITY <attacker> <name_> <DMG\|HEAL\|NONE> <amount> <target>` | Main ability effect |
| `RESOLVE` | `RESOLVE <attacker> <name_> <DMG\|HEAL\|NONE> <amount> <target>` | Resolve ability effect |
| `CHARGE` | `CHARGE <name> +<amount> <resolve>/<max>` | Resolve meter charge |
| `PASSIVE` | `PASSIVE <name> <passive_name_>` | Passive triggered |
| `COND` | `COND <name> <kind> <value> <remaining>` | Condition applied |
| `HP` | `HP <name> <hp>` | HP snapshot after damage/heal |
| `DEAD` | `DEAD <name>` | Character died |
| `EPICK` | `EPICK <pool_idx> <die_type> <dest>` | Enemy draft pick |
| `EROLL` | `EROLL <name> <die> [<die> ...]` | Enemy rolls |
| `EDONE` | `EDONE` | Enemy skips remaining rolls |

Ability names with spaces are written with underscores (e.g. `Mass_Heal`).

---

## Phase 1: Trace Writer — Done

**Files changed:**
- `src/types.odin` — `Trace_Log` struct (file handle + enabled flag)
- `src/game.odin` — `trace_log` field in `Game_State`; init in `game_init`
- `src/trace.odin` — `trace_init`, `trace_close`, `trace_write`, `trace_round`, `trace_pick`,
  `trace_roll`, `trace_discard`, `trace_done`, plus 13 event procs
- `src/combat.odin` — decision trace calls at all player action points; ability pipeline inlined
  in `resolve_roll` with HP snapshots for event lines
- `src/ai.odin` — enemy actions traced via `trace_epick`, `trace_eroll`, `trace_edone`
- `src/main.odin` — `trace_init` on startup, `trace_close` on exit
- `src/combat_log.odin` — file output removed; ring buffer kept for in-game display

---

## Phase 2: Trace Reader + Replay — Done

**Files changed:**
- `sim/trace.odin` — `Trace_Reader`, `Trace_Action` union (`Trace_Round`, `Trace_Pick`,
  `Trace_Roll`, `Trace_Discard`, `Trace_Done`), `trace_reader_load`, `trace_reader_destroy`,
  `trace_peek`, `trace_next`, `trace_parse_die_type`
- `sim/main.odin` — `--replay=<path>` CLI flag; `run_replay` proc; `replay_draft_player_pick`,
  `replay_combat_player_turn`, `replay_consume_discards`, `replay_expect_round` helpers

**Robustness layers built into the replay:**
1. **Pool order drift** — PICK searches by die type, not exact slot index
2. **Die type unavailable** — substitutes closest-value die and prints a note; last resort: any die
3. **Stale DONE/ROLL actions** — skipped when a character has no assigned dice (auto-advance fires)
4. **Trace exhaustion** — switches player side to AI fallback so the game runs to completion
5. **DISCARD mismatch** — searches hand by die type; silently skips if die was already moved to a character

**Known limitation (resolved in Phase 4):** Hand→char drag moves were previously untraced. This is
now fixed — `ASSIGN` lines are written for every hand→char drag and replayed by
`replay_consume_free_actions` before each PICK/ROLL. The ROLL force-assign fallback remains for
traces recorded before Phase 4.

---

## Phase 3: Diff Output — Not started

After `run_replay` completes, compare the outcome against the HP/damage snapshots from the event
lines in the original trace.

**Goal:** show per-character damage dealt/taken and final HP in the replay vs. the original session,
so balance changes are immediately quantified.

**Design sketch:**
- Parse event lines (`HP`, `SKULL`, `ABILITY`, `RESOLVE`) from the trace into a baseline snapshot
  during `trace_reader_load` (currently they are skipped entirely)
- Collect the same metrics during `run_replay` via the existing stat collection hooks
- After the game ends, print a diff table: `| Character | HP orig | HP replay | Dmg orig | Dmg replay |`

**File changes:**
- `sim/trace.odin` — extend `Trace_Reader` with baseline snapshots; parse `HP` lines into a
  `map[string]int` (final HP per character name)
- `sim/main.odin` — collect per-character final HP during `run_replay`; call `print_replay_diff`
  after the game loop exits

---

## Phase 4: ASSIGN Trace Entry — Not started

Close the state-drift gap by recording individual hand→char drag assignments. This is the root
cause of all divergence in phases 2 and beyond.

**Format:** `ASSIGN <hand_idx> <die_type> char <ci>`

**Design:**
- Add `trace_assign` proc to `src/trace.odin`
- Call it in `game.odin` at the drag-drop assignment site (hand → character)
- Add `Trace_Assign` struct and parse case to `sim/trace.odin`
- In `replay_draft_player_pick` / `replay_combat_player_turn`, consume pending `ASSIGN` actions
  before the next PICK/ROLL rather than force-assigning from ROLL lines
- Keep force-assign as the fallback for traces that pre-date this change

**Impact:** Once ASSIGN is traced, replay fidelity extends to the full game without type substitution.
The AI fallback remains for trace exhaustion but should rarely trigger.

---

## Phase 5: Extended Replay Modes — Not started

These build on Phase 4 fidelity and are low-priority until Phase 3 and 4 are done.

- **Partial replay** — `--replay-rounds=N` flag; replay the first N rounds from the trace, then
  hand control to AI. Useful for isolating a specific round's balance impact.
- **Multi-config comparison** — `--compare=cfg1,cfg2,...`; run the same trace against multiple
  encounter configs and print a side-by-side outcome table. Requires a shared replay driver that
  can be seeded identically for each config.

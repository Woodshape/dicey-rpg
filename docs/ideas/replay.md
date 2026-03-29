# Replay System

## Unified Game Log for Balance Iteration

The live game writes `game_log.txt` on every session. This single file serves two purposes:
1. **Replay** — decision lines (PICK, ROLL, DISCARD, DONE) drive `sim/main.odin --replay`
2. **Diagnostics** — event lines (VALUES, SKULL, MATCH, ABILITY, HP, etc.) let Claude trace balance issues round-by-round

There is no separate `combat_log.txt` or `decision_trace.txt`. The `--combat` simulator mode has been removed; `game_log.txt` replaces it.

## Settled Decisions

- **One log file** (`game_log.txt`) for all out-of-game records. In-game ring buffer stays for the player but no longer writes to disk.
- **Decision + event lines coexist** in the same file. Decision lines drive replay; event lines are explicitly recognized and skipped by the parser (no silent skipping, no unknown-keyword errors).
- **Pool index + die type** recorded together — machine precision + human readability.
- **Final assignment state** in ROLL lines — self-verifying ground truth for the replay.
- **Seed-based RNG** — same seed = same rolls. Balance changes affect outcomes, not dice values.
- **Fail hard** on truly unknown keywords during replay — prevents silently replaying corrupted files.

See `docs/codebase/trace.md` for the full log format and call-site details.

## Known Limitation

Hand→char drag moves are not traced. This causes cumulative state drift in longer replays as untraced assignments diverge between the original session and the replay. Rounds 1–7 typically replicate faithfully; later rounds may see die-type substitutions.

The replay system handles this with three robustness layers:
1. Pool order drift → search by die type (not exact index)
2. Die type unavailable → substitute closest-value die, print a note
3. Trace exhaustion → switch player side to AI fallback

A future `ASSIGN` trace entry would close the gap.

## Future Extensions

- **Diff output:** After replay, show per-character damage/HP comparison against the original run.
- **Partial replay:** Replay up to round N, then hand control to AI or the player.
- **Multiple config comparison:** Run the same trace against multiple balance configs and compare outcomes side by side.
- **ASSIGN trace entry:** Record individual hand→char drag assignments to close the state-drift gap.

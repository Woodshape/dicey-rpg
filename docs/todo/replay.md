# Replay TODOs

## Symmetric replay log

**File:** `sim/main.odin` — `run_replay`

`game_log_replay.txt` currently only contains event lines. Decision lines (PICK, ASSIGN, ROLL,
DISCARD, DONE, ROUND) are read from the input trace and executed but never written to the output
log. This means the two files cannot be diffed line-for-line.

Fix: after executing each action in the three replay helpers, call the matching trace proc:

- `replay_draft_player_pick` → call `trace_pick` / `trace_round` after each pick executes
- `replay_combat_player_turn` → call `trace_roll` / `trace_done` after each action executes
- `replay_consume_free_actions` → call `trace_assign` / `trace_discard` after each free action executes
- ROUND markers are already written by `trace_round` at round boundaries in `run_replay` — verify
  they are written at exactly the right point (before the first pick of each round, not after)

The result: `game_log.txt` and `game_log_replay.txt` become fully symmetric — same keywords, same
order, same structure — so a plain `diff` shows only genuine divergence (balance changes, RNG
drift from config edits).

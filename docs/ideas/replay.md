# Replay System

## Combat Log Replay for Balance Iteration

Point the simulator at a real game's decision trace to replay the exact decision sequence with modified stats/abilities. Enables rapid balance iteration: change a number, re-run the same game, see the different outcome.

## Settled Decisions

- **Option B (machine-readable trace)** — a `decision_trace.txt` file with space-separated tokens, one action per line. Decoupled from the human-readable combat log.
- **Replaces `combat_log.txt`** as the persistent session record. The in-game scrolling log stays for player feedback but no longer writes to disk. In-game log can be simplified later to strip debug info.
- **Pool index + die type** recorded together for machine precision + human readability.
- **Final assignment state** in ROLL lines (not individual ASSIGN actions) — self-verifying on replay.
- **Seed-based RNG replay** — same seed = same rolls. Balance changes affect what the rolls *do*, not what was rolled.
- **Fail hard** on invalid decisions during replay — no silent skipping.

See `docs/plans/replay.md` for the full implementation plan.

## Future Extensions

- **Diff output:** After replay, show per-character damage/HP comparison against the original.
- **Partial replay:** Replay up to round N, then hand control to AI or the player.
- **Multiple trace comparison:** Run the same trace against multiple balance configs and compare outcomes side by side.
- **Trace from simulator:** Record AI-vs-AI decisions in the simulator so sim games are also replayable (useful for debugging specific AI edge cases).

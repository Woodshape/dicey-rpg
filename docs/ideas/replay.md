# Replay System

## Combat Log Replay for Balance Iteration

Point the simulator at a real combat log to replay the exact decision sequence with modified stats/abilities. Enables rapid balance iteration: change a number, re-run the same game, see the different outcome.

## Architecture Options

### Option A: Parse existing combat log

- Parse `combat_log.txt` back into pick/assign/roll/discard decisions
- Pro: no changes to the logging system
- Con: fragile — any log format change breaks the parser. Human-readable text is awkward to parse reliably (e.g., character names with spaces, ability descriptions with special characters)

### Option B: Machine-readable decision trace

- Add a second log stream alongside the human log: one structured action per line
- Format: `PICK player d6 hand`, `ROLL player 0`, `ASSIGN player 0 1`, `DISCARD player 2`
- Pro: trivial to parse, decoupled from display formatting
- Con: requires adding the trace logger to all decision points

### Open Questions

- Should roll RNG replay from seed (same rolls regardless of balance changes) or from the trace (recorded roll values)?
  - **From seed:** changing stats doesn't change what you rolled, only what the rolls do. Shows "what if this same roll hit harder?"
  - **From trace:** recorded exact values. Shows the identical game regardless of seed logic changes.
  - Both modes are useful. Seed-based is simpler to implement first.
- How to handle decision validity after balance changes? E.g., if a character's rarity changes from Common (3 slots) to Rare (4 slots), the original 3-die assignment is still valid but suboptimal. If it changes to a smaller value, the assignment may become invalid — need a fallback.

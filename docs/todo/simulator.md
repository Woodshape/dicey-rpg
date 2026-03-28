# TODOs — Simulator

## Single-game validation mode

**Files:** `sim/main.odin`

The simulator currently runs N games and outputs aggregate statistics. This is useful for balance tuning but not for validating game rules and systems. A separate mode is needed that runs a single full combat with a complete combat log — the same log the real game writes to `combat_log.txt`.

**Use case:** After making changes to core systems (combat flow, abilities, conditions, damage pipeline), run a single simulated game and read the full combat log to verify every event follows the rules. This is how rules are currently validated manually — the simulator should automate the "play a full game" step.

**What needs doing:**
- Add a `--validate` or `--single` CLI flag that runs 1 game with full combat log output
- Enable `file_enabled` on the combat log in this mode (write to `combat_log.txt` or stdout)
- Print the full log to stdout after the game ends (or write to a specified file)
- Optionally: structured output (JSON/CSV per event) for automated rule checking
- The existing `--rounds=1` mode collects stats but does NOT produce a combat log — this is a different thing

**Blocked by:** nothing — can be implemented any time.

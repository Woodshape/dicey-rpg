# Combat Log — Ring Buffer & File Output

**File:** `src/combat_log.odin`
**Types:** `Combat_Log`, `Log_Entry` (defined in `types.odin`)

## Responsibilities

- Store recent combat messages in a fixed-size ring buffer
- Write log entries to disk for persistent session records
- Draw the log on screen during gameplay
- Track game numbers across Play Again restarts

## Architecture

### Ring Buffer

The combat log uses a fixed-size ring buffer (`MAX_LOG_ENTRIES = 10`) with inline text storage. No heap allocation.

```odin
Combat_Log :: struct {
    entries:      [MAX_LOG_ENTRIES]Log_Entry,
    count:        int,           // number of entries (capped at MAX_LOG_ENTRIES)
    head:         int,           // next write position (wraps around)
    game_number:  int,           // increments on Play Again
    file_enabled: bool,          // false during tests
}

Log_Entry :: struct {
    text:  [MAX_LOG_LENGTH]u8,   // inline buffer (128 bytes)
    len:   int,
    color: rl.Color,
}
```

New entries overwrite the oldest when the buffer is full. The `head` pointer advances modulo `MAX_LOG_ENTRIES`.

### File Output

- `combat_log_init_file(log)` — called once at application start. Writes a session header and enables `file_enabled`.
- Each `combat_log_add` call appends the formatted text to `combat_log.txt` on disk.
- Tests never call `combat_log_init_file`, so `file_enabled` remains false — no disk writes during testing.

### Game Number Tracking

`combat_log_new_game(log)` increments `game_number` and adds a "--- ROUND N ---" separator. Called by `game_init` on every Play Again restart.

### Rendering

`combat_log_draw(log)` renders entries in a bottom-up stack at the bottom-centre of the screen. Newest entries appear at the bottom. Entries are iterated from oldest to newest using the ring buffer arithmetic.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `combat_log_add(log, color, format, args)` | Add a colored entry (ring buffer + file) |
| `combat_log_write(log, format, args)` | Add a white entry (convenience wrapper) |
| `combat_log_new_game(log)` | Increment game number, add separator |
| `combat_log_init_file(log)` | Enable file output, write session header |
| `combat_log_draw(log)` | Render log on screen |

## How to Use

```odin
// Log a combat event with color
combat_log_add(&gs.log, rl.Color{200, 60, 60, 255}, "%s deals %d damage to %s", attacker.name, dmg, target.name)

// Log a neutral event
combat_log_write(&gs.log, "--- Round 2 ---")
```

## Best Practices

- All combat logging happens in `resolve_roll` (in `combat.odin`) and `ai_take_turn` (in `ai.odin`). Do not scatter log calls across modules.
- Use `combat_log_add` with a color for gameplay events (damage, abilities, death). Use `combat_log_write` for neutral events (picks, discards).
- The inline text buffer (`MAX_LOG_LENGTH = 128`) is generous but finite. Keep messages concise.
- The log is preserved across Play Again by passing the `Combat_Log` pointer into `game_init`.

## What NOT to Do

- Do not call `combat_log_init_file` in test code. It writes to disk and enables file output.
- Do not assume the log has entries — check `log.count > 0` before reading.
- Do not store the `cstring` pointer from a log entry across frames — the ring buffer may overwrite it.
- Do not use the log for debug output. It's rendered on screen and written to disk — it's a player-facing gameplay record.

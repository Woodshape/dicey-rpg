# Combat Log — Ring Buffer (In-Game Only)

**File:** `src/combat_log.odin`
**Types:** `Combat_Log`, `Log_Entry` (defined in `types.odin`)

## Responsibilities

- Store recent combat messages in a fixed-size ring buffer
- Draw the log on screen during gameplay for the player

File output has been removed. All out-of-game persistent logging is handled by the trace system (`src/trace.odin` → `game_log.txt`).

## Architecture

### Ring Buffer

The combat log uses a fixed-size ring buffer (`MAX_LOG_ENTRIES = 10`) with inline text storage. No heap allocation.

```odin
Combat_Log :: struct {
    entries: [MAX_LOG_ENTRIES]Log_Entry,
    count:   int,  // number of entries (capped at MAX_LOG_ENTRIES)
    head:    int,  // next write position (wraps around)
}

Log_Entry :: struct {
    text:  [MAX_LOG_LENGTH]u8,  // inline buffer (128 bytes)
    len:   int,
    color: rl.Color,
}
```

New entries overwrite the oldest when the buffer is full. The `head` pointer advances modulo `MAX_LOG_ENTRIES`.

### Rendering

`combat_log_draw(log)` renders entries in a bottom-up stack at the bottom-centre of the screen. Newest entries appear at the bottom. Entries are iterated from oldest to newest using ring buffer arithmetic.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `combat_log_add(log, color, format, args)` | Add a colored entry to the ring buffer |
| `combat_log_write(log, format, args)` | Add a white entry (convenience wrapper) |
| `combat_log_draw(log)` | Render log on screen |

## How to Use

```odin
// Log a combat event with color
combat_log_add(&gs.log, rl.Color{200, 60, 60, 255}, "%s deals %d damage to %s", attacker.name, dmg, target.name)

// Log a neutral event
combat_log_write(&gs.log, "--- Round 2 ---")
```

## Best Practices

- All combat logging happens in `resolve_roll` (in `combat.odin`) and `ai_combat_turn` (in `ai.odin`). Do not scatter log calls across modules.
- Use `combat_log_add` with a color for gameplay events (damage, abilities, death). Use `combat_log_write` for neutral events (picks, discards).
- The inline text buffer (`MAX_LOG_LENGTH = 128`) is generous but finite. Keep messages concise.

## What NOT to Do

- Do not assume the log has entries — check `log.count > 0` before reading.
- Do not store the `cstring` pointer from a log entry across frames — the ring buffer may overwrite it.
- Do not use the log for persistent records or diagnostics — that is the job of `src/trace.odin` and `game_log.txt`.

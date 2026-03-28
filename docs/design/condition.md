# Condition — Status Effects

**File:** `src/condition.odin`
**Types:** `Condition`, `Condition_Kind`, `Condition_Expiry` (defined in `types.odin`)
**Tests:** `tests/condition_test.odin`

## Responsibilities

- Apply, remove, and query conditions on characters
- Tick turn-based conditions at phase transitions
- Compute effective defense (base DEF + Hex modifiers)
- Absorb damage through Shield conditions
- Fire periodic effects (future: Poison, Regen)

## Architecture

### Condition Struct

```odin
Condition :: struct {
    kind:      Condition_Kind,    // Shield, Hex, ...
    value:     int,               // magnitude (absorption pool for Shield, DEF reduction for Hex)
    expiry:    Condition_Expiry,  // Turns or On_Hit_Taken
    remaining: int,               // duration left; removed at 0
    interval:  int,               // ticks between periodic effects (0 = passive/reactive)
    timer:     int,               // counts up toward interval; resets on fire
}
```

Each character holds `conditions: [MAX_CONDITIONS]Condition` + `condition_count: int` (max 4).

### Condition Kinds

| Kind | Expiry | Value | Behaviour |
|------|--------|-------|-----------|
| Shield | On_Hit_Taken | absorption pool ([VALUE]) | Each hit reduces pool by damage dealt. Removed when pool reaches 0. |
| Hex | Turns | DEF reduction (1) | Target's effective DEF reduced by value. Ticks down each owner turn. |

### Expiry Models

- **Turns**: `remaining` decrements once per owner's turn. Removed at 0.
- **On_Hit_Taken**: `remaining` is not decremented by ticks. Shield uses `value` as the absorption pool instead; removed when `value` reaches 0.

### Ticking

Conditions tick **per-side, not per-game-turn**. `combat_update` tracks `prev_turn` and calls `tick_party_conditions` when the phase changes:
- Player conditions tick on transition to `Player_Turn`
- Enemy conditions tick on transition to `Enemy_Turn`

A 3-turn Hex on an enemy lasts 3 enemy turns, not 3 game turns.

### Periodic Effects (interval)

For future conditions like Poison or Regen:
- `interval > 0`: timer increments each tick. When `timer >= interval`, `condition_fire_periodic` is called and timer resets.
- `interval == 0`: passive/reactive condition, no periodic trigger.
- `condition_fire_periodic` dispatches on `kind` via `#partial switch`. Currently a no-op — the hook point for future periodic conditions.

### Damage Pipeline Integration

All damage application sites use:
1. `character_effective_defense(target)` instead of `target.stats.defense` — accounts for Hex
2. `condition_absorb_damage(target, dmg)` — returns amount absorbed by Shield; caller subtracts from damage

This applies to: skull damage (per-hit loop), Flurry (per-hit loop), Smite, Fireball, resolve abilities.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `condition_apply(ch, kind, value, expiry, remaining, interval)` | Add condition to character |
| `condition_remove(ch, index)` | Remove by index, shift remaining |
| `condition_tick_turns(ch)` | Tick turn-based conditions + periodic timers |
| `condition_fire_periodic(ch, cond)` | Dispatch periodic effect by kind |
| `condition_absorb_damage(ch, incoming)` | Shield absorbs damage, returns amount absorbed |
| `character_effective_defense(ch)` | Base DEF minus Hex reductions, clamped to 0 |
| `condition_has(ch, kind)` | Check if a condition kind is active |

## Test Coverage

`tests/condition_test.odin` — 13 tests:

**Apply/remove:** `condition_apply_adds_to_character`, `condition_apply_fails_when_full`, `condition_remove_shifts_remaining`

**Shield:** `shield_absorbs_damage`, `shield_reduces_skull_damage`

**Hex:** `hex_reduces_effective_defense`, `hex_stacks`, `hex_clamps_defense_to_zero`

**Ticking:** `condition_tick_decrements_turns`, `condition_tick_does_not_affect_on_hit`

**Interval:** `condition_interval_timer_advances`, `condition_interval_zero_means_no_periodic`

**Query:** `condition_has_finds_active_condition`

# Combat — Turn State Machine & Resolution

**File:** `src/combat.odin`
**Types:** `Turn_Phase` (defined in `types.odin`)
**Tests:** `tests/combat_test.odin`

## Responsibilities

- Drive the turn-based state machine (player and enemy alternate actions)
- Handle player input during their turn (drag, roll, discard)
- Delegate to AI during enemy turns
- Resolve rolls: skull damage, abilities, resolve meter, logging
- Check win/lose conditions after every roll
- Manage board refill when no pickable dice remain
- Handle game over and Play Again

## Architecture

### State Machine

The turn flow is an enum-driven state machine:

```
Player_Turn → Player_Roll_Result → Enemy_Turn → Enemy_Roll_Result → Player_Turn → ...
                                                                       ↓
                                                                    Victory / Defeat
```

Each phase has a dedicated update procedure called from `combat_update`:

| Phase | Handler | Description |
|-------|---------|-------------|
| `Player_Turn` | `player_turn_update` | Player can assign (free), pick (ends turn), roll (shows result), or discard (free) |
| `Player_Roll_Result` | `player_roll_result_update` | Timed display of roll results, then auto-advances |
| `Enemy_Turn` | `enemy_turn_update` | Delegates to `ai_take_turn` |
| `Enemy_Roll_Result` | `enemy_roll_result_update` | Timed display, then auto-advances |
| `Victory / Defeat` | `game_over_update` | Shows overlay, waits for Play Again click |

### Roll Resolution Pipeline

`resolve_roll(gs, attacker, target)` is the central resolution procedure, called for both player and enemy rolls:

1. **Skull damage** → `apply_skull_damage` (per-hit loop)
2. **Ability + resolve** → `resolve_abilities` (checks min_matches, fires effect, charges meter, auto-triggers resolve ability)
3. **Combat logging** — match info, ability results, resolve charge, death events

The resolution order (skulls first, then abilities) is intentional — skull damage can kill a target before the ability fires, which matters for targeting.

### Targeting

`get_target(enemy_party, attacker_index)` selects who an attacker hits:
1. **Prefer facing opponent** — the enemy at the same party index
2. **Fall back to first alive** — if the facing opponent is dead
3. **Return nil** — if all enemies are dead

### Board Refill

`check_board_refill(gs)` is called at the start of both `player_turn_update` and `enemy_turn_update`. If `board_has_pickable` returns false (no accessible dice), the board is fully reinitialized.

### Action Types

| Action | Cost | Handler |
|--------|------|---------|
| Pick (board → hand/character) | Ends turn | `try_drop` in `game.odin` |
| Roll | Ends turn, shows results | Roll button click |
| Assign (hand ↔ character) | Free | `try_drop` in `game.odin` |
| Discard (hand die) | Free | Right-click in `player_turn_update` |

### Timed Result Display

Both `Player_Roll_Result` and `Enemy_Roll_Result` use a timer (`gs.turn_timer`) to display results for a fixed duration before advancing. Constants: `PLAYER_ROLL_DISPLAY_TIME` and `ENEMY_ROLL_DISPLAY_TIME` (both 1.5s).

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `combat_update(gs)` | Top-level dispatcher — routes to phase handler |
| `player_turn_update(gs)` | Player input: drag, roll, discard |
| `player_roll_result_update(gs)` | Timed display, then advance |
| `enemy_turn_update(gs)` | Delegates to `ai_take_turn` |
| `enemy_roll_result_update(gs)` | Timed display, then advance |
| `game_over_update(gs)` | Play Again click handler |
| `resolve_roll(gs, attacker, target)` | Full roll resolution with logging |
| `check_win_lose(gs, default_next)` | Returns Victory/Defeat/default |
| `party_all_dead(party)` | True if all characters have `state != .Alive` |
| `get_target(enemy_party, attacker_index)` | Select attack target |
| `check_board_refill(gs)` | Refill board if no pickable dice |
| `can_pick(gs, hand)` / `can_roll(character)` | Action validation |

## How to Use

The combat system is driven entirely through `combat_update(gs)`, called once per frame from `game_update`. All phase transitions happen internally. External code should not set `gs.turn` directly.

## Best Practices

- `resolve_roll` handles all logging. Do not log combat events from other modules.
- Check win/lose via `check_win_lose` after any roll resolution — it handles both sides.
- Board refill happens at the START of a turn, not at the end. This ensures the active player always has dice to pick.
- The `rolling_index` field on `Game_State` tracks which character is showing roll results. It's used by the result display phases to know which character to clear.

## What NOT to Do

- Do not set `gs.turn` from outside `combat.odin` except during initialization.
- Do not call `resolve_roll` without first calling `character_roll` — it reads `character.roll` which must be populated.
- Do not check character liveness with `character.stats.hp > 0`. Use `character_is_alive(character)` which checks `state == .Alive`. The `.Dead` state is set by `resolve_roll` when HP reaches 0; it is the source of truth.
- Do not skip `check_board_refill` at the start of a turn — it prevents the game from stalling when the board is exhausted.

## Test Coverage

`tests/combat_test.odin` — 14 tests:

**Turn flow:** `game_starts_on_player_turn`, `assign_does_not_end_turn`

**Action validation:** `cannot_roll_empty_character`, `can_roll_with_assigned_dice`, `cannot_pick_with_full_hand`, `can_pick_with_space_in_hand`

**Win/lose:** `enemy_death_triggers_victory`, `player_death_triggers_defeat`, `both_alive_returns_default`, `partial_enemy_death_not_victory`, `all_dead_enemy_takes_priority`

**Board refill:** `board_refills_when_empty`, `board_does_not_refill_when_pickable_dice_remain`

**Restart:** `play_again_resets_game_state`

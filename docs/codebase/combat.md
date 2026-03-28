# Combat — Turn State Machine & Resolution

**File:** `src/combat.odin`
**Types:** `Turn_Phase` (defined in `types.odin`)
**Tests:** `tests/combat_test.odin`

## Responsibilities

- Drive the turn-based state machine across draft and combat phases
- Handle player input during draft and combat turns (drag, roll, discard, done)
- Delegate to AI during enemy draft and combat turns
- Resolve rolls: skull damage, abilities, resolve meter, logging
- Check win/lose conditions after every roll
- Regenerate the draft pool at round end
- Handle game over and Play Again

## Architecture

### State Machine

Each round consists of a draft phase followed by a combat phase. The full flow is:

```
Draft_Player_Pick ↔ Draft_Enemy_Pick
        (pool empty)
            ↓
  Combat_Player_Turn → Player_Roll_Result
          ↑                    ↓
          └────────────────────┘
    (loop until no assigned dice)
            ↓
  Combat_Enemy_Turn → Enemy_Roll_Result
          ↑                    ↓
          └────────────────────┘
    (loop until no assigned dice)
            ↓
         Round_End → Draft_Player_Pick (next round)
                   ↓
             Victory / Defeat
```

**Draft phase:** Player and enemy alternate picks (`Draft_Player_Pick` ↔ `Draft_Enemy_Pick`) until the pool is empty. When the pool empties after the player's pick, the game transitions directly to `Combat_Player_Turn`.

**Combat phase:** Each side resolves ALL of its characters before the other side goes. The player rolls characters one at a time via roll buttons; after each roll a timed result display (`Player_Roll_Result`) shows before returning to `Combat_Player_Turn`. When no alive player character has assigned dice remaining, the turn auto-advances to `Combat_Enemy_Turn`. The player may also click "Done" to skip remaining rolls and pass to the enemy early. The enemy side works identically (AI-driven, no input).

**Round end:** `Round_End` checks win/lose, regenerates the pool via `pool_generate`, advances the round counter, and transitions to the next draft phase (alternating first pick).

Each phase has a dedicated update procedure called from `combat_update`. All phase handlers except `draft_enemy_pick_update` and `combat_enemy_turn_update` take an `Input_State` parameter — input is collected once per frame in `game_update` and threaded through. AI-driven handlers do not take `Input_State`. No combat procedures call `rl.GetMouse*`, `rl.IsMouseButton*`, or `rl.GetFrameTime` directly; all input comes from `Input_State`. The `rl` import is retained only for `rl.Color` in combat log entries.

| Phase | Handler | Description |
|-------|---------|-------------|
| `Draft_Player_Pick` | `draft_player_pick_update(gs, input)` | Player drags a die from pool to hand/character; ends turn when a pick is made |
| `Draft_Enemy_Pick` | `draft_enemy_pick_update(gs)` | AI picks one die from the pool; no Input_State |
| `Combat_Player_Turn` | `combat_player_turn_update(gs, input)` | Player clicks roll buttons per character; Done button skips remaining rolls |
| `Player_Roll_Result` | `player_roll_result_update(gs, input)` | Timed display of roll results, then returns to `Combat_Player_Turn` |
| `Combat_Enemy_Turn` | `combat_enemy_turn_update(gs)` | Delegates to `ai_combat_turn`; no Input_State |
| `Enemy_Roll_Result` | `enemy_roll_result_update(gs, input)` | Timed display, then returns to `Combat_Enemy_Turn` |
| `Round_End` | `round_end_update(gs)` | Pool regeneration, round advance, next draft |
| `Victory / Defeat` | `game_over_update(gs, input)` | Shows overlay, waits for Play Again click |

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

### Condition Ticking

`combat_update` tracks `prev_turn` before dispatching to the phase handler. After the handler returns, if the turn phase changed, conditions are ticked for the side whose combat turn is **beginning for the first time that round** — not between rolls within the same round:

- Transition to `Combat_Player_Turn` from anything other than `Player_Roll_Result` → `tick_party_conditions(&gs.player_party)`
- Transition to `Combat_Enemy_Turn` from anything other than `Enemy_Roll_Result` → `tick_party_conditions(&gs.enemy_party)`

This means conditions tick once per combat phase entry, not once per character roll. A 3-turn debuff on an enemy lasts 3 enemy combat turns, not 3 individual rolls.

`tick_party_conditions(party)` calls `condition_tick_turns` on each character, which decrements turn-based durations and fires periodic effects.

### Pool Regeneration

There is no `check_board_refill`. The draft pool is regenerated once per round in `round_end_update` by calling `pool_generate(&gs.round)`. The pool does not refill mid-round. When the pool is exhausted during the draft phase, the game transitions immediately to the combat phase.

### Done Button

During `Combat_Player_Turn`, a "Done" button is rendered at the centre of the screen. Clicking it immediately advances to `Combat_Enemy_Turn`, skipping any remaining character rolls. `done_button_rect()` returns the button rectangle (used by both draw and hit-test code). `mouse_on_done_button(mouse_x, mouse_y)` performs the hit test.

### Auto-Advance

`party_has_assigned_dice(party)` returns true if any alive character in the party has at least one assigned die. `combat_player_turn_update` and `combat_enemy_turn_update` check this at entry; if false, the turn advances automatically without waiting for input.

### Action Types

| Action | Cost | Available In |
|--------|------|-------------|
| Pick (pool → hand/character) | Ends draft turn | `Draft_Player_Pick` |
| Roll (character) | Shows result screen | `Combat_Player_Turn` |
| Done (skip remaining rolls) | Advances to enemy turn | `Combat_Player_Turn` |
| Assign (hand ↔ character) | Free | Draft and combat phases |
| Discard (hand die) | Free | Draft and combat phases |

### Timed Result Display

Both `Player_Roll_Result` and `Enemy_Roll_Result` use a timer (`gs.turn_timer`) to display results for a fixed duration before advancing. Constants: `PLAYER_ROLL_DISPLAY_TIME` and `ENEMY_ROLL_DISPLAY_TIME` (both 1.5s).

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `combat_update(gs, input)` | Top-level dispatcher — routes to phase handler, ticks conditions on phase transitions |
| `draft_player_pick_update(gs, input)` | Player drag-to-pick from pool; advances to enemy pick or combat |
| `draft_enemy_pick_update(gs)` | AI picks one die from pool |
| `combat_player_turn_update(gs, input)` | Player roll buttons and Done button; auto-advances when no assigned dice |
| `player_roll_result_update(gs, input)` | Timed display, then back to `Combat_Player_Turn` |
| `combat_enemy_turn_update(gs)` | Delegates to `ai_combat_turn` |
| `enemy_roll_result_update(gs, input)` | Timed display, then back to `Combat_Enemy_Turn` |
| `round_end_update(gs)` | Pool regeneration, round advance, next draft |
| `game_over_update(gs, input)` | Play Again click handler |
| `resolve_roll(gs, attacker, target)` | Full roll resolution with logging |
| `check_win_lose(gs, default_next)` | Returns Victory/Defeat/default |
| `party_all_dead(party)` | True if all characters have `state != .Alive` |
| `party_has_assigned_dice(party)` | True if any alive character has assigned dice |
| `get_target(enemy_party, attacker_index)` | Select attack target |
| `tick_party_conditions(party)` | Tick turn-based conditions for all party members |
| `can_pick(pool, hand)` | True if hand is not full and pool is not empty |
| `can_roll(character)` | True if character has assigned dice and has not rolled this round |
| `done_button_rect()` | Returns the Done button rectangle for draw and hit-test |
| `mouse_on_done_button(mouse_x, mouse_y)` | Hit-test the Done button |

## How to Use

The combat system is driven entirely through `combat_update(gs, input)`, called once per frame from `game_update`. All phase transitions happen internally. External code should not set `gs.turn` directly.

## Best Practices

- `resolve_roll` handles all logging. Do not log combat events from other modules.
- Check win/lose via `check_win_lose` after any roll resolution — it handles both sides.
- Pool regeneration happens in `round_end_update`, not at the start of a turn. The draft pool is valid for the entire draft phase and does not need mid-phase refills.
- The `rolling_index` field on `Game_State` tracks which character is currently showing roll results. The result display phases use it to clear the correct character after the timer expires.
- Condition ticking uses the `prev_turn` guard to fire once per combat phase entry, not once per roll. Check both the new and previous phases before adding any additional ticking logic.

## What NOT to Do

- Do not set `gs.turn` from outside `combat.odin` except during initialization.
- Do not call `resolve_roll` without first calling `character_roll` — it reads `character.roll` which must be populated.
- Do not check character liveness with `character.stats.hp > 0`. Use `character_is_alive(character)` which checks `state == .Alive`. The `.Dead` state is set by `resolve_roll` when HP reaches 0; it is the source of truth.
- Do not call `pool_generate` outside of `round_end_update`. Pool regeneration is a round-boundary event.
- Do not pass `gs` to `can_pick` — the signature is `can_pick(pool, hand)`, taking the pool and hand directly.

## Test Coverage

`tests/combat_test.odin` — 15 tests:

**Turn flow:** `game_starts_on_draft_player_pick`, `assign_does_not_end_turn`

**Action validation:** `cannot_roll_empty_character`, `can_roll_with_assigned_dice`, `cannot_pick_with_full_hand`, `can_pick_with_space_in_hand`

**Win/lose:** `enemy_death_triggers_victory`, `player_death_triggers_defeat`, `both_alive_returns_default`, `partial_enemy_death_not_victory`, `all_dead_enemy_takes_priority`

**Draft phase:** `draft_pool_not_empty_on_start`, `draft_pick_reduces_pool`, `no_assigned_dice_means_no_rollable`

**Restart:** `play_again_resets_game_state`

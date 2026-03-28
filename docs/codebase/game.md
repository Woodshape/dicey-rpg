# Game — State, Loop & Drag-and-Drop

**Files:** `src/game.odin`, `src/main.odin`
**Types:** `Game_State`, `Drag_State`, `Drag_Source` (defined in `types.odin`)

## Responsibilities

- Define the top-level `Game_State` struct
- Initialize the game (parties, draft pool, round state, log)
- Run the main loop (init → update → draw → cleanup)
- Handle all drag-and-drop input (start drag, drop, cancel)
- Draw the full game screen (pool, hands, parties, HUD, overlays)

## Architecture

### Game_State

The single struct that holds ALL game state. Passed by pointer to every system.

```odin
Game_State :: struct {
    running:             bool,
    pool:                Draft_Pool,
    round:               Round_State,
    hand:                Hand,          // player hand
    enemy_hand:          Hand,          // enemy hand
    player_party:        Party,
    enemy_party:         Party,
    drag:                Drag_State,
    turn:                Turn_Phase,
    turn_timer:          f32,
    rolling_index:       int,           // which character is showing roll results
    log:                 Combat_Log,
    // Character inspect overlay
    inspect_active:      bool,
    inspect_party_enemy: bool,          // false = player party, true = enemy party
    inspect_char_index:  int,           // index into player_party or enemy_party
}
```

There are no globals. Every procedure receives what it needs through `Game_State` or direct parameters.

### Initialization

`game_init(encounter, prev_log, skull_chance, pool_size)` creates a fresh game state:

```odin
game_init :: proc(encounter: string = "tutorial", prev_log: ^Combat_Log = nil, skull_chance: int = SKULL_CHANCE, pool_size: int = DEFAULT_POOL_SIZE) -> (Game_State, bool)
```

- Returns `(Game_State, bool)` — the bool is `false` if config loading fails
- Calls `round_state_init(pool_size, skull_chance)` to create the `Round_State`, then `pool_generate(&round)` to populate the initial `Draft_Pool`
- Loads player and enemy parties via `config_load_encounter()` from `data/encounters/<encounter>.cfg`
- Preserves the combat log across Play Again restarts (if `prev_log` is provided)
- Starts on `Draft_Player_Pick` if `round.first_pick` is true, otherwise `Draft_Enemy_Pick`

### Main Loop

`main.odin` runs the standard Raylib loop:
```odin
rl.InitWindow(...)
gs := game_init(&log)
for !rl.WindowShouldClose() && gs.running {
    game_update(&gs)    // → combat_update(gs)
    game_draw(&gs)
}
```

`game_update` collects an `Input_State` struct from Raylib input functions (mouse position, button state, delta time) and passes it to `combat_update`. `game_draw` renders everything.

### Drag-and-Drop System

All dice movement uses drag-and-drop. There is no click-to-select.

**Drag sources:** Pool slot (draft phase only), Hand slot, Character die slot
**Drop targets:** Hand region, Character die slot

#### try_start_drag(gs, mouse_x, mouse_y)

Called on left mouse button press. Checks (in order):
1. Pool slot → start Pool drag if `is_draft_phase(gs.turn)` and slot is valid
2. Hand slot → start Hand drag if slot is occupied
3. Character slot → start Character drag if die is assigned and not rolled

Sets `gs.drag` with source, die type, and source indices for ghosting. Pool drags store `pool_index` in the drag state instead of board row/col.

#### try_drop(gs, mouse_x, mouse_y) → bool

Called on left mouse button release. Returns `true` if a Pick action was consumed (ends draft turn). Action types:

| Drag Source | Drop Target | Action Type | Ends Turn? |
|-------------|-------------|-------------|------------|
| Pool | Hand | Pick | Yes |
| Pool | Character | Pick | Yes |
| Hand | Character | Assign | No |
| Character | Hand | Assign (unassign) | No |

On an invalid drop (e.g., wrong target, full hand), the drag silently cancels.

### Drawing Pipeline

`game_draw(gs)` renders in this order:
1. Clear background (dark blue-gray)
2. Draft pool (`pool_draw`)
3. Player hand (`hand_draw`)
4. Player party (`party_draw`, interactive)
5. Enemy party (`party_draw`, non-interactive)
6. Enemy hand (`hand_draw_at`, non-interactive)
7. Dragged die following cursor (if drag active)
8. HUD: title, pool remaining/count, hand count, round number
9. Turn indicator (centred top)
10. Done button (only during `Combat_Player_Turn` when characters have assigned dice)
11. Combat log (centred bottom)
12. Character inspect overlay (if `inspect_active`) — centred, blocks all input until dismissed
13. Game over overlay (if Victory/Defeat)

### Turn Indicator Labels

`draw_turn_indicator` maps each phase to a label and colour:

| Turn_Phase | Label | Colour |
|------------|-------|--------|
| `Draft_Player_Pick` | "Your Pick" | Green |
| `Draft_Enemy_Pick` | "Enemy Pick" | Red |
| `Combat_Player_Turn` | "Your Turn" | Green |
| `Player_Roll_Result` | "Roll Result" | Yellow |
| `Combat_Enemy_Turn` | "Enemy Turn" | Red |
| `Enemy_Roll_Result` | "Enemy Roll" | Orange |
| `Round_End` | "Round End" | Muted yellow |

### Enemy Panel Position

`ENEMY_PANEL_X` is computed as `WINDOW_WIDTH - CHAR_PANEL_X - CHAR_PANEL_WIDTH` to mirror the player panel on the right side.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `game_init(encounter, prev_log, skull_chance, pool_size)` | Create fresh Game_State; returns (Game_State, bool) |
| `game_update(gs)` | Per-frame update (delegates to `combat_update`) |
| `game_draw(gs)` | Per-frame render |
| `is_draft_phase(turn)` | Returns true if turn is Draft_Player_Pick or Draft_Enemy_Pick |
| `try_start_drag(gs, mx, my)` | Begin a drag operation |
| `try_drop(gs, mx, my)` | Complete a drag — returns true if Pick action consumed |
| `inspect_get_character(gs)` | Return pointer to the character being inspected |
| `draw_turn_indicator(turn)` | Phase label at top of screen |
| `draw_done_button()` | Done button rendered during Combat_Player_Turn |
| `draw_game_over(turn)` | Victory/Defeat overlay with Play Again button |
| `draw_dragged_die(die_type, mx, my)` | Die following cursor |

## How to Extend

### Adding a new drag target

1. Add hit-testing in `try_drop` under the appropriate `Drag_Source` case
2. Call the relevant game logic (e.g., `character_assign_die`)
3. Return `true` if the action should end the turn, `false` if free

### Adding a new party member

Add the character creation call in `game_init`, increment the party `count`. The draw and interaction systems iterate `party.count` automatically.

## Best Practices

- All game state lives in `Game_State`. Do not use file-level or global variables.
- The drag state (`gs.drag`) is reset to zero on mouse release, regardless of whether the drop was valid.
- Pool drags are gated behind `is_draft_phase()` — do not allow pool interaction during combat phases.
- `game_draw` must be called every frame even during non-interactive phases (enemy turns, result displays) — the game continues to render.
- The combat log is preserved across Play Again via the `prev_log` parameter. The `Combat_Log` struct lives outside `Game_State` in `main.odin` and is passed in.

## What NOT to Do

- Do not put game logic in `game_draw`. Drawing is read-only — no state mutations.
- Do not put rendering code in `game_update`. The update/draw separation must stay clean.
- Do not add global variables. Everything goes through `Game_State`.
- Do not call `try_start_drag` or `try_drop` outside of the appropriate turn update procs — they assume player-controlled phase context.

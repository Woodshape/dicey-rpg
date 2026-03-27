# Game — State, Loop & Drag-and-Drop

**Files:** `src/game.odin`, `src/main.odin`
**Types:** `Game_State`, `Drag_State`, `Drag_Source` (defined in `types.odin`)

## Responsibilities

- Define the top-level `Game_State` struct
- Initialize the game (parties, board, log)
- Run the main loop (init → update → draw → cleanup)
- Handle all drag-and-drop input (start drag, drop, cancel)
- Draw the full game screen (board, hands, parties, HUD, overlays)

## Architecture

### Game_State

The single struct that holds ALL game state. Passed by pointer to every system.

```odin
Game_State :: struct {
    running:       bool,
    board:         Board,
    hand:          Hand,          // player hand
    enemy_hand:    Hand,          // enemy hand
    player_party:  Party,
    enemy_party:   Party,
    drag:          Drag_State,
    turn:          Turn_Phase,
    turn_timer:    f32,
    rolling_index: int,           // which character is showing roll results
    log:           Combat_Log,
}
```

There are no globals. Every procedure receives what it needs through `Game_State` or direct parameters.

### Initialization

`game_init(prev_log)` creates a fresh game state:
- Initializes the board via `board_init()`
- Creates player party (Warrior + Healer) and enemy party (Goblin + Shaman)
- Preserves the combat log across Play Again restarts (if `prev_log` is provided)
- Starts on `Player_Turn`

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

`game_update` delegates entirely to `combat_update`. `game_draw` renders everything.

### Drag-and-Drop System

All dice movement uses drag-and-drop. There is no click-to-select.

**Drag sources:** Board cell, Hand slot, Character die slot
**Drop targets:** Hand region, Character die slot

#### try_start_drag(gs, mouse_x, mouse_y)

Called on left mouse button press during `Player_Turn`. Checks (in order):
1. Board cell → start Board drag if cell is pickable
2. Hand slot → start Hand drag if slot is occupied
3. Character slot → start Character drag if die is assigned and not rolled

Sets `gs.drag` with source, die type, and source indices for ghosting.

#### try_drop(gs, mouse_x, mouse_y) → bool

Called on left mouse button release. Returns `true` if a Pick action was consumed (ends turn). Action types:

| Drag Source | Drop Target | Action Type | Ends Turn? |
|-------------|-------------|-------------|------------|
| Board | Hand | Pick | Yes |
| Board | Character | Pick | Yes |
| Hand | Character | Assign | No |
| Character | Hand | Assign (unassign) | No |

On an invalid drop (e.g., wrong target, full hand), the drag silently cancels.

### Drawing Pipeline

`game_draw(gs)` renders in this order:
1. Clear background (dark blue-gray)
2. Board (`board_draw`)
3. Player hand (`hand_draw`)
4. Player party (`party_draw`, interactive)
5. Enemy party (`party_draw`, non-interactive)
6. Enemy hand (`hand_draw_at`, non-interactive)
7. Dragged die following cursor (if drag active)
8. HUD: title, board count, hand count
9. Turn indicator (centred top)
10. Combat log (centred bottom)
11. Game over overlay (if Victory/Defeat)

### Enemy Panel Position

`ENEMY_PANEL_X` is computed as `WINDOW_WIDTH - CHAR_PANEL_X - CHAR_PANEL_WIDTH` to mirror the player panel on the right side.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `game_init(prev_log)` | Create fresh Game_State |
| `game_update(gs)` | Per-frame update (delegates to `combat_update`) |
| `game_draw(gs)` | Per-frame render |
| `try_start_drag(gs, mx, my)` | Begin a drag operation |
| `try_drop(gs, mx, my)` | Complete a drag — returns true if turn-ending |
| `draw_turn_indicator(turn)` | Phase label at top of screen |
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
- `game_draw` must be called every frame even during non-interactive phases (Enemy_Turn, result displays) — the game continues to render.
- The combat log is preserved across Play Again via the `prev_log` parameter. The `Combat_Log` struct lives outside `Game_State` in `main.odin` and is passed in.

## What NOT to Do

- Do not put game logic in `game_draw`. Drawing is read-only — no state mutations.
- Do not put rendering code in `game_update`. The update/draw separation must stay clean.
- Do not add global variables. Everything goes through `Game_State`.
- Do not call `try_start_drag` or `try_drop` outside of `player_turn_update` — they assume player turn context.

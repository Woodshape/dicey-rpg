# Headless Refactor — Extract Input from Update

Minimal refactor to decouple `combat.odin` update logic from Raylib input calls. Required for the headless combat simulator but also good hygiene — input injection enables testing, replay, and network play.

## Current State

The codebase is well-separated. All core logic is pure:

| File | Status |
|------|--------|
| `dice.odin` | Pure — no Raylib |
| `ai.odin` | Pure — imports `rl` but never uses it |
| `board.odin` | Logic procs pure, rendering isolated |
| `hand.odin` | Logic procs pure, rendering isolated |
| `character.odin` | Logic procs pure, rendering isolated |
| `ability.odin` | Logic procs pure, rendering isolated |
| `combat.odin` | **Violation** — Raylib input calls in update procs |
| `game.odin` | `game_draw` clean, `game_update` routes to `combat_update` |

## The Problem

Four procs in `combat.odin` call Raylib directly in the update phase:

| Proc | Raylib calls |
|------|-------------|
| `player_turn_update` | `rl.IsMouseButtonPressed`, `rl.GetMouseX/Y` |
| `player_roll_result_update` | `rl.GetFrameTime` |
| `enemy_roll_result_update` | `rl.GetFrameTime` |
| `game_over_update` | `rl.IsMouseButtonPressed`, `rl.GetMouseX/Y` |

## The Fix

### Step 1: Define an input struct

```odin
Input_State :: struct {
    mouse_x:       i32,
    mouse_y:       i32,
    left_pressed:  bool,
    right_pressed: bool,
    delta_time:    f32,
}
```

### Step 2: Collect input in one place

In `game_update` (or `main.odin`), read Raylib input once per frame into an `Input_State` and pass it down:

```odin
game_update :: proc(gs: ^Game_State) {
    input := Input_State {
        mouse_x       = rl.GetMouseX(),
        mouse_y       = rl.GetMouseY(),
        left_pressed  = rl.IsMouseButtonPressed(.LEFT),
        right_pressed = rl.IsMouseButtonPressed(.RIGHT),
        delta_time    = rl.GetFrameTime(),
    }
    combat_update(gs, input)
}
```

### Step 3: Thread input through combat procs

Replace all direct Raylib calls in `combat.odin` with reads from the `Input_State` parameter:

```odin
combat_update :: proc(gs: ^Game_State, input: Input_State) { ... }
player_turn_update :: proc(gs: ^Game_State, input: Input_State) { ... }
player_roll_result_update :: proc(gs: ^Game_State, input: Input_State) { ... }
enemy_roll_result_update :: proc(gs: ^Game_State, input: Input_State) { ... }
game_over_update :: proc(gs: ^Game_State, input: Input_State) { ... }
```

### Step 4: Remove `rl` import from combat.odin

After the refactor, `combat.odin` has zero Raylib dependency.

## Scope

- **Files changed:** `types.odin` (add `Input_State`), `combat.odin` (parameter threading), `game.odin` (input collection)
- **Files unchanged:** Everything else — the refactor is contained to the update pipeline
- **Tests:** All existing tests continue to pass (they don't touch `combat_update`)
- **Behaviour:** Identical — the same Raylib calls happen, just one layer up

## Simulator Benefit

With input extracted, the simulator provides its own input:

```odin
// Headless: no mouse, no frame time for display
// AI drives both sides, roll results resolve instantly
sim_input := Input_State {
    delta_time = 999.0,  // skip all display timers instantly
}
combat_update(&gs, sim_input)
```

The simulator never calls Raylib input functions. It may still link against Raylib (types, colours) but never opens a window.

## Also Consider

- `ai.odin` imports `rl` but never uses it — remove the import as cleanup.
- Hit-test helpers (`mouse_to_cell`, `mouse_to_hand_slot`, etc.) already take coordinates as parameters — they work with injected input as-is.
- `resolve_roll` uses `rl.Color` for combat log entries — this is a data type, not a rendering call. Acceptable to keep.

# Hand — Dice Staging Area

**File:** `src/hand.odin`
**Types:** `Hand` (defined in `types.odin`)
**Tests:** `tests/hand_test.odin`

## Responsibilities

- Manage a fixed-size collection of dice (add, remove, discard)
- Enforce hand capacity (`MAX_HAND_SIZE`)
- Provide screen positions and hit-testing for hand slots
- Draw the hand with drag-and-drop interaction (player) or read-only display (enemy)

## Architecture

### Data Model

The hand uses the **fixed-size array + count** pattern used throughout the codebase:

```odin
Hand :: struct {
    dice:  [MAX_HAND_SIZE]Die_Type,
    count: int,
}
```

Active dice occupy indices `0..count-1`. Slots beyond `count` must be zeroed (`Die_Type.None`). On removal, remaining dice shift left and the vacated slot is explicitly cleared.

### Discard System

`hand_discard` destroys a die from the hand (it is not returned to the pool). This is a free action — no turn cost. The `hand_can_discard` function is the extension point for future blocking status effects (e.g., Frozen dice that cannot be discarded).

### Two-Side Layout

Both player and enemy have hands. Position helpers are parameterized by a centre X anchor:

- **Player:** `PLAYER_HAND_CENTER_X` (left third of screen)
- **Enemy:** `ENEMY_HAND_CENTER_X` (right third of screen)

The `hand_draw_at` procedure takes `interactive: bool` to control whether drag/hover/drop visuals appear.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `hand_add(hand, die_type)` | Add a die. Asserts not `.None`. Returns false if full. |
| `hand_remove(hand, index)` | Remove by index, shift left, clear vacated. Returns (type, ok). |
| `hand_discard(hand, index)` | Discard (destroy) a die. Checks `hand_can_discard` first. |
| `hand_can_discard(hand, index)` | Extension point for blocking status effects. Currently always true. |
| `hand_is_full(hand)` | True if `count >= MAX_HAND_SIZE`. |
| `hand_slot_position(index)` | Player hand slot pixel position. |
| `hand_slot_position_at(center_x, index)` | Parameterized slot position. |
| `mouse_to_hand_slot(mx, my)` | Hit-test player hand slots. Returns index or -1. |
| `mouse_in_hand_region(mx, my)` | Loose region check for drop targeting. |
| `hand_draw(hand, drag)` | Draw player hand (interactive). |
| `hand_draw_at(hand, center_x, drag, interactive)` | Draw any hand at a position. |

## How to Use

```odin
// Pick a die from the pool into the hand
if !hand_is_full(&hand) {
    die_type, ok := pool_remove_die(&pool, index)
    if ok { hand_add(&hand, die_type) }
}

// Discard (player right-click)
if hand_can_discard(&hand, slot) {
    hand_discard(&hand, slot)
}

// Move die from hand to character (free action)
die_type, ok := hand_remove(&hand, index)
if ok { character_assign_die(&character, die_type) }
```

## Best Practices

- Always check capacity before adding: `hand_is_full` or check the return value of `hand_add`.
- Never add `Die_Type.None` — `hand_add` asserts against this.
- After removal, verify the vacated slot is zeroed in tests — this catches stale data bugs.
- Use `mouse_in_hand_region` for loose drop targeting (the player doesn't have to hit an exact slot).

## What NOT to Do

- Do not set `hand.dice[i]` or `hand.count` directly. Use `hand_add` / `hand_remove` which maintain the array invariants.
- Do not assume `hand_remove` returns `.None` on failure — it returns `.D4` (the first real enum value). Always check the `bool` return.
- Do not use `mouse_to_hand_slot` for the enemy hand — it's hardcoded to player positions. Use `hand_slot_position_at` with the enemy centre X for custom hit-testing if needed.

## Test Coverage

`tests/hand_test.odin` — 9 tests:

**Capacity:** `hand_add_up_to_max`, `hand_rejects_when_full`

**Removal:** `hand_remove_shifts_dice`, `hand_remove_clears_vacated_slots`, `hand_remove_invalid_index`

**Discard:** `hand_discard_removes_die`, `hand_discard_invalid_index`, `hand_discard_frees_slot_for_new_die`, `hand_can_discard_valid`

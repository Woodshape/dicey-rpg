# Board — Grid, Gradient & Perimeter

**File:** `src/board.odin`
**Types:** `Board`, `Board_Cell` (defined in `types.odin`)
**Tests:** `tests/board_test.odin`

## Responsibilities

- Initialize the board with dice distributed by a rarity gradient
- Calculate which ring each cell belongs to
- Determine which cells are pickable (perimeter logic)
- Remove dice from the board
- Convert between grid coordinates and pixel positions
- Draw the board with hover/drag visual feedback

## Architecture

The board is a square grid of `BOARD_SIZE × BOARD_SIZE` cells. Each cell holds a `Die_Type`, an `occupied` flag, and a precomputed `ring` depth.

### Ring System

`cell_ring(board, row, col)` returns the concentric ring index: 0 = outermost, increasing inward. Calculated as `min(row, col, size-1-row, size-1-col)`. The maximum ring is `(size - 1) / 2` (the centre for odd-sized boards).

### Rarity Gradient

`ring_die_type(ring, max_ring)` determines the die type for a cell using weighted random selection based on depth:

- **Depth 0.0** (outer): mostly d4/d6
- **Depth 0.5** (middle): d8 peaks, some d6/d10
- **Depth 1.0** (near centre): mostly d10/d12

The centre ring is always forced to d12 in `board_init`. Any cell has a `SKULL_CHANCE%` probability of becoming a skull die before the normal gradient is applied.

The weight functions are continuous curves, not discrete buckets — each die type fades smoothly across depth:
```
w_d4  = max(1.0 - depth * 2.5, 0.0)
w_d6  = max(1.0 - depth * 1.5, 0.0)
w_d8  = max(1.0 - abs(depth - 0.5) * 1.5, 0.0)
w_d10 = max(depth * 1.5 - 0.5, 0.0)
w_d12 = max(depth * 2.0 - 1.0, 0.0)
```

### Perimeter Logic

`cell_is_pickable(board, row, col)` returns true if the cell is occupied AND has at least one neighbour that is empty or out of bounds (grid edge). This means:

- Initially, only the outer ring is pickable (all outer cells border the grid edge)
- Removing an outer cell exposes the inner neighbour if it now borders the gap
- Exposure is per-cell, not per-ring — partial ring removal creates selective access

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `board_init()` | Create a new board with gradient-distributed dice |
| `cell_ring(board, row, col)` | Ring depth of a cell (0 = outer) |
| `ring_die_type(ring, max_ring)` | Weighted random die type for a ring |
| `cell_is_pickable(board, row, col)` | Is this cell on the accessible perimeter? |
| `board_remove_die(board, row, col)` | Remove a die; returns (type, ok). Validates perimeter. |
| `board_count_dice(board)` | Count remaining occupied cells |
| `board_has_pickable(board)` | Any pickable cells left? (triggers board refill) |
| `board_origin(board)` | Top-left pixel of the centred board |
| `cell_position(board, row, col)` | Pixel position of a specific cell |
| `mouse_to_cell(board, mx, my)` | Mouse position → grid coords (or -1,-1) |
| `board_draw(board, drag)` | Render the board with hover/drag visuals |

## How to Use

```odin
// Create a fresh board
board := board_init()

// Check if player can pick from a cell
if cell_is_pickable(&board, row, col) {
    die_type, ok := board_remove_die(&board, row, col)
    if ok { hand_add(&hand, die_type) }
}

// Refill when depleted
if !board_has_pickable(&board) {
    board = board_init()
}
```

## Best Practices

- Always check `cell_is_pickable` before removing. `board_remove_die` also validates internally but returns false instead of asserting.
- Board refill is handled in `combat.odin` via `check_board_refill`. Don't refill from within board logic.
- The gradient weights are tuned for a 5×5 board. Changing `BOARD_SIZE` affects the number of rings and how the gradient distributes — verify with the gradient tests.

## What NOT to Do

- Do not place dice directly by setting `board.cells[r][c]`. Use `board_init` for fresh boards.
- Do not check ring depth manually — use `cell_ring` which handles all edge math.
- Do not assume the centre is always a single cell. For even-sized boards (not currently used), there's no single centre.

## Test Coverage

`tests/board_test.odin` — 18 tests:

**Ring calculation:** `ring_corners_are_zero`, `ring_centre_is_max`, `ring_edges_are_zero`, `ring_middle_layer`

**Perimeter:** `full_board_perimeter_is_outer_ring`, `inner_cell_exposed_after_removal`, `cannot_remove_non_perimeter`

**Removal:** `remove_returns_die_type`, `board_count_decreases_on_removal`

**Gradient:** `board_gradient_outer_ring_has_no_d10_d12`, `board_gradient_centre_is_always_d12`, `gradient_outer_ring_is_mostly_small_dice`, `gradient_inner_ring_has_d10_and_d12`, `gradient_inner_ring_has_no_d4`, `gradient_d8_peaks_at_middle_depth`, `gradient_monotonic_high_tier_increases_with_depth`, `gradient_all_five_die_types_appear_on_board`, `gradient_skull_dice_appear_in_all_rings`

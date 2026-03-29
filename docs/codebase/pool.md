# Pool — Draft Pool & Weight Groups

**File:** `src/pool.odin`
**Types:** `Draft_Pool`, `Weight_Group`, `Round_State` (defined in `types.odin`)
**Tests:** `tests/pool_test.odin`

## Responsibilities

- Initialize round state with shuffled weight group cycles
- Generate dice pools biased by weight group
- Remove dice from the pool (shift left, zero vacated)
- Provide screen positions and hit-testing for pool slots
- Draw the pool with hover/drag visual feedback

## Architecture

### Draft Pool

The pool is a flat array of dice (`[MAX_POOL_SIZE]Die_Type`) displayed as a horizontal row. All dice are always pickable — no perimeter logic. The pool is fully drafted each round (alternating picks until empty), then regenerated for the next round.

### Weight Groups

Four weight groups bias the pool toward different die types:

| Group | Primary Types | Bias |
|-------|--------------|------|
| Low | d4, d6 | High consistency, low value |
| Mid_Low | d6, d8 | Balanced-low |
| Mid_High | d8, d10 | Balanced-high |
| High | d10, d12 | High risk, high reward |

Each group sets weights for a weighted random roll. A "Low" round is mostly d4/d6 but a d8 can still appear. Weight curves:

```
Low:      d4=1.0  d6=0.8  d8=0.2  d10=0.0  d12=0.0
Mid_Low:  d4=0.2  d6=0.8  d8=1.0  d10=0.2  d12=0.0
Mid_High: d4=0.0  d6=0.2  d8=0.8  d10=1.0  d12=0.3
High:     d4=0.0  d6=0.0  d8=0.2  d10=0.8  d12=1.0
```

### Weight Group Cycling

Groups cycle in a shuffled non-repeating order (Fisher-Yates shuffle):
1. Shuffle all 4 groups into a random order
2. Each round uses the next group in the sequence
3. After all 4 groups are used, reshuffle and start a new cycle

This ensures variety while keeping the order unpredictable.

### Skull Dice

Each die has a `skull_chance%` probability of being a skull before the weight group distribution is applied. Configurable per encounter. Default: `SKULL_CHANCE = 10%`.

### Round State

`Round_State` tracks the cycling and round progression:
- `group_order` — the current shuffled cycle (4 groups)
- `cycle_index` — position in the current cycle
- `round_number` — 1-based, increments each round
- `first_pick` — alternates each round (player first in round 1)
- `pool_size` — dice per round (default 6)
- `skull_chance` — % per die

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `round_state_init(pool_size, skull_chance)` | Create initial Round_State, shuffle first cycle |
| `round_state_advance(round)` | Next weight group, reshuffle if cycle exhausted, alternate first pick |
| `pool_generate(round)` | Generate N dice using current weight group + skull chance |
| `pool_remove_die(pool, index)` | Remove by index, shift left, clear vacated. Returns (type, ok). |
| `pool_is_empty(pool)` | True if remaining == 0 |
| `weight_group_die_type(group, skull_chance)` | Weighted random die type for a group |
| `pool_origin(count)` | Top-left pixel of the centred pool |
| `pool_slot_position(index, count)` | Pixel position of Nth die in pool |
| `mouse_to_pool_slot(pool, mx, my)` | Hit-test pool slots, returns index or -1 |
| `pool_draw(pool, drag)` | Render pool with hover/drag visuals |

## How to Use

```odin
// Initialize round state
round := round_state_init()
pool := pool_generate(&round)

// Pick a die from the pool
die_type, ok := pool_remove_die(&pool, index)
if ok { hand_add(&hand, die_type) }

// Advance to next round
round_state_advance(&round)
pool = pool_generate(&round)
```

## Best Practices

- Always check `pool_is_empty` or the return value of `pool_remove_die` before accessing pool dice.
- Pool regeneration happens in `round_end_update` (combat.odin). Don't regenerate from within pool logic.
- The pool renders centred horizontally in the upper third of the screen. Dice recentre as they're removed.
- Pool dice use `draw_die_shape`/`draw_die_outline` (from `game.odin`) for Platonic solid silhouettes — not plain rectangles.

## What NOT to Do

- Do not set `pool.dice[i]` or `pool.remaining` directly. Use `pool_remove_die` which maintains array invariants.
- Do not assume pool dice are in any particular order — weight group selection is random.

## Test Coverage

`tests/pool_test.odin` — 17 tests:

**Generation:** `pool_generate_correct_count`, `pool_generate_custom_size`, `pool_generate_all_dice_are_valid`

**Operations:** `pool_remove_shifts_remaining`, `pool_remove_clears_vacated_slot`, `pool_remove_invalid_index`, `pool_is_empty_after_full_draft`

**Weight group distribution:** `pool_low_group_is_mostly_small_dice`, `pool_high_group_is_mostly_big_dice`, `pool_mid_groups_include_d8`, `pool_all_die_types_appear_across_groups`, `pool_skull_dice_appear_at_configured_rate`, `pool_no_skulls_when_zero_chance`

**Weight group cycling:** `weight_group_cycle_visits_all_four`, `weight_group_non_repeating_within_cycle`

**Round state:** `first_pick_alternates`, `round_number_increments`

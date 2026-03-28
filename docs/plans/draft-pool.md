# Draft Pool — Implementation Plan

**Design doc:** `docs/ideas/draft-pool.md`
**Status:** Not Started
**Replaces:** Board grid system (Milestone 1 artifact)

---

## Architecture Overview

```
                         ROUND LOOP
                    ┌──────────────────┐
                    │                  │
                    ▼                  │
             ┌─────────────┐          │
             │  POOL INIT  │          │
             │             │          │
             │ weight group │          │
             │ skull check  │          │
             │ N dice gen   │          │
             └──────┬──────┘          │
                    │                  │
                    ▼                  │
        ┌───────────────────────┐     │
        │     DRAFT PHASE       │     │
        │                       │     │
        │  Player picks 1 die   │     │
        │  (free assign/discard)│     │
        │         ▼             │     │
        │  Enemy picks 1 die    │     │
        │  (free assign/discard)│     │
        │         ▼             │     │
        │  (repeat until pool   │     │
        │   is empty: 3 each)   │     │
        └───────────┬───────────┘     │
                    │                  │
                    ▼                  │
        ┌───────────────────────┐     │
        │    COMBAT PHASE       │     │
        │                       │     │
        │  Player turn:         │     │
        │    free assign/discard│     │
        │    roll one or pass   │     │
        │         ▼             │     │
        │  Enemy turn:          │     │
        │    free assign/discard│     │
        │    roll one or pass   │     │
        │         ▼             │     │
        │  (repeat until both   │     │
        │   pass consecutively) │     │
        └───────────┬───────────┘     │
                    │                  │
                    ▼                  │
              ┌──────────┐            │
              │ WIN/LOSE │────no──────┘
              │  CHECK   │
              └────┬─────┘
                   │ yes
                   ▼
              ┌──────────┐
              │ GAME OVER│
              └──────────┘
```

### State Machine (new Turn_Phase)

```
Draft_Player_Pick ──▶ Draft_Enemy_Pick ──▶ Draft_Player_Pick ...
        │                                          │
        └──── (pool empty) ────────────────────────┘
                    │
                    ▼
        Combat_Player_Turn ──▶ Player_Roll_Result
                                      │
                                      ▼
                            Combat_Enemy_Turn ──▶ Enemy_Roll_Result
                                                        │
                                                        ▼
                                              Combat_Player_Turn ...
                                                        │
                                               (both sides pass)
                                                        │
                                                        ▼
                                                  Round_End
                                                    │    │
                                                    │    ▼
                                                    │  Victory / Defeat
                                                    ▼
                                             Draft_Player_Pick (next round)
```

The combat phase is structurally identical to the current `Player_Turn → Enemy_Turn` loop — alternating turns with free assignment — just without the pick action. The draft phase is a new sub-loop prepended to each round.

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        Game_State                           │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │Draft_Pool│   │  Hand    │   │  Hand    │               │
│  │          │──▶│ (player) │   │ (enemy)  │               │
│  │ dice[N]  │   │ dice[5]  │   │ dice[5]  │               │
│  │ count    │   └────┬─────┘   └────┬─────┘               │
│  │ weight_  │        │              │                       │
│  │  group   │        ▼              ▼                       │
│  └──────────┘   ┌──────────┐   ┌──────────┐               │
│                 │  Player  │   │  Enemy   │               │
│  ┌──────────┐   │  Party   │   │  Party   │               │
│  │ Round    │   │          │   │          │               │
│  │ State    │   │ char[4]  │   │ char[4]  │               │
│  │          │   │ assigned │   │ assigned │               │
│  │ groups[] │   │ roll     │   │ roll     │               │
│  │ cycle_idx│   └──────────┘   └──────────┘               │
│  │ round_num│                                              │
│  │ first_   │   ┌──────────┐                               │
│  │  pick    │   │Combat_Log│                               │
│  └──────────┘   └──────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Files Changed

| File | Action | Summary |
|------|--------|---------|
| `src/types.odin` | **Modify** | Remove `Board`, `Board_Cell`, board constants. Add `Draft_Pool`, `Weight_Group`, `Round_State`. Rework `Turn_Phase` enum. Update `Drag_Source`. |
| `src/board.odin` | **Delete** | Entire file replaced by `pool.odin`. |
| `src/pool.odin` | **Create** | Pool generation, weight group cycling, rendering, hit-testing, drag source. |
| `src/combat.odin` | **Modify** | Add draft phase handlers. Remove `check_board_refill`. Rename `player_turn_update` / `enemy_turn_update` for combat phase (remove pick logic). Add `round_end_update`. |
| `src/game.odin` | **Modify** | `Game_State`: pool replaces board, add `Round_State`. `game_init`: pool init replaces board init. `try_start_drag`/`try_drop`: pool replaces board as drag source. `game_draw`: pool replaces board drawing. HUD: pool count replaces board count. |
| `src/ai.odin` | **Modify** | `ai_pick_best_die`: scan pool instead of board grid. Remove `ai_pick_any_die` (pool has no perimeter). Simplify `ai_should_roll` (no board dependency). Split `ai_take_turn` into draft-phase and combat-phase logic. |
| `src/config.odin` | **Modify** | Add `pool_size` and `skull_chance` to encounter config parsing. |
| `sim/main.odin` | **Modify** | Adapt headless game loop to new phase structure. Remove `check_board_refill` calls. |
| `tests/board_test.odin` | **Delete** | Replaced by `pool_test.odin`. |
| `tests/pool_test.odin` | **Create** | Weight group distribution, pool generation, cycling, skull chance. |
| `tests/combat_test.odin` | **Modify** | Update tests for new Turn_Phase values. Remove board refill tests. Add draft phase tests. |
| `tests/ai_test.odin` | **Modify** | Adapt `ai_picks_from_board` → `ai_picks_from_pool`. Remove board-dependent setup. |
| `docs/codebase/board.md` | **Delete** | Replaced by `pool.md`. |
| `docs/codebase/pool.md` | **Create** | Module reference doc for `pool.odin`. |
| `docs/codebase/combat.md` | **Update** | Document new state machine and phase structure. |
| `docs/codebase/game.md` | **Update** | Document new `Game_State` fields and drag changes. |
| `docs/codebase/ai.md` | **Update** | Document pool scanning instead of board scanning. |
| `docs/codebase/types.md` | **Update** | Document new types, removed types, changed enums. |
| `docs/codebase/config.md` | **Update** | Document pool_size/skull_chance in encounter config. |

---

## Implementation Steps

### Step 0: Preparation

**Goal:** Understand all dependencies before touching code.

- [ ] Grep all `src/` files for references to `board`, `Board`, `Board_Cell`, `BOARD_SIZE`, `CELL_SIZE`, `CELL_GAP`, `CELL_STRIDE`, `cell_ring`, `cell_is_pickable`, `board_init`, `board_remove_die`, `board_count_dice`, `board_has_pickable`, `board_origin`, `cell_position`, `mouse_to_cell`, `board_draw`, `check_board_refill`
- [ ] Grep `sim/` for the same
- [ ] Map every call site to understand the full blast radius
- [ ] Identify which board references are logic vs rendering (logic changes first, rendering last)

---

### Step 1: New Types in `types.odin`

**Goal:** Define all new data structures. No logic yet — just types and constants.

**Add:**

```odin
// Draft pool
MAX_POOL_SIZE :: 12  // generous upper bound for variable pool sizes
DEFAULT_POOL_SIZE :: 6

Weight_Group :: enum u8 {
    Low,      // d4, d6 bias
    Mid_Low,  // d6, d8 bias
    Mid_High, // d8, d10 bias
    High,     // d10, d12 bias
}
WEIGHT_GROUP_COUNT :: 4

Draft_Pool :: struct {
    dice:         [MAX_POOL_SIZE]Die_Type,
    count:        int,   // total dice in pool this round
    remaining:    int,   // dice not yet picked
    weight_group: Weight_Group,
    skull_chance:  int,
}

Round_State :: struct {
    group_order:   [WEIGHT_GROUP_COUNT]Weight_Group,  // shuffled cycle
    cycle_index:   int,                                // position in current cycle
    round_number:  int,                                // 1-based, increments each draft round
    first_pick:    bool,                               // true = player picks first this round
    pool_size:     int,                                // dice per round (default 6)
    skull_chance:  int,                                // % per die
}
```

**Modify `Turn_Phase`:**

```odin
Turn_Phase :: enum u8 {
    // Draft phase
    Draft_Player_Pick,
    Draft_Enemy_Pick,
    // Combat phase
    Combat_Player_Turn,    // free assign/discard + roll one character or pass
    Player_Roll_Result,    // timed display
    Combat_Enemy_Turn,     // AI assigns + rolls one character or passes
    Enemy_Roll_Result,     // timed display
    // Round boundary
    Round_End,             // check win/lose, advance to next draft
    // Terminal
    Victory,
    Defeat,
}
```

**Modify `Drag_Source`:**

```odin
Drag_Source :: enum {
    None,
    Pool,       // was Board
    Hand,
    Character,
}
```

**Modify `Drag_State`:** Replace `board_row`/`board_col` with `pool_index: int`.

**Remove:** `Board_Cell`, `Board`, `BOARD_SIZE`, `CELL_SIZE`, `CELL_GAP`, `CELL_STRIDE`.

**Modify `Game_State`** (in `game.odin`): Replace `board: Board` with `pool: Draft_Pool` and add `round: Round_State`.

- [ ] Add new types and constants
- [ ] Modify Turn_Phase enum
- [ ] Modify Drag_Source and Drag_State
- [ ] Remove Board types and constants (will break compilation — expected)

---

### Step 2: Create `src/pool.odin`

**Goal:** Pool generation, weight group logic, rendering, hit-testing. This is the direct replacement for `board.odin`.

**Procedures:**

| Procedure | Purpose |
|-----------|---------|
| `round_state_init(pool_size, skull_chance)` | Create initial Round_State, shuffle first weight group cycle |
| `round_state_next_group(round)` | Advance to next weight group, reshuffle if cycle complete |
| `pool_generate(round)` | Generate N dice using current weight group bias + skull chance |
| `pool_remove_die(pool, index)` | Remove a die by index, shift remaining left |
| `pool_is_empty(pool)` | True if remaining == 0 |
| `weight_group_die_type(group, skull_chance)` | Weighted random die type for a group |
| `pool_origin()` | Top-left pixel position (centred on screen) |
| `pool_slot_position(index, count)` | Pixel position of Nth die in pool |
| `mouse_to_pool_slot(pool, mx, my)` | Hit-test pool slots, returns index or -1 |
| `pool_draw(pool, drag)` | Render pool dice with hover/drag visuals |

**Weight curves per group** (starting point, tunable):

```
Group Low:      w_d4=1.0  w_d6=0.8  w_d8=0.2  w_d10=0.0  w_d12=0.0
Group Mid_Low:  w_d4=0.2  w_d6=0.8  w_d8=1.0  w_d10=0.2  w_d12=0.0
Group Mid_High: w_d4=0.0  w_d6=0.2  w_d8=0.8  w_d10=1.0  w_d12=0.3
Group High:     w_d4=0.0  w_d6=0.0  w_d8=0.2  w_d10=0.8  w_d12=1.0
```

**Rendering layout:** Dice displayed in a horizontal row, centred on screen. Each die is a coloured rectangle with type label (same visual style as board cells but laid out linearly). Picked dice are removed from the visual.

- [ ] Implement `round_state_init` and `round_state_next_group` (with shuffle)
- [ ] Implement `weight_group_die_type` with weight curves per group
- [ ] Implement `pool_generate`
- [ ] Implement `pool_remove_die` and `pool_is_empty`
- [ ] Implement layout/hit-testing: `pool_origin`, `pool_slot_position`, `mouse_to_pool_slot`
- [ ] Implement `pool_draw`

---

### Step 3: Delete `src/board.odin`

**Goal:** Remove the old board module entirely. Compilation will fail on all call sites — that's intentional. Each subsequent step fixes a set of call sites.

- [ ] Delete `src/board.odin`
- [ ] Delete `tests/board_test.odin`

---

### Step 4: Update `src/combat.odin`

**Goal:** Add draft phase handlers, adapt combat phase, add round transitions.

The combat phase is structurally the same as the current system — alternating turns with free assignment — just without the pick action. The draft phase is a new sub-loop prepended to each round.

**Remove:**
- `check_board_refill` — no board to refill; pool regenerates each round

**Rename/adapt existing handlers:**
- `player_turn_update` → `combat_player_turn_update` — remove pick logic (board drag/drop), keep assignment, discard, and roll. Add "Pass" action (or auto-pass if no characters have dice).
- `enemy_turn_update` → `combat_enemy_turn_update` — remove pick logic, keep AI assign + roll. AI passes when `ai_should_roll` returns false.

**Add new handlers:**

| Handler | Drives |
|---------|--------|
| `draft_player_pick_update(gs, input)` | Player drags a die from pool to hand. Free assign/discard also available. Advances to `Draft_Enemy_Pick` after a pick. |
| `draft_enemy_pick_update(gs)` | AI picks from pool. Advances to `Draft_Player_Pick` or combat phase if pool empty. |
| `round_end_update(gs)` | Check win/lose. If game continues: advance round number, alternate first pick, generate new pool, advance to draft phase. |

**Key change — draft pick as phase alternator:**

A draft pick advances to the *other side's draft pick* within the same phase. The draft phase is its own sub-loop:

```
Draft_Player_Pick → Draft_Enemy_Pick → Draft_Player_Pick → ...
                                              ↓ (pool empty)
                                        Combat_Player_Turn
```

First pick alternates each round via `round.first_pick`. When `!round.first_pick`, the draft starts at `Draft_Enemy_Pick` instead.

**Combat phase — alternating turns with pass:**

The player and enemy alternate combat turns. On each turn, the active side can assign freely and either roll one character or pass. When both sides pass consecutively, the round ends. This uses a `consecutive_passes` counter on `Game_State` (or `Round_State`), reset to 0 whenever a roll happens, incremented on each pass.

Auto-pass: if no alive character on the active side has assigned dice, that side auto-passes (no player input needed).

**`combat_update` dispatcher** — expand the `#partial switch` to cover all new phases.

**Condition ticking** — per-side at combat turn start, same as current. Tick player conditions when `Combat_Player_Turn` begins, tick enemy conditions when `Combat_Enemy_Turn` begins. Only tick on the *first* combat turn of each round (not on every alternation within a round) to preserve the "N turns" semantic.

- [ ] Remove `check_board_refill`
- [ ] Add draft phase handlers: `draft_player_pick_update`, `draft_enemy_pick_update`
- [ ] Adapt `player_turn_update` → `combat_player_turn_update` (remove pick, add pass)
- [ ] Adapt `enemy_turn_update` → `combat_enemy_turn_update` (remove pick, add pass)
- [ ] Add `round_end_update` with pool regeneration and first-pick alternation
- [ ] Add consecutive-pass tracking for round end detection
- [ ] Update `combat_update` dispatcher for all new phases
- [ ] Update condition ticking for new phase transitions

---

### Step 5: Update `src/game.odin`

**Goal:** Wire the new pool and round state into `Game_State`, drag-and-drop, and rendering.

**`Game_State`:**
- Replace `board: Board` → `pool: Draft_Pool`
- Add `round: Round_State`

**`game_init`:**
- Replace `board_init(skull_chance)` with `round_state_init(pool_size, skull_chance)` + `pool_generate(&gs.round)`
- Accept `pool_size` parameter (default `DEFAULT_POOL_SIZE`)

**`try_start_drag`:**
- Replace board hit-testing (`mouse_to_cell`, `cell_is_pickable`) with `mouse_to_pool_slot`
- Change `Drag_Source.Board` → `Drag_Source.Pool`
- Store `pool_index` instead of `board_row`/`board_col`
- Only allow pool drags during draft phases

**`try_drop`:**
- Replace `board_remove_die` with `pool_remove_die`
- Board → pool in the `.Pool` case
- Pool always goes to hand (no direct-to-character pool drops in v1)

**`game_draw`:**
- Replace `board_draw` with `pool_draw`
- Update HUD: pool remaining count replaces board count
- Update turn indicator labels for new phases

**`draw_turn_indicator`:** Add labels for all new Turn_Phase values:
- `Draft_Player_Pick` → "Your Pick"
- `Draft_Enemy_Pick` → "Enemy Pick"
- `Combat_Player_Turn` → "Your Turn"
- `Player_Roll_Result` → "Roll Result"
- `Combat_Enemy_Turn` → "Enemy Turn"
- `Enemy_Roll_Result` → "Roll Result"
- `Round_End` → "Round End"

- [ ] Update `Game_State` struct
- [ ] Update `game_init`
- [ ] Rewrite `try_start_drag` for pool
- [ ] Rewrite `try_drop` for pool
- [ ] Update `game_draw` and HUD
- [ ] Update `draw_turn_indicator` for new phases

---

### Step 6: Update `src/ai.odin`

**Goal:** AI picks from pool instead of board. Simpler — no perimeter logic.

**`ai_pick_best_die`:**
- Scan `gs.pool.dice[0..remaining]` instead of board grid
- No `cell_is_pickable` check — all pool dice are pickable
- Return `pool_index` instead of `(row, col)`
- Signature change: `-> (int, bool)` instead of `-> (int, int, bool)`

**`ai_pick_any_die`:**
- Trivial: return index 0 if pool is not empty. May be removable entirely since all pool dice are valid picks.

**`ai_take_turn` split into two procs:**

`ai_draft_pick(gs)` — called during `Draft_Enemy_Pick`:
1. Score all pool dice via `ai_score_die_for_party`
2. Pick the best one → `pool_remove_die`, `hand_add`
3. `ai_assign_from_hand` (free action after pick)
4. Advance to `Draft_Player_Pick` (or combat phase if pool empty)

`ai_combat_turn(gs)` — called during `Combat_Enemy_Turn`:
1. `ai_assign_from_hand` (free action)
2. If `ai_should_roll` → roll, resolve, advance to `Enemy_Roll_Result`
3. Else → pass (increment consecutive passes, advance to `Combat_Player_Turn`)

**`ai_should_roll`:**
- Remove the `ai_pick_best_die` check ("no useful picks on board"). In the new system, rolling only happens in the combat phase when drafting is already complete. The AI should roll any character with >= 2 normal dice assigned.
- Keep the "skulls-only when stuck" last resort.

- [ ] Rewrite `ai_pick_best_die` to scan pool
- [ ] Simplify or remove `ai_pick_any_die`
- [ ] Split `ai_take_turn` into `ai_draft_pick` and `ai_combat_turn`
- [ ] Simplify `ai_should_roll` (no board dependency)

---

### Step 7: Update `src/config.odin`

**Goal:** Support pool parameters in encounter configs.

Add optional fields to encounter config root scope:

```
pool_size = 6
skull_chance = 10
```

Both default to the global constants if not specified. `config_load_encounter` returns these values (add to return tuple or load into a new `Encounter_Config` struct).

- [ ] Add `pool_size` and `skull_chance` as optional encounter config fields
- [ ] Parse and validate in `config_load_encounter`
- [ ] Thread values into `game_init`

---

### Step 8: Update `sim/main.odin`

**Goal:** Headless game loop works with the new phase structure.

The simulator's `run_game` loop switches on `Turn_Phase`. It needs to handle all new phases:

**Draft phases:** Both sides pick via AI. No display timer — instant resolution.
```
Draft_Player_Pick → swap_sides, ai_draft_pick, swap_sides, fix phase
Draft_Enemy_Pick  → ai_draft_pick
```

**Combat phases:** Similar to current roll handling but separated from picks.
```
Combat_Player_Turn → swap_sides, ai_combat_turn, swap_sides, fix phase
Combat_Enemy_Turn  → ai_combat_turn
*_Roll_Result      → clear roll, advance (no timer)
Round_End          → pool_generate, advance to next draft
```

The `check_board_refill` calls are removed entirely.

- [ ] Update `run_game` switch to handle all new Turn_Phase values
- [ ] Remove `check_board_refill` calls
- [ ] Add pool generation at `Round_End`
- [ ] Verify swap_sides still works for player-side AI

---

### Step 9: Write Tests — `tests/pool_test.odin`

**Goal:** Replace board tests with pool tests covering the new system.

**Weight group distribution (statistical, like board gradient tests):**
- `pool_low_group_is_mostly_small_dice` — Low group produces d4/d6, no d10/d12
- `pool_high_group_is_mostly_big_dice` — High group produces d10/d12, no d4
- `pool_mid_groups_include_d8` — Mid groups have d8 presence
- `pool_all_die_types_appear_across_groups` — over many samples, every type appears
- `pool_skull_dice_appear_at_configured_rate` — skull chance works

**Pool mechanics:**
- `pool_generate_correct_count` — pool.count == pool_size
- `pool_remove_shifts_remaining` — removal shifts, remaining decrements
- `pool_remove_clears_vacated_slot` — vacated slot is zeroed
- `pool_is_empty_after_full_draft` — empty after N removals

**Weight group cycling:**
- `weight_group_cycle_visits_all_four` — first 4 rounds use all 4 groups
- `weight_group_cycle_reshuffles_after_four` — next 4 rounds are a new permutation
- `weight_group_non_repeating_within_cycle` — no group appears twice in one cycle

**Round state:**
- `first_pick_alternates` — player first in round 1, enemy in round 2, etc.
- `round_number_increments` — round_number goes 1, 2, 3...

- [ ] Write weight group distribution tests
- [ ] Write pool mechanics tests
- [ ] Write weight group cycling tests
- [ ] Write round state tests

---

### Step 10: Update `tests/combat_test.odin`

**Goal:** Existing combat tests adapted to new state machine.

**Remove:**
- `board_refills_when_empty` — no board
- `board_does_not_refill_when_pickable_dice_remain` — no board

**Update:**
- `game_starts_on_player_turn` → `game_starts_on_draft_player_pick` (first_pick=true in round 1)
- `cannot_pick_with_full_hand` → adapt to pool context
- `can_pick_with_space_in_hand` → adapt to pool context
- `play_again_resets_game_state` → verify pool and round state reset

**Add:**
- `draft_phase_alternates_picks` — player pick → enemy pick → player pick
- `draft_phase_ends_when_pool_empty` — transitions to combat phase
- `combat_turn_allows_free_assignment` — assignment doesn't advance phase
- `combat_pass_ends_round` — both sides pass → Round_End
- `round_end_generates_new_pool` — pool is fresh after round end

- [ ] Remove board refill tests
- [ ] Update existing tests for new Turn_Phase values
- [ ] Add draft phase tests
- [ ] Add round transition tests

---

### Step 11: Update `tests/ai_test.odin`

**Goal:** AI tests work with pool instead of board.

**Update:**
- `ai_picks_from_board` → `ai_picks_from_pool` — set up pool with known dice, verify AI picks
- `ai_cannot_pick_with_full_hand` → same logic, pool context
- `ai_rolls_skulls_when_stuck` — remove board-clearing setup, use empty pool instead

**Remove:**
- Any test that depends on `BOARD_SIZE`, `board.cells`, `cell_is_pickable`

- [ ] Rewrite board-dependent AI tests for pool
- [ ] Remove board-specific setup code

---

### Step 12: Update Design Docs

**Goal:** Docs reflect the new architecture.

- [ ] Delete `docs/codebase/board.md`
- [ ] Create `docs/codebase/pool.md` — module reference for `pool.odin`
- [ ] Update `docs/codebase/combat.md` — new state machine, phase handlers, round flow
- [ ] Update `docs/codebase/game.md` — new Game_State fields, pool drag-and-drop
- [ ] Update `docs/codebase/ai.md` — pool scanning, phase-aware AI
- [ ] Update `docs/codebase/types.md` — new types, removed types, changed enums
- [ ] Update `docs/codebase/config.md` — pool_size/skull_chance in encounter config
- [ ] Update `CLAUDE.md` project structure — pool.odin replaces board.odin, pool_test.odin replaces board_test.odin
- [ ] Update `docs/plans/implementation-plan.md` — mark milestone status

---

### Step 13: Verify and Clean Up

**Goal:** Everything compiles, all tests pass, no stale references.

- [ ] `odin build src/` — clean compilation
- [ ] `odin test tests/` — all tests pass
- [ ] `odin build sim/` — simulator compiles
- [ ] Run simulator: `./build/dicey-sim --rounds=100` — verify headless loop works
- [ ] Run game: `odin run src/` — play through a full draft→combat→draft cycle
- [ ] Grep for `board`, `Board`, `BOARD_SIZE` across entire codebase — no stale references
- [ ] Grep for `check_board_refill` — removed everywhere
- [ ] Verify all `docs/todo/` entries still reference live `// TODO` comments

---

## Execution Order

The steps above are designed to be executed **sequentially**. The dependency chain is:

```
Step 0 (prep)
  → Step 1 (types) — breaks compilation
    → Step 2 (pool.odin) — new module, compiles standalone
      → Step 3 (delete board.odin) — compilation fully broken
        → Step 4 (combat.odin) — fixes combat compilation
          → Step 5 (game.odin) — fixes game compilation
            → Step 6 (ai.odin) — fixes AI compilation
              → Step 7 (config.odin) — adds config support
                → Step 8 (sim/) — fixes simulator
                  → Step 9 (pool tests) — new tests
                    → Step 10 (combat tests) — updated tests
                      → Step 11 (ai tests) — updated tests
                        → Step 12 (docs) — documentation
                          → Step 13 (verify) — clean state
```

Steps 1–3 can be collapsed into a single commit if preferred (types + new module + delete old module). Steps 9–11 can be worked in parallel. Step 12 can be done alongside any code step.

**Estimated test count change:** ~18 board tests removed, ~14 pool tests added, ~4 combat tests removed/rewritten, ~5 combat tests added, ~3 AI tests rewritten. Net: roughly the same count, shifted from board to pool.

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| State machine complexity | New phases are individually simpler. Combat phase is nearly identical to current code — just without picks. Draft phase is a clean sub-loop. |
| Simulator's swap_sides trick breaks | Test the simulator early (Step 8). The trick depends on Turn_Phase values — update the phase remapping in `fix_player_turn_phase`. |
| AI draft behavior feels wrong | The AI's draft scoring is unchanged — it still scores dice by type match, denial, and scaling fit. The only change is scanning a flat array instead of a grid. |
| Hand overflow during draft | Free assignment and discard are available during draft picks. If hand is full, player can assign to a character or discard before picking. AI uses `ai_assign_from_hand` after each pick. |
| "Done rolling" detection | Consecutive-pass counter. Auto-pass when no characters have dice. Player gets explicit Pass button when they have dice but choose not to roll. |
| Condition tick timing | Per-side ticking at combat turn start, same semantic as current. Only tick once per round per side to preserve duration balance. |

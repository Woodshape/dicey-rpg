# Types — Shared Types & Constants

**File:** `src/types.odin`

Central type registry for the entire codebase. All shared types, enums, constants, and lookup tables live here. No logic — just definitions.

## Responsibilities

- Define all data structures used across multiple modules
- Establish enum values, sentinel zero values, and lookup tables
- Set layout constants for UI positioning

## Key Types

### Die_Type

```odin
Die_Type :: enum u8 { None, D4, D6, D8, D10, D12, Skull }
```

- `.None` is the sentinel zero value. Indicates no die present. Asserted against at entry points (`hand_add`, `character_assign_die`). Renders as magenta `"??"` to be visually obvious if it leaks.
- `.Skull` is exempt from the pure type constraint on characters.
- `die_type_is_normal()` returns true for D4–D12, false for None and Skull.

Lookup tables indexed by `Die_Type`:
- `DIE_TYPE_NAMES` — display names (cstring)
- `DIE_TYPE_COLORS` — bright colors for perimeter/active dice
- `DIE_TYPE_COLORS_DIM` — dimmed colors for locked/unmatched dice
- `DIE_FACES` — face count per type (0 for None and Skull)

### Roll_Result

```odin
Roll_Result :: struct {
    values, skulls, matched, ...
    // Invariant: matched_count + unmatched_count + skull_count == count
}
```

Holds the full outcome of rolling a character's dice. Used by match detection, ability resolution, and UI display. The invariant is asserted in both `character_roll` and `detect_match`.

### Draft_Pool / Weight_Group / Round_State

```odin
Weight_Group :: enum u8 { Low, Mid_Low, Mid_High, High }

Draft_Pool :: struct {
    dice:         [MAX_POOL_SIZE]Die_Type,
    count:        int,  // total dice generated this round
    remaining:    int,  // dice not yet picked
    weight_group: Weight_Group,
    skull_chance: int,
}

Round_State :: struct {
    group_order:  [WEIGHT_GROUP_COUNT]Weight_Group,
    cycle_index:  int,
    round_number: int,
    first_pick:   bool,
    pool_size:    int,
    skull_chance: int,
}
```

- `Draft_Pool` holds the current round's available dice. `count` is the total generated; `remaining` tracks how many are left to pick.
- `Weight_Group` controls the die type distribution for a round: `Low` biases toward d4/d6, up to `High` which biases toward d10/d12.
- `Round_State` manages the cycling of weight groups across rounds. `group_order` is a shuffled cycle of all four groups; `cycle_index` tracks position within it. `round_number` is 1-based and increments each draft round. `first_pick` alternates who picks first. `pool_size` and `skull_chance` are configurable per session.

### Hand

Fixed-size array (`[MAX_HAND_SIZE]Die_Type`) with a `count` field. The count/array pattern is used throughout the codebase.

### Character / Party

Character holds state, stats, assigned dice, roll results, and abilities. Party is a fixed-size array of characters with a count.

### Character_State

```odin
Character_State :: enum u8 { Empty, Alive, Dead }
```

- `.Empty` is the sentinel zero value — a zero-initialized Character is `.Empty` by default.
- Do not conflate with `Character_Rarity`. A dead Common character is still Common.

### Turn_Phase

```odin
Turn_Phase :: enum u8 {
    // Draft phase
    Draft_Player_Pick,   // player picks one die from pool (free assign/discard allowed)
    Draft_Enemy_Pick,    // AI picks one die from pool
    // Combat phase
    Combat_Player_Turn,  // player assigns freely, rolls one character or passes
    Player_Roll_Result,  // timed display of roll results
    Combat_Enemy_Turn,   // AI assigns, rolls one character or passes
    Enemy_Roll_Result,   // timed display of roll results
    // Round boundary
    Round_End,           // check win/lose, advance to next draft round
    // Terminal
    Victory,
    Defeat,
}
```

Drives the combat state machine in `combat.odin`. Each round begins with a draft phase (`Draft_Player_Pick` / `Draft_Enemy_Pick`) where both sides alternate picking from the pool, then transitions into the combat phase (`Combat_Player_Turn` through `Enemy_Roll_Result`). `Round_End` handles win/lose checks and advances to the next round.

### Ability / Ability_Scaling

- `Ability_Effect` is a procedure pointer: `proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result)`
- `Ability_Describe` returns a formatted cstring for UI display (temporary, valid for one frame).
- `Ability_Scaling` has `.None` as its first (zero) value for flat effects that ignore roll data, followed by `.Match`, `.Value`, and `.Hybrid`.
- `Ability` struct: `name`, `scaling`, `min_matches`, `min_value` (minimum [VALUE] to trigger), `effect`, `description` (renamed from `static_describe`).
- `Ability_Describe` has the full signature: `proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring`.

### Condition_Kind / Condition_Expiry / Condition

```odin
Condition_Kind :: enum u8 { None, Shield, Hex }
Condition_Expiry :: enum u8 { None, Turns, On_Hit_Taken }
Condition :: struct {
    kind, value, expiry, remaining, interval, timer
}
```

- `.None` is the sentinel zero value for both enums.
- `Shield` absorbs incoming damage (value = remaining absorption pool). Removed when pool reaches 0.
- `Hex` reduces target DEF by `value`. Expires after `remaining` turns.
- `interval` / `timer` support periodic effects (e.g., future Poison/Regen). Currently unused.
- Characters hold `conditions: [MAX_CONDITIONS]Condition` and `condition_count: int`.
- Lookup table: `CONDITION_NAMES` — indexed by `Condition_Kind`, sentinel is `"??"`.

### Input_State

```odin
Input_State :: struct {
    mouse_x, mouse_y: i32,
    left_pressed:     bool,
    left_released:    bool,
    right_pressed:    bool,
    delta_time:       f32,
}
```

Collected once per frame in `game_update` from Raylib input functions, then passed to `combat_update` and phase handlers. This decouples combat logic from direct Raylib calls.

### Drag_State

Tracks the current drag-and-drop operation. `Drag_Source` enum indicates where the drag started (Pool, Hand, Character).

```odin
Drag_Source :: enum { None, Pool, Hand, Character }

Drag_State :: struct {
    active:     bool,
    source:     Drag_Source,
    die_type:   Die_Type,
    pool_index: int, // index into draft pool (for Pool source)
    index:      int, // hand slot index or character die index
    char_index: int, // which character in the party (for Character source)
}
```

- `.None` is the sentinel zero value — not dragging.
- `pool_index` identifies which die in the draft pool is being dragged (used to ghost the source slot).
- `index` and `char_index` serve Hand and Character drag sources respectively.

### Combat_Log / Log_Entry

Ring buffer for combat messages. Fixed-size entries with inline text buffers — no heap allocation.

## Constants

| Constant | Value | Used by |
|----------|-------|---------|
| `MAX_POOL_SIZE` | 12 | Draft pool array upper bound |
| `DEFAULT_POOL_SIZE` | 6 | Default dice per draft round |
| `POOL_CELL_SIZE` / `POOL_CELL_GAP` | 64 / 6 | Pool die rendering |
| `WEIGHT_GROUP_COUNT` | 4 | Number of weight groups in a cycle |
| `MAX_HAND_SIZE` | 5 | Hand capacity |
| `MAX_CHARACTER_DICE` | 6 | Legendary max dice (array sizes) |
| `MAX_PARTY_SIZE` | 4 | Party array size |
| `SKULL_CHANCE` | 10 | % chance per pool die becomes skull |
| `MAX_CONDITIONS` | 4 | Max active conditions per character |
| `MAX_DIE_VALUE` | 12 | Frequency array size for match detection |

## Best Practices

- All enums that appear in fixed-size arrays with a count MUST have a sentinel zero value (`.None`, `.Empty`).
- Sentinel values in lookup tables should use obviously wrong values (magenta, `"??"`) so bugs are visible immediately.
- Layout constants (pixel positions, sizes) live here, not scattered across modules.
- When adding a new `Die_Type` value, update ALL lookup tables (`DIE_TYPE_NAMES`, `DIE_TYPE_COLORS`, `DIE_TYPE_COLORS_DIM`, `DIE_FACES`).

## What NOT to Do

- Do not put logic in `types.odin` — only type definitions, constants, and simple predicate procs like `die_type_is_normal`.
- Do not use game-meaningful enum values as sentinels. Slot state (Empty/Alive/Dead) is separate from character properties (Rarity).
- Do not hardcode `DEFAULT_POOL_SIZE`, `MAX_HAND_SIZE`, or `RARITY_MAX_DICE` values in test code — always reference the constant.

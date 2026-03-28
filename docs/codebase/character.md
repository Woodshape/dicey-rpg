# Character — Stats, Assignment & UI

**File:** `src/character.odin`
**Types:** `Character`, `Character_State`, `Character_Rarity`, `Character_Stats`, `Party` (defined in `types.odin`)
**Tests:** `tests/character_test.odin`

## Responsibilities

- Create characters with name, rarity, and stats
- Manage dice assignment with the pure type constraint
- Apply skull dice damage (per-hit loop)
- Track assigned die type for constraint checking
- Provide screen positions and hit-testing for character panels and die slots
- Draw character panels with assigned/rolled dice, stats, and ability results

## Architecture

### Pure Type Constraint

A character can hold only one normal die type at a time. All assigned normal dice must be the same type (e.g., all d4 or all d8). Skull dice are exempt — they can be assigned alongside any normal type.

The constraint is enforced in `character_can_assign_die`:
1. If the die is `.Skull` → always accepted (up to slot limit)
2. If no normal dice are assigned → any normal type accepted
3. If a normal type is already committed → only that same type accepted

`character_assigned_normal_die_type` scans assigned dice to find the committed normal type (skipping skulls). This is the source of truth for the constraint.

### Skull Damage — Per-Hit Loop

`apply_skull_damage(attacker, target)` applies `skull_count` individual attacks. Each hit:
1. Computes raw damage: `max(Attack - character_effective_defense(target), 0)` — uses effective DEF which accounts for Hex debuffs
2. Subtracts Shield absorption: `condition_absorb_damage(target, dmg)` — Shield pool absorbs up to `dmg`, removed when depleted
3. Applies remaining damage to target HP

The loop processes each skull die as a discrete hit, enabling per-hit condition interactions (Shield breaks mid-volley, Hex stacks compound, etc.). Returns total damage dealt after all reductions.

### Dice Slot Pattern

Characters use the same fixed-size array + count pattern as hands:
```odin
assigned:       [MAX_CHARACTER_DICE]Die_Type
assigned_count: int
```

`MAX_CHARACTER_DICE` (6) accommodates the largest rarity (Legendary). The character's actual slot limit is `max_dice`, set from `RARITY_MAX_DICE[rarity]` at creation.

### UI Layout

Character panels are stacked vertically. Player panels start at `CHAR_PANEL_X` (left side), enemy panels at `ENEMY_PANEL_X` (right side). Each panel shows name, rarity, stats (HP/ATK/DEF/RSV), die slots, and a Roll button (player side only).

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `character_create(name, rarity, stats)` | Create a character in `.Alive` state |
| `character_is_alive(character)` | True if state is `.Alive` |
| `character_can_assign_die(character, die_type)` | Validates pure type constraint + capacity |
| `character_assign_die(character, die_type)` | Assign a die. Asserts not `.None`. |
| `character_unassign_die(character, index)` | Remove by index, shift left, clear vacated |
| `character_assigned_normal_die_type(character)` | Find committed normal type, if any |
| `apply_skull_damage(attacker, target)` | Per-hit skull damage loop |
| `char_panel_y(char_index)` | Y position for the Nth character panel |
| `panel_slot_position(panel_x, panel_y, slot_index)` | Pixel position of a die slot |
| `mouse_to_party_char_slot(party, panel_x, mx, my)` | Hit-test across all party characters |
| `mouse_on_party_roll_button(party, panel_x, mx, my)` | Hit-test roll buttons |
| `character_draw_at(character, px, py, drag, interactive, name_color)` | Draw one character panel |
| `party_draw(party, panel_x, drag, interactive, name_color)` | Draw all characters in a party |

## How to Use

```odin
// Create a character
ch := character_create("Warrior", .Common, Character_Stats{hp=20, attack=3, defense=1})

// Assign dice (validates constraint)
if character_can_assign_die(&ch, .D6) {
    character_assign_die(&ch, .D6)
}

// Unassign back to hand
die_type, ok := character_unassign_die(&ch, 0)
if ok { hand_add(&hand, die_type) }
```

## Best Practices

- Always check `character_can_assign_die` before assigning. `character_assign_die` asserts validity internally.
- Never assign `Die_Type.None` — it will assert-fail.
- Use `character_assigned_normal_die_type` to check the committed type, not manual iteration.
- After `character_unassign_die`, the vacated slot is zeroed. Test this invariant with non-zero enum values to catch stale data.
- Abilities and resolve are set directly on the Character struct after creation (see `ability.odin` templates).

## What NOT to Do

- Do not check `character.assigned_count` against `MAX_CHARACTER_DICE` — check against `character.max_dice` which respects rarity.
- Do not check character liveness with `character.stats.hp > 0` — use `character_is_alive(character)` which checks `state == .Alive`. The `.Dead` state is set by `resolve_roll` in `combat.odin` when HP hits 0; it is the source of truth.
- Do not modify `assigned` or `assigned_count` directly. Use `character_assign_die` / `character_unassign_die` which maintain array invariants.
- Do not assume `character_unassign_die` returns `.None` on failure — check the `bool`.

## Test Coverage

`tests/character_test.odin` — 10 tests:

**State:** `empty_character_slot_is_inactive`, `created_character_is_active`

**Assignment:** `character_assign_first_die_any_type`, `character_assign_same_type`, `character_rejects_mixed_type`, `character_respects_rarity_max`

**Unassignment:** `character_unassign_returns_die`, `character_unassign_clears_vacated_slots`, `character_accepts_new_type_after_clearing`

**Type tracking:** `character_assigned_type_tracks_correctly`

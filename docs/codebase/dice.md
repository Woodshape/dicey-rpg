# Dice — Rolling & Match Detection

**File:** `src/dice.odin`
**Types:** `Roll_Result`, `Die_Type` (defined in `types.odin`)
**Tests:** `tests/dice_test.odin`

## Responsibilities

- Roll individual dice (`roll_die`)
- Roll all assigned dice on a character, separating skulls from normals (`character_roll`)
- Detect match patterns from rolled values as a pure function (`detect_match`)
- Clear roll state after resolution (`character_clear_roll`)

## Architecture

### Two-Axis Resolution

The match detection system produces two numbers that feed directly into ability formulas:

- **[MATCHES]** (`matched_count`): Count of all dice whose rolled value appears at least twice. Multiple match groups are additive — two pairs gives [MATCHES]=4.
- **[VALUE]** (`matched_value`): Face value of the best match group (highest frequency, tie-broken by higher value).

There are no named pattern tiers (Pair, Full House, etc.). Abilities use [MATCHES] and [VALUE] directly.

### detect_match — Pure Function

`detect_match(values: []int) -> Roll_Result` is the core algorithm:

1. Count frequency of each value (1–12) using a fixed array
2. Find the best group: highest frequency, tie-break by higher value → sets `matched_value`
3. Mark every die whose value has frequency >= 2 as matched
4. Count matched and unmatched dice
5. Assert invariant: `matched_count + unmatched_count == count`

This function receives ONLY normal dice values (no skulls). It has no side effects and no randomness — fully testable.

### character_roll — Side-Effectful Wrapper

`character_roll(character)` orchestrates a full roll:

1. Iterate assigned dice, separating skulls (into `result.skulls`) from normals
2. Roll each normal die via `roll_die`
3. Call `detect_match` on the normal values only
4. Map matched flags back to the full array (skipping skull slots)
5. Assert: `matched_count + unmatched_count + skull_count == count`
6. Store result on `character.roll`, set `character.has_rolled = true`

### character_clear_roll

Called after roll results have been displayed and resolved. Resets roll state, clears assigned dice (consumed), and clears `ability_fired` / `resolve_fired` flags.

## Key Procedures

| Procedure | Pure? | Purpose |
|-----------|-------|---------|
| `roll_die(die_type)` | No (RNG) | Roll a single normal die, returns 1–faces |
| `detect_match(values)` | Yes | Core match detection algorithm |
| `character_roll(character)` | No (RNG + mutation) | Full roll with skull separation |
| `character_clear_roll(character)` | No (mutation) | Reset roll state, consume dice |

## How to Use

```odin
// Roll a character's assigned dice
character_roll(&character)

// Read results
roll := &character.roll
if roll.matched_count >= 2 {
    // Ability fires with [MATCHES] and [VALUE]
}

// After resolution and display
character_clear_roll(&character)
```

## Best Practices

- Never call `detect_match` with skull dice in the input — filter them out first (as `character_roll` does).
- Always check `character.has_rolled` before reading `character.roll`.
- The `Roll_Result` invariant (`matched + unmatched + skulls == count`) must hold after every roll. Both `detect_match` and `character_roll` assert this.
- Use `detect_match` directly for testing match logic — it's pure and takes a simple slice.

## What NOT to Do

- Do not call `roll_die` on `.Skull` or `.None` — it asserts `die_type_is_normal`.
- Do not read `character.roll` after `character_clear_roll` — it's zeroed.
- Do not assume `matched_value` is 0 when there are no matches. When no die has frequency >= 2, the best group is a frequency-1 value (the highest), and `matched_count` is 0 with `matched_value` set to that highest value. Abilities gate on `matched_count >= min_matches`, not on `matched_value`.

## Test Coverage

`tests/dice_test.odin` — 27 tests:

**Match patterns:** `match_no_match`, `match_pair`, `match_pair_highest_value_wins`, `match_two_pairs_gives_four_matches`, `match_triple`, `match_triple_plus_pair_gives_five_matches`, `match_four_of_a_kind`, `match_five_of_a_kind`

**Edge cases:** `match_minimum_hand_pair`, `match_minimum_hand_triple`, `match_minimum_hand_no_match`, `match_six_dice_all_same`, `match_six_dice_double_triple`, `match_six_dice_three_pairs`

**Axis values:** `match_value_higher_value_wins_tie`, `match_all_unmatched_feeds_resolve`, `match_all_matched_zero_unmatched`

**Roll lifecycle:** `roll_result_cleared_properly`

**Skull integration:** `skull_exempt_from_pure_type`, `skull_only_hand_is_valid`, `skull_does_not_set_normal_type`, `skull_mixed_type_rejected`, `skull_roll_mixed`, `skull_roll_all_skulls`, `skull_damage_calculation`, `skull_damage_respects_defense`, `skull_damage_cannot_go_below_zero_hp`

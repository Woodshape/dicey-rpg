# Ability — Effects, Resolution & Templates

**File:** `src/ability.odin`
**Types:** `Ability`, `Ability_Scaling`, `Ability_Effect`, `Ability_Describe` (defined in `types.odin`)
**Tests:** `tests/ability_test.odin`

## Responsibilities

- Define ability effect procedures (the actual game logic)
- Define ability description procedures (UI display strings)
- Resolve abilities after a roll (main ability + resolve meter + resolve ability)

Character templates (e.g., `warrior_create`) have been removed. Characters are now loaded from `data/characters/*.cfg` via `config_load_character()` in `config.odin`. Effect and describe procs remain in `ability.odin`; lookup tables that map ability names to procs (`ABILITY_EFFECTS`, `ABILITY_DESCRIPTIONS`, `RESOLVE_EFFECTS`, `RESOLVE_DESCRIPTIONS`) live in `config.odin`.

## Architecture

### Ability Struct

```odin
Ability :: struct {
    name:        cstring,
    scaling:     Ability_Scaling,   // .None, .Match, .Value, or .Hybrid
    min_matches: int,               // minimum [MATCHES] to trigger
    min_value:   int,               // minimum [VALUE] to trigger
    effect:      Ability_Effect,    // proc pointer — the game logic
    description: Ability_Describe,  // proc pointer — UI string (renamed from static_describe)
}
```

Each character has exactly 3 ability slots:
1. **`ability`** — main active, fires on roll if `matched_count >= min_matches`
2. **`resolve_ability`** — fires when resolve meter reaches `resolve_max`
3. **`passive`** — always active, no roll trigger (placeholder, not yet wired)

### Effect Procedure Signature

```odin
Ability_Effect :: #type proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result)
```

The full `Game_State` is passed for maximum flexibility. Abilities can read or modify:
- Both parties (AoE damage, party-wide heals)
- Both hands (steal, destroy, corrupt)
- The draft pool (manipulate available dice)
- The combat log

The `attacker` and `target` are convenience pointers for the common case. `roll` provides [MATCHES] and [VALUE] for scaling.

### Side-Agnostic Party Lookup

Abilities that affect the attacker's allies (e.g., party-wide heals) must **not** hardcode `gs.player_party` or `gs.enemy_party`. Use `attacker_party(gs, attacker)` to find the correct party at runtime — this works correctly when the simulator swaps parties for AI-driven player turns.

```odin
attacker_party :: proc(gs: ^Game_State, attacker: ^Character) -> ^Party
```

### Scaling Axes

| Axis | Formula Pattern | Best Die Type |
|------|----------------|---------------|
| `.Match` | Scales with `roll.matched_count` | d4/d6 (high match rate) |
| `.Value` | Scales with `roll.matched_value` | d10/d12 (high face values) |
| `.Hybrid` | Uses both axes (e.g., `matched_count * matched_value`) | d6/d8 (balanced) |

### Enhanced Mode

Each ability can have an **enhanced mode** that activates when `[VALUE] >= value_threshold`. The threshold is configured per-ability in `.cfg` files (`value_threshold` field, default 0 = no enhanced mode). The behavior change is unique to each ability — it's code in the proc, not a generic bonus.

Check: `ability_is_enhanced(&ability, matched_value)` in `dice.odin`.

| Ability | Normal | Enhanced ([V] >= threshold) |
|---------|--------|---------------------------|
| Flurry | [V] dmg × [M] hits, reduced by DEF | Same but **ignores DEF** (PIERCING) |
| Fireball | [M] × [V] dmg, reduced by DEF | Same but **ignores DEF** (PIERCING) |
| Smite | [V] dmg, reduced by DEF | Same but **ignores DEF** (PIERCING) |
| Heal | Restore [V] HP to self | Also heals **lowest-HP ally** (PARTY HEAL) |
| Shield | Shield lowest-HP ally for [V] | Shields **all alive allies** (PARTY SHIELD) |
| Hex | -1 DEF for 3 turns | **-2 DEF** for 3 turns (DEEP HEX) |

Describe procs append a keyword tag when enhanced (e.g. `"9 dmg x 3 hits (PIERCING)"`).

Only reachable by d8+ dice (threshold=8 default). d4 (max [V]=4) and d6 (max [V]=6) can never trigger enhanced mode. This is the primary mechanical reward for drafting big dice.

### Resolution Pipeline

The resolution pipeline is inlined directly in `resolve_roll` in `combat.odin` (not a separate proc). Steps, in order:

1. **Main ability:** if `matched_count >= min_matches` and `effect != nil` → snapshot target HP, call effect, set `ability_fired = true`, write `ABILITY` trace line with HP delta
2. **Charge resolve:** add `unmatched_count` to `attacker.resolve`, write `CHARGE` trace line
3. **Resolve ability:** if `resolve >= resolve_max` and `effect != nil` → snapshot HP, call effect, set `resolve_fired = true`, reset `resolve = 0`, write `RESOLVE` trace line

The order matters: the main ability fires first (it may change game state), then resolve charges, then the resolve ability fires if the threshold is met (even from this roll's charge).

### Describe Procedures

```odin
Ability_Describe :: #type proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring
```

Takes the same parameters as `Ability_Effect` but returns a formatted cstring. Uses `fmt.ctprintf` — the returned string is temporary, valid for one frame only. Used by character UI to show ability tooltips and post-roll results.

## Current Abilities

### Effect Procedures

| Ability | Scaling | Formula |
|---------|---------|---------|
| Flurry | Hybrid | Deal [VALUE] damage [MATCHES] times. Each hit reduced by target DEF. |
| Smite | Value | Deal [VALUE] damage, reduced by target DEF. |
| Fireball | Hybrid | Deal [MATCHES] × [VALUE] damage, reduced by target DEF. |
| Heal | Value | Restore [VALUE] HP to self. No DEF interaction. |
| Shield | Value | Apply Shield to lowest-HP ally. Shield absorbs [VALUE] total damage, then expires. |
| Hex | None | Reduce target DEF by 1 for 3 turns. Fires on min_matches = 2. |
| Resolve: Warrior | — | Deal 10 flat damage ignoring defense. |
| Resolve: Goblin Explosion | — | Deal 6 damage to all enemies. Respects DEF and Shield. |
| Resolve: Shadow Bolt | — | Deal 15 damage ignoring defense. Single target, respects Shield. |

## Passive Abilities

Passives are always-on effects that fire at specific trigger points. Each character has one `Passive` (defined in `.cfg` files, wired via `PASSIVE_EFFECTS` lookup table in `config.odin`).

### Trigger Model

| Trigger | Call Site | When |
|---------|-----------|------|
| `On_Roll` | `fire_on_roll_passive` in `resolve_roll` | Before skull/ability damage, every roll |
| `On_Ally_Damaged` | `notify_ally_damaged` in `resolve_roll` | After any damage to an ally (skull or ability) |

### Current Passives

| Passive | Character | Trigger | Effect |
|---------|-----------|---------|--------|
| Tenacity | Warrior | On_Roll | Heal 1 HP on miss (no match, has normal dice). |
| Empathy | Healer | On_Ally_Damaged | +1 resolve when an ally takes damage. Caps at resolve_max. |
| Scavenger | Goblin | On_Roll | Deal 2 flat damage (ignores DEF) on a miss (matched_count == 0, has normal dice). |
| Curse Weaver | Shaman | On_Roll | Deal 1 damage per active condition on target (ignores DEF). |

### How to Add a New Passive

1. **Write the effect procedure** in `ability.odin` with `Passive_Effect` signature.
2. **Register in `PASSIVE_EFFECTS`** in `config.odin` with `(name, trigger, proc)`.
3. **Set in `.cfg` file**: `[passive]` section with `name`, `effect`, `description`.
4. **Write tests** in `tests/passive_test.odin`.

## How to Add a New Ability

1. **Write the effect procedure** in `ability.odin`:
   ```odin
   ability_my_effect :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) {
       dmg := max(roll.matched_value * 2 - target.stats.defense, 0)
       target.stats.hp = max(target.stats.hp - dmg, 0)
   }
   ```

2. **Write the describe procedure** in `ability.odin`:
   ```odin
   describe_my_effect :: proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring {
       return fmt.ctprintf("%d dmg", roll.matched_value * 2)
   }
   ```

3. **Register in lookup tables** in `config.odin`:
   - Add to `ABILITY_EFFECTS` map: `"my_effect" = ability_my_effect`
   - Add to `ABILITY_DESCRIPTIONS` map: `"my_effect" = describe_my_effect`
   - (Or `RESOLVE_EFFECTS` / `RESOLVE_DESCRIPTIONS` for resolve abilities)

4. **Create or edit a `.cfg` file** in `data/characters/` that references the ability by name.

5. **Write tests** in `tests/ability_test.odin` — test the effect procedure directly with crafted `Roll_Result` values.

## Best Practices

- Ability effects should always clamp damage to 0 (`max(dmg, 0)`) and HP to 0 (`max(hp - dmg, 0)`).
- Healing has no cap (HP is a flat value with no maximum). This is by design.
- Use `fmt.ctprintf` in describe procs. The returned cstring is only valid for one frame — do not store it.
- The `min_matches` threshold should be at least 2 for main abilities (a match requires frequency >= 2).
- Set `min_matches = 0` for resolve abilities — they trigger on meter threshold, not match count.

## What NOT to Do

- Do not extract the resolution pipeline out of `resolve_roll` into a separate proc without also moving the intermediate HP snapshot logic and trace calls — they are coupled.
- Do not read `attacker.roll` inside an effect proc — use the `roll` parameter instead. They point to the same data, but using the parameter makes the contract explicit.
- Do not assume `target` is non-nil. In `resolve_abilities`, the target is checked before calling, but future changes should be defensive.
- Do not add new abilities without a corresponding describe procedure. The UI expects it.

## Test Coverage

`tests/ability_test.odin` — 12 tests:

**Effects:** `flurry_deals_one_per_match`, `flurry_respects_defense`, `smite_deals_value_damage`, `fireball_deals_matches_times_value`, `heal_restores_value_hp`

**Resolution:** `resolve_fires_ability_when_threshold_met`, `resolve_skips_ability_when_threshold_not_met`, `resolve_zero_matches_skips_ability`

**Resolve meter:** `resolve_charges_from_unmatched`, `resolve_accumulates_across_rolls`, `resolve_triggers_at_threshold`, `resolve_does_not_trigger_below_threshold`

`tests/passive_test.odin` — 15 tests:

**Tenacity:** `tenacity_heals_on_miss`, `tenacity_does_not_heal_on_match`, `tenacity_does_not_heal_on_skulls_only`

**Empathy:** `empathy_charges_resolve_on_ally_damage`, `empathy_does_not_charge_for_self_damage`, `empathy_does_not_exceed_resolve_max`

**Scavenger:** `scavenger_deals_damage_on_miss`, `scavenger_does_not_fire_on_match`, `scavenger_does_not_fire_on_skulls_only`

**Curse Weaver:** `curse_weaver_deals_damage_per_condition`, `curse_weaver_no_damage_without_conditions`

**Integration:** `fire_on_roll_passive_sets_fired_flag`, `fire_on_roll_passive_skips_non_roll_trigger`, `passive_loads_from_config`, `passive_empathy_loads_correct_trigger`

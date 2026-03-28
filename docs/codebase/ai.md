# AI — Enemy Decision-Making

**File:** `src/ai.odin`
**Tests:** `tests/ai_test.odin`

## Responsibilities

- Execute enemy actions during both draft and combat phases
- Assign compatible dice from enemy hand to enemy characters (free action)
- Score pool dice for optimal picks (type matching, denial, skull value)
- Decide when to roll vs wait for more picks
- Discard unusable dice when deadlocked

## Architecture

### Draft Phase — `ai_draft_pick`

`ai_draft_pick(gs)` is called during `Draft_Enemy_Pick`. It executes one pick per call:

```
1. Assign any compatible dice from hand to characters (free)
2. Find the best die in the pool via ai_pick_best_pool_die
3. If found → remove from pool, add to hand, assign from hand, log the action
4. If not found and hand is full → discard least useful die, then pick index 0 as fallback
5. If not found and pool is empty → advance to combat phase
6. Advance phase: pool empty → Combat_Player_Turn or Combat_Enemy_Turn (based on first_pick);
   otherwise → Draft_Player_Pick
```

### Combat Phase — `ai_combat_turn`

`ai_combat_turn(gs)` is called during `Combat_Enemy_Turn`. Each side rolls ALL of its characters before the other side goes. When nothing remains to roll, the round ends:

```
1. Assign any compatible dice from hand to characters (free)
2. If any character should roll → roll it, resolve, advance to Enemy_Roll_Result
3. If hand is full and no die is usable → discard the least useful die
4. If nothing left to roll → advance to Round_End
```

There is no per-die pick step in the combat phase. All picking happened during the draft.

### Assignment from Hand

`ai_assign_from_hand(gs)` iterates the enemy hand in reverse (so removal indices stay valid) and assigns each die to the best available character. Scoring prefers:
- Characters with more room (fewer assigned dice, scaled by 10)
- Characters whose committed type matches the die (+20 bonus)
- Characters whose ability scaling fits the die type (+`ai_scaling_fit * 2` bonus)

### Roll Decision

`ai_should_roll(gs)` returns `(should_roll, char_index)`. Two tiers, evaluated per character:
1. **>= 2 normal dice** → roll (character has enough real dice to act)
2. **Full (at max_dice) with any dice** → roll (skull damage is better than waiting)

Never rolls characters with 0 assigned dice. The full-character check ensures the AI never deadlocks when every die it holds is a skull: a full character rolls regardless.

### Die Scoring

`ai_score_die_for_party(die_type, enemy_party, player_types)` evaluates a pool die:

| Factor | Bonus | Rationale |
|--------|-------|-----------|
| Base score | +1 | Every valid die has a floor |
| Skull die | +2 | Universally useful for damage |
| Matches committed type | +10 | Strong pull toward consistency |
| No type committed yet | +3 | Good to start building |
| Denial (player wants this type) | +4 | Denying opponent's build |
| Scaling fit (`ai_scaling_fit`) | +0–5 | Die type matches character's ability scaling axis |
| No character can accept | 0 (skip) | Prevents hand clogging |

The critical behavior: dice that NO alive character can accept score 0 and are never picked. This prevents the AI from filling its hand with useless dice.

### Discard Logic

`ai_pick_discard(party, hand)` selects the least useful die to discard when deadlocked:
- Scores each die: +10 if any alive character can accept it
- Discards the die with the lowest score (least useful)
- Respects `hand_can_discard` for future status effect blocking

### Scaling Fit

`ai_scaling_fit(scaling, die_type)` scores how well a die type serves a character's ability scaling axis (0–5):

| Scaling | Best dice | Mid | Worst |
|---------|-----------|-----|-------|
| `.Match` | d4 (5), d6 (3) | d8 (1) | d10, d12 (0) |
| `.Value` | d12 (5), d10 (3) | d8 (1) | d4, d6 (0) |
| `.Hybrid` | d6/d8 (4) | d4/d10 (2) | d12 (1) |
| `.None` | all (0) | — | — |

Used by both `ai_score_die_for_party` (direct add) and `ai_assign_from_hand` (×2 weight).

### Legacy Scorer

`ai_score_die` (the standalone version) remains for backward compatibility with tests that call it directly. The party-based scorer (`ai_score_die_for_party`) is used by the actual AI.

## Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `ai_draft_pick(gs)` | Draft phase entry point — pick one die from pool, advance phase |
| `ai_combat_turn(gs)` | Combat phase entry point — roll characters, advance to Round_End |
| `ai_assign_from_hand(gs)` | Assign compatible hand dice to characters |
| `ai_should_roll(gs)` | Decide whether to roll and which character |
| `ai_pick_best_pool_die(gs)` | Find highest-scoring die in pool; returns `(index, bool)` |
| `ai_score_die_for_party(die_type, party, player_types)` | Score a die against all characters |
| `ai_scaling_fit(scaling, die_type)` | Score die fit for ability scaling axis (0–5) |
| `ai_score_die(die_type, enemy_type, ...)` | Legacy single-character scorer |
| `ai_hand_has_usable_die(party, hand)` | Any die in hand assignable? |
| `ai_pick_discard(party, hand)` | Select least useful die to discard |

## How to Use

The AI has two entry points, one per game phase:

- `ai_draft_pick(gs)` is called from `combat.odin` during `Draft_Enemy_Pick`.
- `ai_combat_turn(gs)` is called from `combat.odin` during `Combat_Enemy_Turn`.

Both read and mutate `gs` directly — pool or hand, enemy party, combat log, and turn phase.

## Best Practices

- All pool dice are valid candidates for picking — there is no `ai_pick_any_die` fallback because `ai_pick_best_pool_die` already scans the entire flat pool array.
- Assignment happens at the start of every draft pick AND combat turn AND after every successful pick. This maximises the chance of clearing hand space.
- Denial scoring uses the player's committed types gathered at the start of `ai_pick_best_pool_die`. The AI denies what the player is already building.
- The "no character can accept" check (returning score 0) is the key guard against hand clogging.
- The full-character roll check ensures the AI never stalls when holding only skull dice and a character is at capacity.

## What NOT to Do

- Do not call `ai_draft_pick` outside of the `Draft_Enemy_Pick` phase, or `ai_combat_turn` outside of `Combat_Enemy_Turn`. Both mutate game state and advance the turn phase.
- Do not assume the AI will always pick during the draft. If the hand is full it discards first; if the pool is empty it transitions phases.
- Do not score dice without checking `character_can_assign_die` first — a die that can't be assigned has no value.

## Known Issues

See `docs/issues/ai.md`:
- **Type commitment:** The AI doesn't track which die type it has strategically committed to per character across turns. It picks greedily per turn, which can waste actions on incompatible types. Partially mitigated by `ai_scaling_fit` steering picks toward appropriate dice.
- **Ability awareness:** Now partially addressed — `ai_scaling_fit` scores dice by how well they serve the character's scaling axis. A [VALUE]-scaling character scores d10/d12 higher; a [MATCHES]-scaling character scores d4/d6 higher. However, the AI still doesn't plan multi-turn strategies around specific abilities.

## Test Coverage

`tests/ai_test.odin` — 16 tests:

**Scoring:** `ai_prefers_matching_type`, `ai_scores_skull_dice_highly`, `ai_considers_denial`

**Scaling fit:** `ai_scaling_fit_match_prefers_small`, `ai_scaling_fit_value_prefers_big`, `ai_scaling_fit_hybrid_prefers_mid`

**Assignment:** `ai_assigns_compatible_from_hand`, `ai_does_not_assign_incompatible`

**Roll decision:** `ai_rolls_when_character_full`, `ai_does_not_roll_empty_character`, `ai_does_not_roll_with_only_skulls`, `ai_rolls_with_normal_dice`, `ai_does_not_roll_full_with_only_skulls`, `ai_rolls_skulls_when_stuck`

**Pick:** `ai_picks_from_pool`, `ai_cannot_pick_with_full_hand`

Notes on specific tests:
- `ai_does_not_roll_full_with_only_skulls` — despite its name, expects `true`. A character full of skulls rolls (skull damage > deadlock). The name reflects the old board-era behavior; the assertion was updated when the rule changed.
- `ai_picks_from_pool` — replaced `ai_picks_from_board`. Calls `ai_pick_best_pool_die` and checks the returned index is within `gs.pool.remaining`.
- `ai_cannot_pick_with_full_hand` — calls `ai_pick_best_pool_die` and expects `found == false`.

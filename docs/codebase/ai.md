# AI — Enemy Decision-Making

**File:** `src/ai.odin`
**Tests:** `tests/ai_test.odin`

## Responsibilities

- Execute one action per enemy turn (pick, roll, or skip)
- Assign compatible dice from enemy hand to enemy characters (free action)
- Score board dice for optimal picks (type matching, denial, skull value)
- Decide when to roll vs continue picking
- Discard unusable dice when deadlocked

## Architecture

### Turn Flow

`ai_take_turn(gs)` is the single entry point, called by `enemy_turn_update` in `combat.odin`. It executes exactly one action per call:

```
1. Assign any compatible dice from hand to characters (free)
2. If a character should roll → roll, resolve, advance to Enemy_Roll_Result
3. If a good die exists on the board → pick it, assign from hand again, advance to Player_Turn
4. If no good die but hand isn't full → pick any die (prevents skipping)
5. If hand is full and deadlocked → discard the least useful die
6. Otherwise → skip turn
```

### Assignment from Hand

`ai_assign_from_hand(gs)` iterates the enemy hand in reverse (so removal indices stay valid) and assigns each die to the best available character. Scoring prefers:
- Characters with more room (fewer assigned dice, scaled by 10)
- Characters whose committed type matches the die (+20 bonus)
- Characters whose ability scaling fits the die type (+`ai_scaling_fit * 2` bonus)

### Roll Decision

`ai_should_roll(gs)` returns `(should_roll, char_index)`. Three tiers, evaluated per character:
1. **Full + >= 2 normal** → roll (character is ready)
2. **>= 2 normal + no useful picks** → roll (nothing better to do)
3. **Full + no useful picks** → last-resort roll (even with < 2 normal dice or skulls-only; skull damage is better than deadlock)

Never rolls characters with 0 assigned dice. Tier 3 prevents infinite skipping when the board has no useful dice and the hand/characters are fully committed.

### Die Scoring

`ai_score_die_for_party(die_type, enemy_party, player_types)` evaluates a board die:

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
| `ai_take_turn(gs)` | Main entry point — one action per turn |
| `ai_assign_from_hand(gs)` | Assign compatible hand dice to characters |
| `ai_should_roll(gs)` | Decide whether to roll and which character |
| `ai_pick_best_die(gs)` | Find highest-scoring pickable die on board |
| `ai_score_die_for_party(die_type, party, player_types)` | Score a die against all characters |
| `ai_scaling_fit(scaling, die_type)` | Score die fit for ability scaling axis (0–5) |
| `ai_score_die(die_type, enemy_type, ...)` | Legacy single-character scorer |
| `ai_pick_any_die(gs)` | Fallback: pick first available die |
| `ai_hand_has_usable_die(party, hand)` | Any die in hand assignable? |
| `ai_pick_discard(party, hand)` | Select least useful die to discard |

## How to Use

The AI is invoked entirely through `ai_take_turn(gs)` during the `Enemy_Turn` phase. It reads and mutates `gs` directly — board, enemy hand, enemy party, combat log, and turn phase.

## Best Practices

- The AI always tries to act. The fallback chain (best pick → any pick → discard → skip) ensures it doesn't get stuck in an infinite loop.
- Assignment happens at the start of every turn AND after every pick. This maximizes the chance of clearing hand space.
- Denial scoring uses the player's committed types, gathered at the start of `ai_pick_best_die`. This means the AI denies what the player is building, not what they might build.
- The "no character can accept" check (returning 0) is the key guard against hand clogging.

## What NOT to Do

- Do not call `ai_take_turn` outside of `enemy_turn_update`. It mutates game state and advances the turn phase.
- Do not assume the AI will always pick. It may roll, discard, or skip depending on the board and hand state.
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

**Pick:** `ai_picks_from_board`, `ai_cannot_pick_with_full_hand`

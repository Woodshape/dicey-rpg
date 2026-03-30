# DEF Distribution and Hex

## Problem

Only the Warrior has DEF > 0 (DEF=1). This makes multiple systems vestigial:

- **Hex** reduces target DEF by 1 for 3 turns. Against 3/4 characters (DEF=0), it's a complete no-op — reduces 0 to 0.
- **Skull damage** passes through unmitigated against 3/4 characters.
- **Flurry's per-hit model** (multiple small hits vs one big hit) only matters when DEF exists to interact with.
- **Goblin Explosion's** DEF interaction is irrelevant most of the time.

The Shaman's main ability fires ~29% of the time and contributes nothing in 3 out of 4 matchups. Net effect: the Shaman is a 12 HP body with Shadow Bolt (resolve) as her only real contribution.

## Root Cause

DEF was added to the Warrior as a stat differentiation but never given to other characters. The damage reduction system exists in code but has almost no surface area in the game.

## Consequence

- Hex is the weakest ability in the game
- Curse Weaver passive (1 dmg per condition on target) rarely fires because the condition ecosystem is thin
- The damage reduction system might as well not exist
- Shaman is structurally the weakest character

## Fix

Give all characters non-zero DEF. This is a pure data change — modify `data/characters/*.cfg`. Suggested starting values:

| Character | Current DEF | Suggested DEF |
|-----------|------------|---------------|
| Warrior | 1 | 2 |
| Healer | 0 | 1 |
| Goblin | 0 | 1 |
| Shaman | 0 | 1 |

This makes Hex useful against every target, makes skull damage interact with DEF on every character, and gives the per-hit damage model (Flurry, skull loops) meaningful interplay with defense.

## Related

- `docs/issues/design/team-asymmetry.md` — Shaman's weakness contributes to the 80/20 win rate
- `docs/issues/design/passive-effectiveness.md` — Curse Weaver passive depends on conditions being meaningful

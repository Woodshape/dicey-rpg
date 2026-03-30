# Ability Fire Rate Differentiation

## Problem

All main abilities use `min_matches=2` and `min_value=0`. This means every character triggers at the same match probability threshold regardless of ability power. There's no differentiation — a devastating Fireball fires as easily as a weak Hex.

Post-AI-patience-fix fire rates are ~28% at Common, ~48% at Rare, etc. — identical across all characters at a given rarity.

## Design Question

Should stronger abilities require higher `min_matches` or `min_value`?

- `min_value` is already in the config schema and `Ability` struct but **not wired into the trigger check** in ability resolution.
- Wiring it in would enable abilities that only fire on high-face-value rolls (e.g. a d10/d12 build requiring [VALUE] >= 8), creating more specialised characters.
- Both conditions default to 0 in config, so existing characters need no changes.

## Possible Approach

| Ability | Current | Possible |
|---------|---------|----------|
| Flurry (Warrior) | min_matches=2 | min_matches=2 (unchanged — bread and butter) |
| Fireball (Goblin) | min_matches=2 | min_matches=3 (harder to trigger, but devastating) |
| Shield (Healer) | min_matches=2 | min_matches=2 (unchanged — support should be reliable) |
| Hex (Shaman) | min_matches=2 | min_value=4 (only fires on mid+ rolls — rewards big dice) |

This creates drafting identity: Goblin wants many dice (high [M] chance), Shaman wants big dice (high [V] chance).

## Related

- `docs/ideas/combat.md` — min_value trigger discussion
- `docs/codebase/ability.md` — ability resolution pipeline

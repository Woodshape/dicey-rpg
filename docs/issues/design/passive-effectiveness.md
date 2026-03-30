# Passive Effectiveness Varies Wildly

## Problem

| Passive | Effective? | Why |
|---------|-----------|-----|
| Tenacity (Warrior) | Strong | Fires ~72% of rolls, significant sustain |
| Scavenger (Goblin) | Moderate | 2 dmg on miss (ignores DEF). Adds up but Goblin dies early |
| Empathy (Healer) | Weak-Moderate | +1 resolve on ally damage. Accelerates Mass Heal but Healer often dies first |
| Curse Weaver (Shaman) | Very Weak | 1 dmg per condition on target. Conditions are rare — nearly never fires |

Tenacity is the best passive by a wide margin. Curse Weaver is almost non-functional because the condition ecosystem is too thin (only Shield and Hex exist, and Hex rarely lands on a meaningful target).

## Root Cause

- **Tenacity** triggers on miss (common event) and provides sustain (the most valuable effect)
- **Curse Weaver** triggers on condition count (rare event) and deals chip damage (low value)
- The gap isn't about numbers — it's about trigger frequency × effect impact

## Consequence

Passives don't create meaningful differentiation between characters. Warrior's passive is a significant survival advantage; the other three are near-irrelevant.

## Possible Fixes

- **Buff Curse Weaver trigger:** fire on any roll (not just when target has conditions), or deal damage per condition on *any* enemy (not just target)
- **Expand condition ecosystem:** more condition types (Poison, Burn, Freeze) make Curse Weaver scale naturally
- **Redesign weak passives:** give Shaman/Healer passives that trigger on common events (every roll, every turn) rather than rare ones
- **Nerf Tenacity:** reduce to heal 1 HP only when unmatched >= 2, so it doesn't fire on every miss

## Related

- `docs/ideas/passives.md` — alternative passive designs
- `docs/issues/design/def-and-hex.md` — Curse Weaver depends on conditions being meaningful
- `docs/ideas/status-effects.md` — expanding the condition ecosystem

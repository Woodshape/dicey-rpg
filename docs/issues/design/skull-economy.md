# Skull Economy Shifts with Rarity

## Problem

Skull damage becomes the dominant damage source as rarity increases:
- Common: skulls ~50% of total damage, abilities ~50%
- Legendary: skulls ~70% of total damage, abilities ~30%

This is counterintuitive — at higher rarity with more dice slots and higher match rates, you'd expect abilities to dominate. Instead, skulls become proportionally louder.

## Root Cause

Skulls always deal damage on roll (no match needed) and don't benefit from more dice. They're a fixed tax on character slots. As rarity increases:

1. **Slots become more valuable for matching** — each extra normal die dramatically improves match probability (d8 at 4 dice: 59% match vs 3 dice: 34%). A skull occupying one of those slots costs more in match potential.
2. **Fewer rolls per game** — banking for full capacity means fewer total rolls. Ability damage per game drops because there are fewer opportunities. Skull damage drops too but more slowly because skulls fire on every roll.
3. **Skulls are guaranteed value** — skull damage = ATK × skull_count every roll, regardless of match quality. This floor doesn't scale with rarity, while the match-dependent ceiling does.

## Consequence

At high rarity, skulls crowd out the ability system. Characters with skull dice lose disproportionate match potential. The draft tension (skull vs ability dice) becomes lopsided — ability dice are almost always correct, making skulls feel like a trap rather than a meaningful choice.

## Possible Fixes

- **Separate skull slots** — skulls don't occupy ability dice slots. Characters have dedicated skull capacity alongside their normal dice slots. Removes the competition entirely.
- **Skulls as immediate board actions** — picking a skull from the pool immediately deals damage instead of being assigned. Makes skulls a tempo play (damage NOW) vs ability dice (investment for later). Already discussed in `docs/ideas/combat.md`.
- **Skull damage scales with match quality** — skull ATK = base ATK + ([M] / 2). Rewards mixed skull+ability builds since skulls benefit from having ability dice alongside them.
- **Reduce skull slot cost** — skulls occupy half a slot, or the first skull is free. Softens the tradeoff without removing it.

## Related

- `docs/ideas/match-economy.md` — observation 3
- `docs/ideas/combat.md` — skull design concerns
- `docs/ideas/draft-pool.md` — skull dice distribution

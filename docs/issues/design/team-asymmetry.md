# Team Composition Asymmetry

## Problem

Player wins 80% of games. Warrior + Healer (damage + sustain) vs Goblin + Shaman (damage + debuff) is structurally uneven. The Healer extends fights with Shield and Mass Heal, giving the Warrior more rolls. The enemy has zero sustain — once damage starts, it's a race the enemy loses.

- Warrior survives 80% of games (vs Goblin ~16%, Shaman ~20%)
- Healer dies in ~62% of games but buys the Warrior enough time to win

## Root Cause

Not a numbers problem — tuning ATK/HP alone won't close the gap. The enemy roster has no healing, no shielding, and no way to extend fights. The Shaman's Hex is a DEF debuff that does nothing against targets with DEF=0 (see `def-and-hex.md`).

## Consequence

The 80/20 win rate makes the tutorial encounter feel solved. Enemy AI plays correctly but can't overcome the sustain gap.

## Possible Fixes

- **Give enemies sustain:** Shaman could heal, or a new enemy character with healing/shielding
- **Redesign Hex into an offensive ability:** replace the DEF debuff with something that directly helps the enemy survive or deal damage
- **Add a third enemy character:** numbers advantage compensates for no sustain
- **Reduce Healer effectiveness:** lower Shield/Mass Heal values so sustain is less dominant

## Related

- `docs/issues/design/def-and-hex.md` — Hex is useless without DEF targets
- `docs/issues/balance.md` — baseline stats

# Resolve System Degrades at High Rarity

## Problem

Resolve fires drop sharply as rarity increases:
- Common: 0.9 fires/game
- Rare: 0.6 fires/game
- Epic: 0.4 fires/game
- Legendary: 0.3 fires/game

Two compounding causes:
1. **Fewer rolls per game** — characters bank dice across rounds, rolling less often, so the meter has fewer chances to charge.
2. **Higher match rates** — more dice per roll means fewer unmatched dice per roll. The meter charges slower even when it does get a chance.

At Legendary, resolve fires once every 3-4 games. The resolve system was designed as a consolation for bad rolls, but at high rarity there aren't enough bad rolls to fuel it.

## Consequence

Resolve abilities become irrelevant at Rare+. Characters designed around their resolve ability (e.g. Shaman's Shadow Bolt as primary win condition) lose their identity. The three-ability kit (main + resolve + passive) effectively becomes a two-ability kit.

## Possible Fixes

- **Per-rarity resolve_max:** lower resolve_max for higher-rarity characters (e.g. Common=10, Rare=8, Epic=6, Legendary=4) to compensate for fewer charging opportunities
- **Per-die-type charge scaling:** d12 unmatched dice charge more than d4 (rewards risk-taking, also helps the d12 reward gap)
- **Charge on match too:** small charge even on matched rolls (e.g. +1 per roll regardless), so the meter isn't purely miss-dependent
- **Overflow charging:** when [M] > ability threshold, excess matched dice charge resolve instead of being wasted
- **resolve_max in character config:** already supported — can tune per character without code changes

## Related

- `docs/ideas/match-economy.md` — observation 2
- `docs/ideas/combat.md` — resolve meter charge rate ideas
- `docs/issues/balance.md` — section "Resolve System Degrades at High Rarity"

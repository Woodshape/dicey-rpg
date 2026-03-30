# d12 Reward Gap

## Problem

The risk/reward tradeoff between small and big dice is working but the reward for risk-taking is marginal. d12 does only ~30% more damage when it hits, while d4 fires 32% more often. Effective throughput is nearly identical.

At Legendary (6 slots), hybrid formula `[M]×[V]`:
- d4: [M]=4.6, [V]=2.8 → 12.9/matched roll, fires **100%**
- d12: [M]=2.1, [V]=8.0 → 16.8/matched roll, fires **76%**

The gamble of committing to d12s doesn't feel rewarding enough relative to the safe d4 strategy.

## Consequence

Players (and AI) have weak incentive to draft big dice. The "Paladin fantasy" — committing to d12s for devastating single blows — underdelivers. Small dice are almost always the rational choice because consistency dominates.

## Possible Fixes

- **Non-linear [VALUE] scaling in abilities:** e.g. `[V]²/4` instead of `[V]` — makes high values disproportionately powerful
- **[VALUE] threshold bonuses:** abilities deal bonus damage when [V] >= 8 or >= 10 — rewards high rolls
- **Per-die-type ability variants:** value-scaling abilities could have higher base multipliers than match-scaling ones
- **d12 match bonus:** give d12 a small inherent bonus when it does match (e.g. +2 [VALUE]) to widen the gap

## Related

- `docs/ideas/match-economy.md` — observation 1
- `docs/ideas/characters.md` — class design (Paladin favors [VALUE])

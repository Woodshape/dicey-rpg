# d12 Reward Gap

## Problem

The risk/reward tradeoff between small and big dice is working but the reward for risk-taking is marginal. d12 does only ~30% more damage when it hits, while d4 fires 32% more often. Effective throughput is nearly identical.

At Legendary (6 slots), hybrid formula `[M]×[V]`:
- d4: [M]=4.6, [V]=2.8 → 12.9/matched roll, fires **100%**
- d12: [M]=2.1, [V]=8.0 → 16.8/matched roll, fires **76%**

The gamble of committing to d12s doesn't feel rewarding enough relative to the safe d4 strategy.

## Consequence

Players (and AI) have weak incentive to draft big dice. The "Paladin fantasy" — committing to d12s for devastating single blows — underdelivers. Small dice are almost always the rational choice because consistency dominates.

## Fix Applied: Enhanced Mode (2026-03-30)

Abilities now have an **enhanced mode** that activates when `[VALUE] >= value_threshold`. The threshold is per-ability in `.cfg` files. The behavior change is qualitative — not a flat damage bonus, but a fundamentally different effect.

| Ability | Normal | Enhanced ([V] >= 8) |
|---------|--------|---------------------|
| Flurry | [V] dmg × [M] hits, reduced by DEF | **Ignores DEF** (PIERCING) |
| Fireball | [M] × [V] dmg, reduced by DEF | **Ignores DEF** (PIERCING) |
| Smite | [V] dmg, reduced by DEF | **Ignores DEF** (PIERCING) |
| Heal | Restore [V] HP to self | Also heals **lowest-HP ally** (PARTY HEAL) |
| Shield | Shield lowest-HP ally for [V] | Shields **all alive allies** (PARTY SHIELD) |
| Hex | -1 DEF for 3 turns | **-2 DEF** for 3 turns (DEEP HEX) |

### Why this works

- d4 (max [V]=4) and d6 (max [V]=6) can **never** trigger enhanced mode at threshold=8
- d8 triggers occasionally (when [V]=8, probability depends on match group)
- d10/d12 trigger frequently — this is their payoff for low match rates
- The behavioral change (ignoring DEF, party-wide effects) is qualitatively different, not just "more damage" — it creates moments where big dice feel dramatically more powerful

### Design

- `value_threshold` on the `Ability` struct, configurable per-ability in `.cfg` files
- `ability_is_enhanced()` helper in `dice.odin` — simple threshold check
- Each ability proc branches on enhanced and implements its own behavior change
- Describe procs append a keyword tag: PIERCING, PARTY HEAL, PARTY SHIELD, DEEP HEX

Replaces the earlier flat value bonus system (+N damage at threshold), which was too subtle to matter in practice.

## Related

- `docs/ideas/match-economy.md` — observation 1
- `docs/ideas/characters.md` — class design (Paladin favors [VALUE])
- `docs/codebase/ability.md` — Enhanced Mode section

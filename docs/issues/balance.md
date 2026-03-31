# Balance Issues

Baseline: 1000 rounds, seed=42, encounter=tutorial (2v2, all Uncommon).

## Current Sim Stats (post-skull rework, 2026-03-31)

- **75.1% player wins**, 24.9% enemy wins, 0% draws
- Average game length: 34.7 turns
- Skull damage formula: `skull_roll + max(ATK - DEF, 0)` — skull roll is raw, DEF only reduces ATK bonus

### Skull Rework (2026-03-31)

Tutorial characters bumped from Common → Uncommon (3 dice, d6 skull die). Skull dice now roll a rarity-gated die (`RARITY_SKULL_DIE` table: Common=d4, Uncommon=d6 ... Legendary=d12), storing the actual roll in `Roll_Result.skulls[i]`. Formula changed from flat ATK-DEF to `skull_roll + max(ATK-DEF, 0)`, guaranteeing skull rolls always deal minimum damage regardless of DEF.

Win rate dropped from 80% → 75.1% post-rework (skulls now more variable, lower average than old formula for Uncommon characters).

### Rarity Scale

5 tiers: Common=2 dice, Uncommon=3, Rare=4, Epic=5, Legendary=6. Each tier has a matching skull die size.

Pre-rework rarity stats (old Common=3 dice baseline, still directionally valid):

| Metric | Common (3) | Rare (4) | Epic (5) | Legendary (6) |
|--------|-----------|----------|----------|----------------|
| Ability fire rate | 28% | 48% | 66% | 79% |
| 0-match rolls | 72% | 52% | 34% | 21% |
| Avg [M] | 0.6 | 1.1 | 1.7 | 2.4 |
| Avg turns | 45.6 | 41.1 | 38.0 | 37.7 |

## Open Design Issues

Individual issue files in `docs/issues/design/`:

- [team-asymmetry.md](design/team-asymmetry.md) — 80% player win rate from Healer sustain vs zero enemy sustain
- [def-and-hex.md](design/def-and-hex.md) — only Warrior has DEF>0, making Hex and damage reduction vestigial
- [shadow-bolt-dominance.md](design/shadow-bolt-dominance.md) — Shadow Bolt is the enemy's only win condition
- [ability-fire-rate.md](design/ability-fire-rate.md) — all abilities use min_matches=2, no differentiation
- [passive-effectiveness.md](design/passive-effectiveness.md) — Tenacity is strong, Curse Weaver is non-functional
- [d12-reward-gap.md](design/d12-reward-gap.md) — d12 risk/reward tradeoff is too narrow
- [resolve-at-high-rarity.md](design/resolve-at-high-rarity.md) — resolve fires drop to 0.3/game at Legendary
- [skull-economy.md](design/skull-economy.md) — skulls become 70% of damage at high rarity

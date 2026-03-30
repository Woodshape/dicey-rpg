# Balance Issues

Baseline: 1000 rounds, seed=42, encounter=tutorial (2v2, all Common).

## Current Sim Stats (post-AI patience fix)

- **80.0% player wins**, 20.0% enemy wins, 0% draws
- Average game length: 45.6 turns
- Sim now reports DMG/roll and DMG/turn alongside DMG/game

### AI Patience Fix (2026-03-30)

The AI previously rolled as soon as a character had 2 normal dice. Now it waits until the character is at full capacity (`assigned_count >= max_dice`). This forces dice accumulation across rounds and dramatically improved match rates.

Before/after (Common):
- Ability fire rate: 19.5% → **28.4%**
- 3-dice rolls: 25% → **56%** of all rolls
- 0-match rolls: 81% → **72%**
- Avg [M]: 0.4 → **0.6**

### Rarity Now Matters

With the patient AI, rarity became the strongest lever in the system:

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

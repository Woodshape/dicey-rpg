# Match Economy Investigation

**Date:** 2026-03-30

## Problem

Abilities fire ~20% of the time across all characters. 81% of rolls produce zero matches. The match system — the core mechanic — is a rare event rather than the primary combat driver. Skull damage + passives carry games instead.

## Root Cause: Draft Economy

The bottleneck is not rarity, skulls, or pool size — it's the ratio of picks to characters per round.

### Key Numbers (1000-round sim, seed=42, tutorial encounter)

- **Avg dice per roll:** ~2 normal dice (70% of all rolls are 2-die rolls)
- **Ability fire rate:** ~19-20% for all characters regardless of rarity
- **Match rate by dice count:**

| Dice | d4 | d6 | d8 | d10 | d12 |
|------|----|----|----|----|-----|
| 1 | 0% | 0% | 0% | 0% | 0% |
| 2 | 26.5% | 16.8% | 12.8% | 9.8% | 9.0% |
| 3 | 62.9% | 44.0% | 34.2% | 26.6% | 24.0% |
| 4 | — | — | — | — | — |

### Why Characters Only Roll 2 Dice

With pool_size=6, each side gets 3 picks per round split across 2 characters = **1.5 picks per character per round**. The AI rolls as soon as a character has 2 normal dice. Weight groups cycle each round, often changing available types and invalidating banked dice.

### What Doesn't Help

- **Higher rarity:** Common→Rare gains ~3pp fire rate (19.5%→22.3%). Rare→Epic another ~1pp. The extra slots (4-5) almost never get filled. The ceiling is irrelevant when the floor is 1-2 dice.
- **No skulls:** skull_chance=0 produces identical results to 10%. Skulls aren't eating slots in practice.
- **Bigger pool:** pool_size=10 (5 picks/side) produces identical results. The AI rolls at 2 dice anyway, so extra picks don't accumulate.

## Options

### A. Fix the AI Roll Timing

Raise `ai_should_roll` threshold from `normal_count >= 2` to `normal_count >= max_dice` or `max_dice - 1`. AI banks dice across rounds, waits for fuller hands before rolling.

- Pro: Simple code change
- Con: Useless alone — AI still only gets 1.5 picks/round, waiting longer doesn't produce more picks
- Con: Longer games, more "dead" turns

### B. Fix the Draft Economy

Increase picks per character per round. Options:
- Larger pool (8-10 dice) — but sim showed no effect without AI fix (A)
- Fewer characters (1v1) — all 3 picks go to one character
- Multiple draft rounds before combat — draft 2 rounds, then fight
- Draft-then-bank: dice persist across rounds, multiple draft rounds accumulate before rolling

- Pro: Addresses the root cause directly
- Con: Useless without A (AI rolls at 2 dice regardless of supply)
- Note: A + B together could be effective

### C. Fix the Match System — REJECTED

**Rejected:** Lowering min_matches or guaranteeing partial matches would remove the "will I match?" tension that is the core of the game design. The uncertainty of matching is what makes drafting decisions meaningful — without it, dice selection becomes purely about [VALUE] optimization and the match axis collapses.

### D. Structural Economy Fixes

- **Dice persist until consumed** — characters hold dice across rounds. Weight group cycling becomes strategic: "wait for a d4 round to fill my Rogue." AI needs to learn when to hold vs roll.
- **Separate skull and ability slots** — skulls don't compete with normal dice. Characters always have full slots for ability dice.

- Pro: Preserves the match tension while giving more dice to work with
- Con: Persistence + weight group cycling is complex to balance
- Con: Separate skull slots changes the skull/ability tradeoff design intent

## Resolution

**Option A was implemented** (2026-03-30). `ai_should_roll` now requires `assigned_count >= max_dice` instead of `normal_count >= 2`. Results with 1000-round sim across all rarities:

| Metric | Common (3) | Rare (4) | Epic (5) | Legendary (6) |
|--------|-----------|----------|----------|----------------|
| Ability fire rate | 28% | 48% | 66% | 79% |
| 0-match rolls | 72% | 52% | 34% | 21% |
| Avg [M] | 0.6 | 1.1 | 1.7 | 2.4 |
| Dmg/roll (Warrior) | 2.1 | 2.5 | 2.7 | 2.6 |
| Dmg/roll (Goblin) | 3.8 | 4.7 | 5.3 | 5.6 |
| Avg turns | 45.6 | 41.1 | 38.0 | 37.7 |

Option A alone was sufficient — the dependency prediction ("useless alone") was wrong. Banking dice across rounds works because dice persist on characters between rounds. Characters accumulate 3 dice over ~2 rounds instead of rolling 2 dice every round.

Options B and D remain viable for future tuning but are not needed to solve the original problem.

## Post-Fix Observations

### 1. [VALUE] is flat — die size tradeoff works but could be sharper

Avg [V] barely changes across rarities (~5.7 at Common, ~5.4 at Legendary). The hybrid formula `[M]×[V]` at Legendary:

- d4: avg [M]=4.6, avg [V]=2.8 → expected ≈ 12.9/matched roll, fires **100%**
- d12: avg [M]=2.1, avg [V]=8.0 → expected ≈ 16.8/matched roll, fires **76%**

d12 does ~30% more damage when it hits, d4 fires 32% more often. Effective throughput is nearly identical — the risk/reward tradeoff is working as designed. But the gap could be wider for d12 to feel more rewarding.

### 2. Resolve system degrades at high rarity

Resolve fires drop from ~0.9/game (Common) to ~0.3/game (Legendary). Fewer rolls per game + higher match rates = fewer unmatched dice. At Legendary, resolve is nearly irrelevant — designed as a consolation for bad rolls, but at high rarity there aren't enough bad rolls to fuel it.

### 3. Skull economy shifts with rarity

Skull damage is relatively stable across rarities (Warrior: 6.3→4.4/game) but ability damage drops much faster (7.3→3.6/game). At Common, skulls are ~50% of total damage. At Legendary, ~70%. Skulls become proportionally more important as rarity increases — counterintuitive, since you'd expect abilities to dominate with more dice.

This is because skulls always deal damage (no match needed) and don't benefit from more dice. They're a fixed tax on character slots that becomes more expensive as slots become more valuable for matching.

### 4. Win rate converges at higher rarity

Player win rate drops from 80% (Common) to ~76% (Rare+) and flatlines. Healer survival improves (37.8%→58.7%) because Shield fires more often. The structural asymmetry (Healer sustain vs zero enemy sustain) is still the dominant factor but less pronounced when both sides have reliable abilities.

### 5. Core die system is validated

The fundamental [MATCHES]/[VALUE] two-axis design works:
- Small dice → high [M], low [V] → consistent, reliable
- Big dice → low [M], high [V] → risky, spikey
- Hybrid formula rewards both axes without either dominating
- Rarity meaningfully gates [M] ceiling — exactly as the design doc intended
- Match probability curves match the design doc's theoretical tables

The remaining issues are in systems built on top of the die system (resolve scaling, skull slot competition, team composition asymmetry) — not in the dice math itself.

### 6. "Total damage per game" is a misleading stat

The simulator's DMG stat showed total damage *decreasing* with rarity (Warrior: 12.7 at Common → 6.2 at Legendary). This was a statistical artifact — games are shorter and enemy HP is fixed, so total damage is bounded by HP pools. The sim now reports damage per roll and damage per turn, which correctly show per-roll damage *increasing* with rarity.

## Dependencies (Original Assessment)

- A without B: AI waits longer but still only gets 1.5 picks/round → **proved wrong: banking across rounds works**
- B without A: More picks available but AI rolls at 2 anyway → no improvement
- A + B together: AI waits + more supply = characters reach 3+ dice → significant improvement
- C alone: Works independently, biggest single-lever change — **rejected (removes core tension)**
- D: Independent structural changes, each works alone but complex

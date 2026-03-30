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

## Dependencies

- A without B: AI waits longer but still only gets 1.5 picks/round → minimal improvement
- B without A: More picks available but AI rolls at 2 anyway → no improvement
- A + B together: AI waits + more supply = characters reach 3+ dice → significant improvement
- C alone: Works independently, biggest single-lever change
- D: Independent structural changes, each works alone but complex

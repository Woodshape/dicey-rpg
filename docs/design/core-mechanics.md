# Dicey RPG - Core Mechanics Design Document

**Status:** Draft
**Last Updated:** 2026-03-25

---

## Overview

Dicey RPG is a turn-based RPG built around a dice-drafting mechanic. Players and enemies take turns picking dice from a shared board, roll their drafted hand, and resolve abilities based on two axes: **match count** (how many dice show the same value) and **matched value** (how high that value is).

---

## Dice Types

Five dice types exist in the game, each with a different number of faces:

| Die  | Faces | Match Probability | Max Value | Character |
|------|-------|-------------------|-----------|-----------|
| d4   | 4     | Very high          | 4         | Consistent, reliable |
| d6   | 6     | High               | 6         | Balanced-safe |
| d8   | 8     | Moderate           | 8         | Balanced-risky |
| d10  | 10    | Low-moderate       | 10        | Risk-leaning |
| d12  | 12    | Low                | 12        | High-risk, high-reward |

The fewer faces a die has, the more likely it is to match other dice in a hand, but the lower its maximum value. This creates a natural tension between consistency and power.

---

## Character Rarity & Dice Slots

Each character has a rarity that determines how many dice can be assigned to them at once. This directly gates which match patterns are achievable.

| Rarity    | Max Dice | Patterns Unlocked |
|-----------|----------|-------------------|
| Common    | 3        | Pair, Three of a Kind |
| Rare      | 4        | + Two Pairs, Four of a Kind |
| Epic      | 5        | + Full House, Five of a Kind |
| Legendary | 6        | No new patterns — higher rarity just improves the probability of existing patterns |

Match patterns are defined up to Five of a Kind. More dice do not unlock new patterns; they increase the odds of achieving stronger ones. A legendary character rolling 6 dice where all show the same value still resolves as Five of a Kind.

Note: Three of a Kind requires only 3 dice, so Common characters can achieve it. Two Pairs requires a minimum of 4 dice (2+2), making it Rare+. Full House requires 5 (3+2), making it Epic+.

Additional rarities can be slotted between or beyond these tiers as the design evolves.

### The Hand

- The player's hand holds a maximum of **5 dice** at any time.
- Dice can be freely moved between the hand and any character slot at no action cost.
- **A character can only hold dice of a single type.** All assigned dice must be the same die type (all d4, all d8, etc.). Mixed types are not permitted on a single character.
- Picking a die from the board costs an action. Rolling a character's assigned dice costs an action. Moving dice between hand and characters is free.
- Switching a character's die type requires pulling their current dice back to hand first, which consumes hand slots and costs tempo.
- The hand acts as a staging area: you may hold different die types simultaneously, routing each type to the appropriate character.
- With 4 characters potentially wanting different die types, you can rarely build up more than 1–2 characters at once. This forces turn-by-turn prioritisation.

---

## Board Layout

### Shape

The board is a square grid. Each cell holds one die (type visible, value unknown until rolled). The board is shared between both sides.

A square grid has concentric rings where outer rings are naturally larger than inner ones — a 5×5 board has 16 outer tiles, 8 middle tiles, and 1 centre tile. This geometry directly drives the rarity distribution without any special rules.

Exact board size TBD (playtesting).

### Rarity Gradient

Dice types are distributed by ring depth, from cheap and common on the outside to rare and powerful at the centre:

| Ring        | Die Types    | Rationale |
|-------------|-------------|-----------|
| Outer ring  | d4, d6      | Most tiles, highest supply, low risk/reward |
| Middle ring | d8, d10     | Fewer tiles, moderate supply |
| Centre      | d12         | Fewest tiles, scarcest, highest risk/reward |

The outer ring having the most tiles means d4/d6 are naturally the most abundant dice on the board — no special weighting rules needed.

### Perimeter Picks

**You can only pick dice from the current outermost accessible ring.** Inner dice are locked until the tiles in front of them are cleared.

- Each pick removes one die from the perimeter, potentially exposing inner tiles
- Exposed inner tiles become pickable on future turns
- Both players pick from the same accessible perimeter

### Denial and the Exposure Dilemma

Every pick does two things simultaneously: it takes a die for yourself and potentially exposes a higher-value die for your opponent.

This creates a persistent tension:
- Grabbing a d6 you don't need might expose a d12 your opponent wants
- Leaving a d6 in place might be intentional — keeping that d12 locked away from both sides
- Racing to clear the outer ring is sometimes correct; stalling it is sometimes correct

Board refill timing is TBD — this affects how often the exposure dilemma resets.

---

## Round Flow

The game is action-economy based rather than strictly round-based. Both sides interleave actions:

- **Pick** (action): Drag one die from the board to your hand (max 5) or directly to a character slot.
- **Assign** (free): Drag dice between your hand and a character slot via drag-and-drop. No action cost. Pure die type constraint enforced.
- **Roll** (action): Roll all dice currently assigned to one character. Triggers their ability or charges their meter. Assigned dice are consumed.

Actions alternate between player and enemy. Building up a character telegraphs your intent (assigned die types are visible to both sides) but enables stronger match patterns.

---

## Core Resolution: The Two Axes

After rolling, results are evaluated on two independent axes:

### Axis 1: Match Pattern (Breadth)

The match pattern formed by the rolled dice assigned to a character, using poker-style naming. The number of dice a character can hold (rarity) determines which patterns are reachable.

| Match Pattern    | Description              | Trigger Level | Min Rarity |
|------------------|--------------------------|---------------|------------|
| Pair             | 2-of-a-kind              | Basic         | Common     |
| Three of a Kind  | 3-of-a-kind              | Strong        | Common     |
| Two Pairs        | 2+2 (needs 4 dice)       | Moderate      | Rare       |
| Four of a Kind   | 4-of-a-kind              | Powerful      | Rare       |
| Full House       | 3+2 (needs 5 dice)       | Strong+       | Epic       |
| Five of a Kind   | All 5 match              | Epic          | Epic       |
Note: Three of a Kind is achievable by Common characters (3 dice). Two Pairs requires 4 dice minimum despite being a "lower" pattern — a common character can get a triple but never two pairs.

The highest pattern determines the trigger level. Secondary groups in the same roll may also contribute depending on the ability.

**Any match probability — pure same-type hand by rarity:**

| Die | Common (3 dice) | Rare (4 dice) | Epic (5 dice) | Legendary (6 dice) |
|-----|-----------------|---------------|---------------|---------------------|
| d4  | 62.5%           | 90.6%         | **100%**      | **100%**            |
| d6  | 44.4%           | 72.2%         | 90.7%         | 98.5%               |
| d8  | 34.4%           | 59.0%         | 79.5%         | 92.3%               |
| d10 | 28.0%           | 49.6%         | 69.8%         | 84.9%               |
| d12 | 23.6%           | 42.7%         | 61.8%         | 77.7%               |

Higher rarity consistently improves match odds across all die types. The gain is most dramatic at lower rarities — going Common→Rare with d12s roughly doubles your match rate (23.6%→42.7%). Rare→Epic and Epic→Legendary still help but with diminishing returns.

**Detailed breakdown — Common (3 dice):**

| Die | No Match | Pair  | Three of a Kind |
|-----|----------|-------|-----------------|
| d4  | 37.5%    | 56.3% | 6.3%            |
| d6  | 55.6%    | 41.7% | 2.8%            |
| d8  | 65.6%    | 32.8% | 1.6%            |
| d10 | 72.0%    | 27.0% | 1.0%            |
| d12 | 76.4%    | 22.9% | 0.7%            |

**Detailed breakdown — Rare (4 dice):**

| Die | No Match | Pair  | Two Pairs | Three of a Kind | Four of a Kind |
|-----|----------|-------|-----------|-----------------|----------------|
| d4  | 9.4%     | 56.3% | 14.1%     | 18.8%           | 1.6%           |
| d6  | 27.8%    | 55.6% | 6.9%      | 9.3%            | 0.5%           |
| d8  | 41.0%    | 49.2% | 4.1%      | 5.5%            | 0.2%           |
| d10 | 50.4%    | 43.2% | 2.7%      | 3.6%            | 0.1%           |
| d12 | 57.3%    | 38.2% | 1.9%      | 2.5%            | 0.06%          |

**Detailed breakdown — Epic (5 dice):**

| Die | No Match | Pair  | Two Pairs | Three of a Kind | Full House | Four of a Kind | Five of a Kind |
|-----|----------|-------|-----------|-----------------|------------|----------------|----------------|
| d4  | 0%       | 23.4% | 35.2%     | 23.4%           | 11.7%      | 5.9%           | 0.4%           |
| d6  | 9.3%     | 46.3% | 23.1%     | 15.4%           | 3.9%       | 1.9%           | 0.1%           |
| d8  | 20.5%    | 51.3% | 15.4%     | 10.3%           | 1.7%       | 0.85%          | 0.02%          |
| d10 | 30.2%    | 50.4% | 10.8%     | 7.2%            | 0.9%       | 0.45%          | 0.01%          |
| d12 | 38.2%    | 47.7% | 8.0%      | 5.3%            | 0.53%      | 0.27%          | 0.005%         |

**Detailed breakdown — Legendary (6 dice):**

Three Pairs rolls up into Two Pairs (best evaluable pattern). Double Triple rolls up into Full House.

| Die | No Match | Pair  | Two Pairs | Three of a Kind | Full House | Four of a Kind | Five of a Kind |
|-----|----------|-------|-----------|-----------------|------------|----------------|----------------|
| d4  | 0%       | 0%    | 35.2%     | 11.7%           | 38.1%      | 13.2%          | 1.9%           |
| d6  | 1.5%     | 23.1% | 38.6%     | 15.4%           | 16.1%      | 4.8%           | 0.4%           |
| d8  | 7.7%     | 38.5% | 30.8%     | 12.8%           | 7.9%       | 2.2%           | 0.1%           |
| d10 | 15.1%    | 45.4% | 23.8%     | 10.1%           | 4.4%       | 1.2%           | 0.06%          |
| d12 | 22.3%    | 47.8% | 18.6%     | 8.0%            | 2.7%       | 0.7%           | 0.03%          |

### Axis 2: Matched Value (Depth)

The face value shown on the matching dice. Due to fair die symmetry, value is uniformly distributed — but the ceiling scales with die size.

| Die | Avg matched value | Max matched value |
|-----|-------------------|-------------------|
| d4  | 2.5               | 4                 |
| d6  | 3.5               | 6                 |
| d8  | 4.5               | 8                 |
| d10 | 5.5               | 10                |
| d12 | 6.5               | 12                |

### Combined Effect

An ability's total impact is a function of both axes:

- `Three of a Kind with d4s showing 3` = Strong trigger, potency 3 (reliable but capped)
- `Pair with d12s showing 11` = Basic trigger, potency 11 (rare but devastating)
- `Full House with d6s showing 5` = Powerful trigger, potency 5 (the sweet spot)
- `Two Pairs with d4s showing 2 and 4` = Moderate trigger, two active potencies

This means there is no single "best" drafting strategy. The optimal hand depends on your class, abilities, and the current situation.

---

## Unmatched Dice: Super Ability Meter

Dice that do not form any match are **not wasted**. Instead, each unmatched die contributes to a **Super Ability Meter**.

### Meter Rules

- Each unmatched die adds charge to the meter (exact amount TBD - could be flat, or scaled by die type/value).
- The meter persists across rounds within a battle.
- When the meter is full, the player can trigger a **Super Ability** specific to their race/class combination.
- Using the Super Ability empties the meter.

### Super Meter Generation Rate

| Die | Avg unmatched dice per roll | Notes |
|-----|-----------------------------|-------|
| d4  | ~1.6                        | Always matches somewhere, but leftover stragglers are common |
| d6  | ~2.4                        | |
| d8  | ~3.0                        | |
| d10 | ~3.4                        | |
| d12 | ~3.5                        | Nearly double d4 — fuels super meter fast |

d12 builds miss ~38% of rolls entirely and charge the meter roughly 2× faster than d4 builds. This is a built-in balancer: consistent drafters build super slowly, gamblers charge it fast but need the gamble to pay off.

### Design Intent

- Prevents "dead" turns where nothing rolls well - even a bad roll builds toward something.
- Creates a strategic layer: do you draft risky d12s knowing misses fuel your Super?
- High-match builds (lots of d4s) fill the meter slowly. High-risk builds (lots of d12s) fill it fast on bad rolls.
- Super Abilities should feel impactful enough to be worth building toward, but not so dominant that players intentionally draft poorly to charge them.

### Super Ability Examples (Placeholder)

- **Human Paladin:** "Divine Judgment" - Deal massive holy damage ignoring armor.
- **Orc Berserker:** "Blood Frenzy" - Take an extra full turn immediately.
- **Elf Wizard:** "Arcane Cascade" - Reroll all dice and resolve both results.
- **Dwarf Guardian:** "Stone Fortress" - Block all damage for 2 rounds.

---

## Ability System

Abilities are categorized by which axis they scale from.

### Match-Scaling Abilities (Favor Consistent Dice)

| Ability        | Effect |
|----------------|--------|
| Flurry         | Each match tier adds another hit. Low damage per hit, stacks up. |
| Shield Wall    | Block points = number of matching dice. More matches = thicker wall. |
| Chain Lightning| Jumps to additional enemies per match tier. |
| Poison         | Applies stacks equal to match count. Ticks over time. |

### Value-Scaling Abilities (Favor Big Dice)

| Ability     | Effect |
|-------------|--------|
| Smite       | Raw damage = highest matched value. One big hit. |
| Heal        | Restore HP equal to matched value. |
| Pierce      | Ignore armor up to the matched value. High value bypasses tanks. |
| Intimidate  | Debuff enemy if value exceeds a threshold. |

### Hybrid Abilities (Reward Both Axes)

| Ability         | Effect |
|-----------------|--------|
| Fireball        | Damage = matches x value. Dream ability, costly to unlock. |
| Vampiric Strike | Deal damage = value, heal = match count. Split scaling. |

---

## Dice Manipulation Abilities

Active abilities that modify dice results after rolling. These add skill expression and reduce pure randomness.

| Ability  | Scope           | Effect |
|----------|-----------------|--------|
| Nudge    | Within character | Change one assigned die result by +/-1. Turn a near-miss into a match. |
| Copy     | Within character | Set one assigned die to match another assigned die's result. Guaranteed +1 match. |
| Split    | Hand tool        | Convert one die in hand to two dice of the next smaller type, placed in hand. Trades value potential for match potential on a different character. (e.g. d8 → two d4s) |
| Empower  | Hand tool        | Merge two dice of the same type in hand into one die of the next larger type, placed in hand. Trades match potential for value potential on a different character. (e.g. two d6s → one d8) |

Split and Empower operate on the hand rather than on assigned dice, making them party-level routing tools. They let you convert die types mid-turn to better match what your characters need.

---

## Class Design Philosophy

Classes are defined by their preferred axis, giving each class a distinct drafting personality.

| Class   | Preferred Axis | Drafting Style | Fantasy |
|---------|---------------|----------------|---------|
| Rogue   | Matches       | Commits to d4s for reliable pairs and triples. | Death by a thousand cuts |
| Paladin | Value         | Commits to d12s. Waits for the one devastating hit. | Single righteous blow |
| Wizard  | Hybrid        | Reads the board and commits to whatever die type maximises their specific abilities. High skill ceiling. | Calculated devastation |
| Bard    | Manipulation  | Uses Split/Empower to reshape hand routing mid-turn. Forces matches on bigger dice. | Bends luck itself |

---

## Example Hands

### Hand A: 5×d4 — "The Grinder"
Roll: `[2, 3, 2, 4, 2]`
- **Three of a Kind (2s)** → Strong trigger, potency 2
- **Two unmatched dice** (3 and 4) → feed super meter
- Probability of this pattern: 23.4%
- This build almost always fires something; the low ceiling is the tradeoff.

### Hand B: 5×d12 — "The Gambler"
Roll: `[7, 3, 11, 3, 9]`
- **Pair (3s)** → Basic trigger, potency 3 (underwhelming)
- **Three unmatched dice** (7, 11, 9) → solid super meter charge
- Probability of this pattern: 47.7%

Roll: `[9, 9, 9, 2, 7]`
- **Three of a Kind (9s)** → Strong trigger, potency 9 *(this is what you're chasing)*
- **Two unmatched dice** (2 and 7) → still some meter charge
- Probability of three of a kind or better: ~6.1%

### Hand C: Party Split — "Divide and Conquer"
Hand contains: `[d4, d4, d12, d12, d12]`
- 2×d4 assigned to Rogue (Common, 2/3 slots filled — waiting for one more d4)
- 3×d12 assigned to Paladin (Rare, 3/4 slots filled — one more d12 would unlock Two Pairs or Four of a Kind)
- Hand is empty: next pick must choose between grabbing a d4 for the Rogue or a d12 for the Paladin
- Opponent sees the assignment on both characters and knows what types to deny

### Hand C roll — Rogue fires first:
Roll: `[3, 3]` *(only 2 d4s assigned)*
- **Pair (3s)** → Basic trigger, potency 3
- No unmatched dice

### Hand C roll — Paladin fires next turn:
Roll: `[11, 11, 3]` *(3 d12s assigned)*
- **Pair (11s)** → Basic trigger, potency 11 (high-value hit)
- **One unmatched die** (3) → charges Paladin's super meter

---

## Open Questions

- **Board size:** What square grid size feels right? 5×5 (25 tiles), 7×7 (49), or something else? Should it scale with number of combatants?
- **Board refill timing:** After each pick? At the start of a round? When depleted below a threshold?
- **Refill placement:** Do new dice always fill the outer ring, or can they appear anywhere?
- **Partial exposure:** If only some tiles in a ring are cleared, does that expose only those inner neighbours, or does the whole next ring become accessible?
- **Multiple match groups:** If you roll a pair of 3s and a pair of 5s, can you trigger two abilities or must you choose one?
- **Super Meter charge rate:** Flat per unmatched die? Scaled by die type? Scaled by rolled value?
- **Enemy AI drafting:** How sophisticated should enemy drafting be? Should different enemy types have visible drafting preferences?
- **Die distribution on board:** Purely random, or weighted/seeded per encounter for balance?
- **Disruption abilities:** How do status effects like Paralyze interact with loaded dice — do they stay, return to hand, or discard?
- **Party death:** When a character dies, what happens to their assigned dice?

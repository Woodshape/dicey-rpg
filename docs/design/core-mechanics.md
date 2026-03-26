# Dicey RPG - Core Mechanics Design Document

**Status:** Draft
**Last Updated:** 2026-03-26

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

Each character has a rarity that determines how many dice can be assigned to them at once. More dice = higher potential [MATCHES], which directly scales ability power.

| Rarity    | Max Dice | Max [MATCHES] |
|-----------|----------|---------------|
| Common    | 3        | 3             |
| Rare      | 4        | 4             |
| Epic      | 5        | 5             |
| Legendary | 6        | 6             |

Higher rarity doesn't unlock qualitatively new mechanics — it raises the ceiling on [MATCHES], making abilities hit harder or more often.

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

## Core Resolution: [MATCHES] and [VALUE]

After rolling, results are evaluated on two simple, independent axes that feed directly into ability formulas. No pattern lookup tables, no magic values — just two numbers read straight from the roll result.

### [MATCHES] — How many dice hit (Breadth)

**[MATCHES]** = the count of dice whose rolled value appears at least twice. Any die that shares its value with at least one other die is "matched."

- Roll `[3, 7, 3, 11, 5]` → [MATCHES] = 2 (the two 3s)
- Roll `[4, 4, 4, 2, 1]` → [MATCHES] = 3 (three 4s)
- Roll `[3, 3, 5, 5, 1]` → [MATCHES] = 4 (two 3s + two 5s, all four count)
- Roll `[6, 6, 6, 6, 6]` → [MATCHES] = 5
- Roll `[2, 5, 8, 11, 1]` → [MATCHES] = 0

Multiple match groups are additive — rolling two separate pairs gives [MATCHES] = 4, same as four of a kind. The system doesn't distinguish between group shapes. This is intentional: abilities scale on the raw count, not on an abstract pattern tier.

**Rarity gates [MATCHES] directly:** A Common character (3 dice) caps at [MATCHES] = 3. A Legendary character (6 dice) can reach [MATCHES] = 6. More dice = more chances to match = higher [MATCHES].

### [VALUE] — How hard they hit (Depth)

**[VALUE]** = the face value of the best match group (highest frequency, tie-broken by higher value).

- Roll `[3, 7, 3, 11, 5]` → [VALUE] = 3 (the pair of 3s)
- Roll `[3, 3, 5, 5, 1]` → [VALUE] = 5 (both pairs have freq 2, higher value wins)
- Roll `[4, 4, 4, 2, 1]` → [VALUE] = 4

Due to fair die symmetry, [VALUE] is uniformly distributed — but the ceiling scales with die size:

| Die | Avg [VALUE] | Max [VALUE] |
|-----|-------------|-------------|
| d4  | 2.5         | 4           |
| d6  | 3.5         | 6           |
| d8  | 4.5         | 8           |
| d10 | 5.5         | 10          |
| d12 | 6.5         | 12          |

### Combined Effect

Abilities use [MATCHES] and [VALUE] directly in their formulas:

- `3 d4s, roll [3, 3, 3]` → [MATCHES]=3, [VALUE]=3 — reliable, capped low
- `3 d12s, roll [11, 11, 5]` → [MATCHES]=2, [VALUE]=11 — risky, devastating when it hits
- `5 d6s, roll [4, 4, 2, 2, 5]` → [MATCHES]=4, [VALUE]=4 — good breadth from two pairs
- `5 d4s, roll [2, 2, 2, 4, 4]` → [MATCHES]=5, [VALUE]=2 — maximum breadth, low depth

There is no single "best" drafting strategy. Small dice give high [MATCHES] (consistency); big dice give high [VALUE] (power ceiling). The optimal draft depends on the character's abilities and the current situation.

### Why not named patterns?

Earlier designs used poker-style pattern names (Pair, Two Pairs, Full House, etc.) as trigger levels for abilities. This was dropped because:

- **No clean mapping to ability effects.** "Deal [MATCHES] damage to all enemies" makes immediate sense. "Deal Full-House-tier damage" requires a lookup table to understand.
- **Two Pairs and Full House have no distinct design space.** Two Pairs (2+2) is just [MATCHES]=4 — mechanically identical to Four of a Kind for ability purposes. Full House (3+2) is just [MATCHES]=5. The pattern shape doesn't matter if abilities only read the count.
- **Simpler for players.** "You matched 4 dice showing 5" is instantly readable. No need to learn which pattern names map to which power tiers.

The system still detects the largest single group for [VALUE] resolution. If multiple groups exist, all matched dice count toward [MATCHES], and [VALUE] takes the best group.

### Match probability — any match by rarity (pure same-type hand)

| Die | Common (3) | Rare (4) | Epic (5) | Legendary (6) |
|-----|------------|----------|----------|----------------|
| d4  | 62.5%      | 90.6%    | **100%** | **100%**       |
| d6  | 44.4%      | 72.2%    | 90.7%    | 98.5%          |
| d8  | 34.4%      | 59.0%    | 79.5%    | 92.3%          |
| d10 | 28.0%      | 49.6%    | 69.8%    | 84.9%          |
| d12 | 23.6%      | 42.7%    | 61.8%    | 77.7%          |

Higher rarity consistently improves match odds. The gain is most dramatic at lower rarities — Common→Rare with d12s roughly doubles the match rate (23.6%→42.7%).

### [MATCHES] distribution by rarity

**Common (3 dice):**

| Die | [MATCHES]=0 | [MATCHES]=2 | [MATCHES]=3 |
|-----|-------------|-------------|-------------|
| d4  | 37.5%       | 56.3%       | 6.3%        |
| d6  | 55.6%       | 41.7%       | 2.8%        |
| d8  | 65.6%       | 32.8%       | 1.6%        |
| d10 | 72.0%       | 27.0%       | 1.0%        |
| d12 | 76.4%       | 22.9%       | 0.7%        |

**Rare (4 dice):**

| Die | [MATCHES]=0 | [MATCHES]=2 | [MATCHES]=3 | [MATCHES]=4 |
|-----|-------------|-------------|-------------|-------------|
| d4  | 9.4%        | 56.3%       | 18.8%       | 15.7%       |
| d6  | 27.8%       | 55.6%       | 9.3%        | 7.4%        |
| d8  | 41.0%       | 49.2%       | 5.5%        | 4.3%        |
| d10 | 50.4%       | 43.2%       | 3.6%        | 2.8%        |
| d12 | 57.3%       | 38.2%       | 2.5%        | 2.0%        |

Note: [MATCHES]=4 includes both two-pair shapes (2+2) and four-of-a-kind shapes. The system doesn't distinguish — both give the same [MATCHES] value to abilities.

**Epic (5 dice):**

| Die | [MATCHES]=0 | [MATCHES]=2 | [MATCHES]=3 | [MATCHES]=4 | [MATCHES]=5 |
|-----|-------------|-------------|-------------|-------------|-------------|
| d4  | 0%          | 23.4%       | 23.4%       | 41.1%       | 12.1%       |
| d6  | 9.3%        | 46.3%       | 15.4%       | 25.0%       | 4.0%        |
| d8  | 20.5%       | 51.3%       | 10.3%       | 16.2%       | 1.7%        |
| d10 | 30.2%       | 50.4%       | 7.2%        | 11.2%       | 0.9%        |
| d12 | 38.2%       | 47.7%       | 5.3%        | 8.3%        | 0.5%        |

Note: [MATCHES]=4 includes two-pair (2+2) and four-of-a-kind shapes. [MATCHES]=5 includes full-house (3+2) and five-of-a-kind shapes.

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

Abilities use [MATCHES] and [VALUE] directly in their formulas. No pattern-to-tier mapping — the roll result plugs straight into the effect.

### [MATCHES]-Scaling Abilities (Favor Consistent Dice)

| Ability        | Formula | Example (3 d4s, [MATCHES]=3, [VALUE]=2) |
|----------------|---------|------------------------------------------|
| Flurry         | Deal 1 damage [MATCHES] times | 3 hits of 1 damage |
| Shield Wall    | Block [MATCHES] damage from next attack | Block 3 damage |
| Chain Lightning| Hit [MATCHES] enemies for base damage | Hit 3 enemies |
| Poison         | Apply [MATCHES] poison stacks | 3 stacks, ticking over time |

### [VALUE]-Scaling Abilities (Favor Big Dice)

| Ability     | Formula | Example (3 d12s, [MATCHES]=2, [VALUE]=11) |
|-------------|---------|---------------------------------------------|
| Smite       | Deal [VALUE] damage | 11 damage |
| Heal        | Restore [VALUE] HP | Heal 11 HP |
| Pierce      | Ignore [VALUE] armor on next attack | Ignore 11 armor |
| Intimidate  | Debuff enemy if [VALUE] >= threshold | 11 vs threshold |

### Hybrid Abilities (Reward Both Axes)

| Ability         | Formula | Example (5 d6s, [MATCHES]=4, [VALUE]=5) |
|-----------------|---------|-------------------------------------------|
| Fireball        | Deal [MATCHES] x [VALUE] damage | 4 x 5 = 20 damage |
| Vampiric Strike | Deal [VALUE] damage, heal [MATCHES] HP | 5 damage, heal 4 HP |

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
| Rogue   | [MATCHES]     | Commits to d4s for reliable high [MATCHES]. | Death by a thousand cuts |
| Paladin | [VALUE]       | Commits to d12s. Waits for the one devastating [VALUE]. | Single righteous blow |
| Wizard  | Hybrid        | Reads the board and commits to whatever die type maximises [MATCHES] x [VALUE]. High skill ceiling. | Calculated devastation |
| Bard    | Manipulation  | Uses Split/Empower to reshape hand routing mid-turn. Forces matches on bigger dice. | Bends luck itself |

---

## Example Hands

### Hand A: 5×d4 — "The Grinder"
Roll: `[2, 3, 2, 4, 2]`
- **[MATCHES]=3, [VALUE]=2** — three 2s matched, two unmatched
- Flurry (match-scaling): 3 hits of 1 damage
- Fireball (hybrid): 3 x 2 = 6 damage
- 2 unmatched dice → super meter charge
- This build almost always fires something; the low [VALUE] ceiling is the tradeoff.

### Hand B: 5×d12 — "The Gambler"
Roll: `[7, 3, 11, 3, 9]`
- **[MATCHES]=2, [VALUE]=3** — pair of 3s, three unmatched
- Smite (value-scaling): 3 damage (underwhelming)
- 3 unmatched dice → solid super meter charge

Roll: `[9, 9, 9, 2, 7]`
- **[MATCHES]=3, [VALUE]=9** — *(this is what you're chasing)*
- Smite: 9 damage. Fireball: 3 x 9 = 27 damage.
- 2 unmatched dice → still some meter charge
- Probability of [MATCHES]>=3: ~6.1%

### Hand C: Party Split — "Divide and Conquer"
Hand contains: `[d4, d4, d12, d12, d12]`
- 2×d4 assigned to Rogue (Common, 2/3 slots filled — waiting for one more d4)
- 3×d12 assigned to Paladin (Rare, 3/4 slots filled — one more d12 would push [MATCHES] higher)
- Hand is empty: next pick must choose between grabbing a d4 for the Rogue or a d12 for the Paladin
- Opponent sees the assignment on both characters and knows what types to deny

### Hand C roll — Rogue fires first:
Roll: `[3, 3]` *(only 2 d4s assigned)*
- **[MATCHES]=2, [VALUE]=3** — Flurry: 2 hits. Heal: 3 HP.
- No unmatched dice

### Hand C roll — Paladin fires next turn:
Roll: `[11, 11, 3]` *(3 d12s assigned)*
- **[MATCHES]=2, [VALUE]=11** — Smite: 11 damage.
- 1 unmatched die → charges Paladin's super meter

---

## Skull Dice: Base Damage Mechanic

**Problem:** Not all characters have attack abilities. Some focus on blocking, healing, stunning, or manipulating the board/dice. These characters still need a way to deal damage, or combat stalls when only support characters remain.

### Decision: Skull Dice

Skull dice appear on the board alongside normal dice. They are the universal damage mechanic — every character can deal damage by picking up skull dice, regardless of their abilities.

### Rules

- Skull dice appear on the board and are picked/assigned like normal dice.
- **Skull dice are exempt from the pure type rule.** A character can hold skull dice alongside any one normal die type. Skull dice are always "compatible."
- Skull dice are **not rolled for a value**. They are fixed (no face value matters).
- When a character's roll contains **N skull dice**, that character attacks **N times** using their base **Attack stat**.
- Skull dice do **not** participate in match pattern detection. Only normal dice form Pairs, Triples, etc.
- Skull dice do **not** count as unmatched (they don't charge the super meter).

### Roll Resolution With Mixed Dice

A character with 2 skull dice + 3 d8s rolls all 5 at once. Resolution:

1. **Skull dice resolve first:** Each skull die triggers one separate attack at the character's Attack stat. 2 skulls = 2 individual hits, resolved one at a time.
2. **Normal dice resolve second:** The 3 d8s are evaluated for match patterns and trigger abilities as normal.

Both effects happen in the same roll — skull dice provide the damage floor, normal dice provide the ability ceiling.

### Per-Hit Resolution (Important)

Skull damage is applied **per-hit, not pooled**. Each skull die is a discrete attack that deals `max(Attack - target Defense, 0)` damage individually. This is mechanically identical to pooling for now, but the per-hit loop is the foundation for future trigger systems.

**Design options this enables:**

- **On-hit passives:** "Each time this character lands a hit, gain 1 super meter charge" or "Each hit has a 20% chance to apply Poison." These trigger once per skull die, not once per roll.
- **On-hit-taken reactions:** Defensive abilities like "Each time this character takes a hit, reflect 1 damage back" or "Reduce damage by 1 per hit (stacking armor)." Multiple small hits interact differently with per-hit reduction than one big pooled hit.
- **Hit-count scaling:** Abilities like "Deal bonus damage on the 3rd hit this turn." Skull dice hits count toward the threshold.
- **Damage shields:** A shield that absorbs N damage total breaks differently against 3 separate hits of 2 vs 1 hit of 6. Per-hit resolution makes shields more interesting.
- **Lifesteal per hit:** "Heal 1 HP per hit dealt" scales with skull count, not total damage.
- **Status application:** "Each hit has a chance to Stun/Bleed/Burn." More skulls = more chances to proc, creating a reason to stack skulls beyond raw damage.

The per-hit model means stacking many skull dice isn't just "more damage" — it's "more trigger opportunities." This gives skull-heavy builds a distinct identity from ability-focused builds even when total damage is similar.

### Board Placement

- Skull dice appear across all rings of the board (not restricted to a specific ring).
- Distribution TBD — could be fixed count per board fill, random, or encounter-seeded.
- Visually distinct from normal dice (skull icon or unique colour).

### Design Implications

- **Support characters become viable damage dealers** by loading skull dice. A healer with 2 skulls + 1 d4 heals AND attacks.
- **Damage-focused characters** can stack skulls for multi-attacks, but sacrifice ability dice slots.
- **Denial extends to damage:** grabbing skull dice denies your opponent's base damage output.
- **The draft tension deepens:** every skull die you pick is one less ability die, and vice versa.

---

## Character Stats

Character abilities scale from dice rolls (match patterns and values), but skull dice attack using a character's **base stats**. Stats are needed.

### Core Stats (Placeholder)

| Stat    | Description |
|---------|-------------|
| HP      | Hit points. Character dies at 0. |
| Attack  | Damage dealt per skull die in a roll. |
| Defense | Damage reduction from incoming attacks (flat reduction or percentage — TBD). |

### Open Questions: Stats

- **Should Attack scale with level/gear, or is it fixed per character?**
- **Is Defense flat reduction (Attack - Defense = damage) or percentage-based?**
- **Do we need Speed/Initiative?** Currently turn order is alternating actions. A speed stat could determine who picks first after a board refill.
- **Should stats vary by rarity?** A Legendary character might have higher base Attack than a Common one, making skull dice more valuable on them.
- **Stat modifiers from abilities?** E.g., a buff ability that temporarily increases Attack, making skull dice deal more damage for a few turns.

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

# Balance Issues

Baseline: 1000 rounds, seed=42, encounter=tutorial (2v2, all Common).

## Current Sim Stats (post-AI patience fix)

- **80.0% player wins**, 20.0% enemy wins, 0% draws
- Average game length: 45.6 turns

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

Die type match rates at full capacity (Legendary):
- d4: 92%, d6: 88%, d8: 80%, d10: 74%, d12: 58%

The d4 vs d12 tradeoff is working as designed: d4 matches almost always but caps at low [VALUE], d12 misses ~40% of the time but delivers ~3x the [VALUE] when it hits. Hybrid abilities (`[M]×[V]`) produce similar expected throughput for both — the risk/reward axis is live.

### Resolve System Degrades at High Rarity

Resolve fires drop sharply as rarity increases (0.9/game at Common → 0.3/game at Legendary). Fewer rolls per game + higher match rates = fewer unmatched dice = slower meter charging. At Legendary, resolve is nearly irrelevant. This is a structural consequence of the patient AI — characters bank dice and roll less often, so the resolve meter has fewer chances to charge.

### Sim Stat Caveat: "Total Damage Per Game"

The simulator's "DMG" stat shows total damage per game, which decreases at higher rarity (Warrior: 12.7 at Common → 6.2 at Legendary). This is misleading — games are shorter (45.6 → 37.7 turns) and enemy HP is fixed, so total damage is bounded by enemy HP pools. Higher rarity = fewer but more decisive rolls, not less damage output. The correct measure would be damage per roll or damage per turn, which the sim does not currently report.

## 1. Team Composition Asymmetry

Warrior + Healer (damage + sustain) vs Goblin + Shaman (damage + debuff) is structurally uneven.
The Healer extends fights with Shield and Mass Heal, giving the Warrior more rolls. The enemy has
zero sustain — once damage starts, it's a race the enemy loses.

- Warrior survives 74.5% of games (vs Goblin 19.9%, Shaman 25.5%).
- Healer dies in ~75% of games but buys the Warrior enough time to win.

**Root cause:** Not a numbers problem — it reflects roster asymmetry. Tuning ATK/HP alone won't close
the gap without giving the enemy side healing or some form of sustain.

## 2. Hex is Nearly Useless

Hex reduces target DEF by 1 for 3 turns. Only the Warrior has DEF > 0 (DEF=1). Against the other
three characters (DEF=0), Hex is a complete no-op — it reduces 0 to 0.

- Shaman's main ability fires 20% of the time and contributes nothing in 3 out of 4 matchups.
- Curse Weaver (Shaman passive) amplifies conditions, but conditions are rare, so it rarely fires.
- Net effect: the Shaman is a 12 HP body with Shadow Bolt (resolve) as her only real contribution.

**Fix options:**
- Give all characters non-zero DEF so Hex has targets.
- Redesign Hex to a different debuff (reduce ATK, increase damage taken, etc.).
- Replace Hex entirely with an offensive ability.

## 3. Shadow Bolt Dominance

Shadow Bolt (15 dmg, ignores DEF) is the single biggest damage source in the game. It one-shots the
Healer (HP=15) and nearly one-shots the Shaman (HP=12). This makes it the enemy's primary — and
often only — win condition.

- Fires 0.9x/game on average. When it kills the Healer early, the Warrior loses sustain and the
  enemy's win rate improves dramatically.
- The counterpoint: if it fires late or targets the Warrior (HP=20), it's much less decisive.

**Not necessarily a problem** — big resolve abilities should feel impactful. But the gap between
Shadow Bolt (15) and Heroic Strike (10) is large, and Shadow Bolt ignoring DEF means the Warrior's
only defensive stat doesn't help.

## 4. Ability Fire Rate Ceiling

All main abilities fire at ~20% per roll. This is driven by match probability:
- 2 dice: 9-26% match rate depending on die type
- 3 dice: 24-63% match rate depending on die type

With min_matches=2 on all abilities, the fire rate is locked to pair+ probability. There's no
differentiation — every character triggers at the same rate regardless of ability power.

**Design question:** Should stronger abilities require higher min_matches or min_value? Currently
min_value is in the config schema but not wired into the trigger check.

## 5. Passive Effectiveness Varies Wildly

| Passive | Effective? | Why |
|---------|-----------|-----|
| Tenacity (Warrior) | Strong | Fires 80% of rolls, ~6 HP healed/game. Significant sustain. |
| Scavenger (Goblin) | Moderate | 2 dmg on miss (ignores DEF). Adds up but Goblin dies early. |
| Empathy (Healer) | Weak-Moderate | +1 resolve on ally damage. Accelerates Mass Heal but Healer often dies first. |
| Curse Weaver (Shaman) | Very Weak | 1 dmg per condition on target. Conditions are rare — nearly never fires meaningfully. |

Tenacity is the best passive by a wide margin. Curse Weaver is almost non-functional because the
condition ecosystem is too thin (only Shield and Hex exist, and Hex rarely lands on a meaningful target).

## 6. DEF Distribution

Only the Warrior has DEF > 0. This makes:
- Hex useless against 3/4 characters
- Goblin Explosion's DEF interaction irrelevant most of the time
- Skull damage fully unmitigated against 3/4 characters
- Flurry's per-hit DEF reduction meaningful only in mirror-like scenarios

**Fix:** Give multiple characters non-zero DEF to make the damage reduction system actually matter.

## 7. Resolve Charge Rate

- ~1.8-2.0 unmatched dice per roll. At resolve_max=10, that's ~5-6 rolls to fill.
- Resolve fires roughly once per game for most characters (Goblin only 0.4x due to early death).
- Flat charge rate (1 per unmatched die) means all die types charge equally. Higher dice miss more
  often but produce more unmatched dice per roll, roughly balancing out.

**Tuning lever:** Per-character resolve_max is the easiest knob. Lower = more frequent resolve fires.
Per-die-type charge scaling (d12 charges more than d4) is a future option.

## 8. Skull Dice Balance

- SKULL_CHANCE=10%. Skulls deal ATK damage per die, reduced by DEF.
- Warrior skulls: 3 dmg each (ATK=3), reduced to 2 vs DEF=1 targets. ~6.1 skull dmg/game.
- Skulls are "guaranteed value" — always deal damage regardless of match quality.
- With DEF=0 on most characters, skull damage passes through unmitigated.
- Skulls crowd assignment slots (3 max for Common), competing with ability dice.

**Current balance feels okay** — skulls are reliable but not dominant. The tension between skulls
(guaranteed small damage) and ability dice (uncertain but potentially large damage) is working.

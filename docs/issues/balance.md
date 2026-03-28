# Balance Issues

All current stat and damage values are placeholders. The game is playable but not balanced — fights can end too quickly or drag on, and some abilities are clearly stronger than others.

## Current Sim Stats

Latest simulator results (1000 rounds, seed=42):
- **81.3% player wins**, 16.4% enemy wins, 2.3% draws
- Average game length: ~98 turns

## Placeholder Stats

- **HP:** More balanced now (Healer HP=15) but still rough. Without a maximum, balance is driven entirely by the ratio of starting HP to damage/healing throughput. Needs playtesting data.
- **Attack / Defense:** Current values (Goblin ATK=3, Shaman ATK=2) are closer to reasonable but still placeholder. Skull dice dominance relative to ability damage needs cross-checking.
- **Resolve:** resolve_max=10 across the board. May need per-character tuning once ability diversity stabilizes.

## Ability Damage Ceiling

- Fireball ([MATCHES] x [VALUE]) can spike very high with Epic or Legendary characters (e.g., [MATCHES]=5, [VALUE]=10 = 50 damage in one roll).
- Flurry now uses [VALUE] x [MATCHES] (changed from flat scaling), giving it comparable spike potential.
- No current ceiling or diminishing returns. Needs a check once higher-rarity characters are tested in play.

## Resolve Meter Rate

- The meter fills from unmatched dice at a flat rate. Too fast = resolve abilities trivialised (fire every other turn). Too slow = players never see them.
- Resolve abilities have been diversified: 2 of the original 3 heals were replaced with offensive abilities, reducing the "every resolve = heal" monotony.
- The right rate depends on HP values and match frequency — settle HP and ability damage first, then tune this.

## Hex is Weak Against DEF=0 Targets

Hex reduces the target's DEF by 1, but most characters currently have DEF=0. This makes Hex often useless — it reduces 0 to 0 (or to a negative value that has no effect).

**Consequence:** The Shaman's resolve ability contributes nothing in most matchups, weakening the enemy side further.

**Fix options:**
- Give characters non-zero DEF values so Hex has targets to reduce.
- Redesign Hex to a different debuff (reduce ATK, increase skull damage taken, etc.).
- Replace Hex entirely with an offensive resolve ability.

## Player Side Structurally Stronger

Warrior + Healer (damage + defense/sustain) is a fundamentally stronger archetype pairing than Goblin + Shaman (damage + debuff). The Healer extends fights, giving the Warrior more turns to deal damage. The Shaman's debuffs (especially Hex, see above) often have no effect.

**Consequence:** 81% player win rate is not just a numbers problem — it reflects roster asymmetry. Tuning ATK/HP alone will not close the gap.

**Fix options:**
- Give the enemy side a healing or sustain character.
- Make Shaman's abilities offensively impactful (direct damage, not just debuffs).
- Add DEF to player characters so enemy debuffs matter.
- Design encounters with enemy stat advantages to compensate for weaker synergy.

# Skulls Don't Participate in Matches

## Problem

Skulls are the universal damage mechanic — designed so any character can deal damage regardless of abilities. But in practice, assigning skulls to a character *reduces* their ability to fire abilities (fewer normal dice = fewer matches) while providing negligible damage (ATK=1 on Healer = 1 dmg per skull).

This creates a lose-lose: skulls hurt your match odds AND deal almost no damage. Support characters like the Healer become completely unable to kill anything once their damage-dealing allies die. Games stall into 20+ round slogs with no win condition.

## Observed in Play

Seed 1774894875, tutorial encounter. Warrior died in round 7. Healer survived alone for 9 more rounds (rounds 8-16) dealing a total of 3 skull damage before the player gave up. Healer ATK=1, enemies at 8-11 HP — would take ~30+ rounds to kill one enemy through skulls alone.

## Root Cause

Skulls are *inside* the dice system (assigned to characters, consume slots, require a roll action) but *outside* the interesting part (match detection, [VALUE], enhanced mode). They get all the costs of the system with none of the benefits.

A Healer with 2 d8 + 1 skull: the skull can't match (no face value), so the character effectively rolls 2 normal dice for matching purposes. 2-die match rate is ~11% for d8. Without the skull, 3 d8 would give ~34% match rate. The skull tripled the miss rate.

## Fix: Skulls Roll and Count Toward Matches

Skull dice roll 1-12 (like a d12) and participate in match detection normally. They still deal per-hit ATK damage on every roll. When a skull's rolled value is part of a match group, skull damage becomes ATK + [VALUE].

Full design exploration in `docs/ideas/combat.md` under "Exploring: Skulls roll as d12, participate in matches."

## Impact

- `src/dice.odin`: `character_roll` and `detect_match` — skulls no longer excluded from normal dice pool
- `src/types.odin`: `Roll_Result` — skull tracking changes (skulls now have values)
- `src/character.odin`: `apply_skull_damage` — damage formula changes to ATK + matched [V]
- `src/ability.odin`: all ability procs — skull values now contribute to [MATCHES]/[VALUE]
- `tests/dice_test.odin`, `tests/ability_test.odin` — extensive test updates
- `data/characters/*.cfg` — may need ATK rebalancing since skull damage increases
- AI scoring — skulls become more valuable, AI draft logic needs updating

## Priority

High. This is a game-feel problem that makes the Healer (and any future support character) unplayable in endgame scenarios. The current skull system undermines the core design promise.

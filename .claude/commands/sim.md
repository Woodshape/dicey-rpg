# Sim — Dicey RPG Simulator

> Analyze game balance, investigate ability mechanics, find bugs in combat resolution,
> and use the trace/replay system to reproduce and debug specific games.

## Step 1: Build

Always rebuild before running to pick up any recent changes:

```bash
odin build sim/ -out:build/dicey-sim
```

---

## Step 2: Choose your workflow

### Balance check — is the game fair?

```bash
./build/dicey-sim --rounds=1000 --seed=42
```

Read the output looking for:

| Signal | What it means |
|--------|--------------|
| Player win rate > 70% | Player is too strong |
| Player win rate < 30% | Enemy is too strong |
| Ability fire rate < 10% | Character rarely gets enough assigned dice |
| Ability fire rate > 60% | min_matches threshold may be too low |
| Resolve fires/game < 0.3 | Resolve max is too high or unmatched dice too rare |
| Skull DMG >> Ability DMG | Skull chance may be too high, or ability scaling is too weak |

### Ability-only analysis — isolate mechanics from skull noise

```bash
./build/dicey-sim --rounds=1000 --seed=42 --no-skulls
```

Use when you want to understand how abilities scale without skull damage
interfering. Good for comparing match-scaling vs value-scaling characters,
or checking if a specific ability is over/undertuned in isolation.

### Reproduce + inspect a specific game

```bash
./build/dicey-sim --rounds=1 --seed=42 --trace
```

Writes `game_log.txt` — a full record of every decision and outcome.
Use a fixed seed to get the exact same game repeatedly while investigating.

```bash
# Find a specific round
grep -n "ROUND" game_log.txt

# Look at what happened to a specific character
grep "p0\|e1" game_log.txt
```

### Replay — verify a fix didn't break the game

```bash
# 1. Capture a game before the fix
./build/dicey-sim --rounds=1 --seed=42 --trace
cp game_log.txt game_log_before.txt

# 2. Apply fix and rebuild
odin build sim/ -out:build/dicey-sim

# 3. Replay with same player decisions, AI enemy
./build/dicey-sim --replay=game_log_before.txt
```

The replay drives player picks/rolls from the trace. The enemy remains AI-driven.
At the end, a diff table compares final HP against the original run.

---

## Reading the stats output

```
Warrior | DMG: 42.0 | Ability: 33% | Resolve: 1.2/game | Avg HP: 6.0
  Damage: skull 12.0 + ability 30.0
  Ability "Flurry" (hybrid, min 2): fired 33%, missed 67% (avg 2.1 dice on miss)
  Matches: 0x=67% 2x=33% | Avg[M]: 0.7 | Avg[V]: 6.2
```

- **Ability fired %** — how often the ability triggers per roll
- **avg N dice on miss** — how many dice were assigned on rolls where the ability didn't fire. If this is high (≥3), the character is getting dice but still missing — consider lowering `min_matches`
- **Avg[M]** — average matched dice count. Near 0 for a match-scaling ability = too few dice or wrong die types
- **Avg[V]** — average best match value. Low for a value-scaling ability = character needs higher-face dice
- **skull vs ability split** — if skull damage dominates a non-skull character, the AI is picking skulls it shouldn't, or skull_chance is too high

---

## Reading the trace (game_log.txt)

**Decision lines** — what each side chose:
```
PICK p 3 d8 char 0      # player picked pool slot 3 (d8), assigned to char 0
PICK e 1 d6 hand        # enemy picked pool slot 1 (d6) to hand
ROLL p 0 d8 d8 d8       # player rolled character 0 with 3×d8
ASSIGN p 2 d10 char 1   # player moved hand die to char 1 (free action)
DISCARD p 0 d4          # player discarded hand slot 0
DONE p                  # player finished all rolls this turn
```

**Event lines** — what happened (always in this order per roll):
```
ROLL p 0 d8 d8 d8
VALUES p0 Warrior 5 3 7       # rolled values (skulls omitted)
MATCH p0 Warrior 2 5          # matched_count=2, matched_value=5
SKULL p0 Warrior 1 4 e0 Goblin  # 1 skull hit, 4 damage to Goblin
HP e0 Goblin 11               # Goblin HP after skull
PASSIVE p0 Warrior Tenacity   # passive fired
ABILITY p0 Warrior Flurry DMG 9 e0 Goblin  # main ability fired
HP e0 Goblin 2                # HP after ability
CHARGE p0 Warrior +2 6/10    # 2 unmatched dice → resolve meter now 6/10
RESOLVE p0 Warrior Heroic_Strike DMG 8 e0 Goblin  # resolve fired
HP e0 Goblin 0
DEAD e0 Goblin
```

---

## Finding bugs

### Wrong match detection
Compare VALUES with what MATCH reports:
```
VALUES p0 Warrior 3 3 7    ← two 3s
MATCH p0 Warrior 2 3       ← matched_count=2, matched_value=3  ✓
MATCH p0 Warrior 0 0       ← no match reported despite duplicates  ✗ BUG
```
If MATCH shows 0 when VALUES has duplicates → bug in `detect_match` in `dice.odin`.

### Ability fires when it shouldn't (or vice versa)
Check MATCH `matched_count` against the character's `min_matches` in their `.cfg`:
```
MATCH p0 Warrior 1 5
ABILITY p0 Warrior Flurry ...    ← Flurry needs min 2 matches → BUG
```

### HP not updating correctly
Verify: `HP_before − damage = HP_after`. Use the HP line from before the roll:
```
HP e0 Goblin 15          ← before this roll
ABILITY p0 Warrior Flurry DMG 9 e0 Goblin
HP e0 Goblin 0           ← expected 6, got 0 → BUG
```
Could be wrong target, double-application, or DEF not being subtracted.

### Skull damage wrong
Formula per skull: `max(ATK − effective_DEF, 0)`. Check against the character's stats in their `.cfg`:
```
SKULL p0 Warrior 2 8 e0 Goblin   # 2 skulls × 4 each = 8  (ATK=5, Goblin DEF=1 → 4/hit) ✓
```
If values don't match, check `apply_skull_damage` in `character.odin` and `character_effective_defense` for Hex interactions.

### Resolve meter wrong
CHARGE lines accumulate unmatched dice count. RESOLVE should fire exactly when the meter hits `resolve_max`:
```
CHARGE p0 Warrior +3 7/10
CHARGE p0 Warrior +3 10/10    ← hits max
RESOLVE p0 Warrior Heroic_Strike ...   ← fires next roll ✓
```
If RESOLVE fires before max, or doesn't fire after reaching it → check `resolve_roll` in `combat.odin`.

### Conditions not ticking correctly
COND lines show `remaining` turns. Each round transition should decrement by 1:
```
ROUND 3
COND e0 Goblin Hex 1 2
ROUND 4
COND e0 Goblin Hex 1 1    ← decremented ✓
COND e0 Goblin Hex 1 2    ← same as before → BUG (not ticking)
```
Check `condition_tick_turns` in `condition.odin`.

---

## Targeted one-liners

```bash
# Is Shadow Bolt (Shaman resolve) doing too much damage?
./build/dicey-sim --rounds=2000 --seed=42 | grep -A 10 "Shaman"

# How often does Warrior's Flurry actually fire?
./build/dicey-sim --rounds=1000 --seed=42 | grep -A 8 "Warrior"

# What's the win rate without skull dice?
./build/dicey-sim --rounds=1000 --seed=42 --no-skulls | head -20

# Reproduce round 7 of a specific game
./build/dicey-sim --rounds=1 --seed=42 --trace
grep -n "ROUND" game_log.txt
# then read from the ROUND 7 line forward

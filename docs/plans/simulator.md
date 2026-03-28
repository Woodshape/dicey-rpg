# Combat Simulator

Headless binary that runs N battles with configurable encounters and collects balance statistics. Answers questions like "does 2x Goblin beat Warrior + Healer?" and "how does Smite perform vs Fireball?"

**Depends on:** config system (`docs/codebase/config.md`), headless refactor (`docs/plans/headless-refactor.md`).

---

## Architecture

### Binary

Separate Odin binary in `sim/` that imports `package game`. Raylib is linked (game package depends on it for types like `rl.Color`) but no window is ever opened.

```
sim/
  main.odin       -- CLI parsing, N-game loop, output
  stats.odin      -- per-game stat collection, aggregation
```

### CLI

```
odin run sim/ -- --encounter=tutorial --rounds=1000 --seed=42
odin run sim/ -- --encounter=tutorial --rounds=1000 --no-skulls    # ability-only balance
odin run sim/ -- --combat --seed=42                                # single game with full combat log
```

| Flag | Default | Description |
|------|---------|-------------|
| `--encounter` | `tutorial` | Encounter name, loads `data/encounters/{name}.cfg` |
| `--rounds` | `100` | Number of games to simulate |
| `--seed` | random | RNG seed for reproducibility. If omitted, uses a random seed. The seed is always printed in output so any run can be reproduced. |
| `--csv` | `sim_results.csv` | Output CSV file path |
| `--no-skulls` | `false` | Disable skull dice in the pool. Isolates ability-only balance. |
| `--combat` | `false` | Run 1 game with full combat log to stdout and `combat_log.txt`. Use `--seed` to replay a specific game. |

### No Concurrency

Each game runs sequentially. Simple, deterministic, easy to debug. Revisit if round counts grow large enough to matter.

---

## Headless Game Loop

The simulator drives both sides with AI. No input, no rendering, no display timers.

```
for each round:
    gs = game_init(encounter_name)

    loop:
        switch gs.turn:
        case .Player_Turn:
            ai_take_turn(&gs)          // AI plays player side
        case .Player_Roll_Result:
            clear_roll(...)            // no display timer, resolve instantly
            gs.turn = check_win_lose(gs, .Enemy_Turn)
        case .Enemy_Turn:
            ai_take_turn(&gs)          // AI plays enemy side
        case .Enemy_Roll_Result:
            clear_roll(...)
            gs.turn = check_win_lose(gs, .Player_Turn)
        case .Victory, .Defeat:
            collect_stats(...)
            break loop

        if turn_count > MAX_SIM_TURNS:
            record as draw
            break loop
```

### Key Differences from Live Game

| Aspect | Live game | Simulator |
|--------|-----------|-----------|
| Player input | Mouse/drag-and-drop | AI (`ai_take_turn`) |
| Roll result display | 1.5s timer | Instant (skip timer) |
| Combat log | Ring buffer + file | Disabled |
| Board refill | Same | Same (`check_board_refill`) |
| Win/lose check | Same | Same (`check_win_lose`) |
| Game over | Play Again button | Stats collection, next round |

### Turn Limit

`MAX_SIM_TURNS` (e.g., 200) prevents infinite loops from degenerate AI or heal-stall scenarios. Games exceeding the limit are recorded as draws and flagged in output.

---

## AI for Both Sides

Both player and enemy use `ai_take_turn`. Since `ai_take_turn` is hardcoded to act on `gs.enemy_party`/`gs.enemy_hand`, the simulator uses a **party-swap trick** for the player side:

1. Swap `player_party ↔ enemy_party` and `hand ↔ enemy_hand`
2. Call `ai_take_turn` (AI thinks it's the enemy turn)
3. Swap back
4. Remap turn phases: `.Enemy_Roll_Result → .Player_Roll_Result`, `.Player_Turn → .Enemy_Turn`

This works because abilities use `attacker_party(gs, attacker)` for ally-targeting (not hardcoded `gs.player_party`), and `resolve_roll` only modifies the attacker and target characters directly.

### Future: Strategy Profiles

When strategy profiles are implemented (see `docs/ideas/ai.md`), each side can use a different AI strategy.

---

## Stats Collection

### Per-Game Stats

Collected at game end for each completed round:

```odin
Game_Stats :: struct {
    winner:              Side,           // .Player, .Enemy, .Draw
    turns:               int,            // total turns taken
    player_chars:        [MAX_PARTY_SIZE]Char_Stats,
    enemy_chars:         [MAX_PARTY_SIZE]Char_Stats,
    player_count:        int,
    enemy_count:         int,
}

Char_Stats :: struct {
    name:                cstring,
    damage_dealt:        int,            // total damage (skull + ability)
    damage_taken:        int,
    healing_done:        int,
    ability_fires:       int,            // times main ability triggered
    ability_attempts:    int,            // times character rolled
    resolve_fires:       int,            // times resolve ability triggered
    skull_damage_dealt:  int,
    ability_damage_dealt: int,           // damage from abilities only (excludes skulls)
    hp_remaining:        int,            // at game end (0 if dead)
    alive:               bool,
    die_type_used:       Die_Type,       // committed normal die type (for dice analysis)
}
```

### Stat Collection Points

Stats are collected by hooking into existing game logic — no changes to core procs. The simulator wraps calls and reads state before/after:

| Stat | Where collected |
|------|----------------|
| `damage_dealt` | Snapshot `target.stats.hp` before and after `resolve_roll` |
| `skull_damage_dealt` | Snapshot before/after `apply_skull_damage` (inside `resolve_roll`) |
| `healing_done` | Snapshot `attacker.stats.hp` before/after `resolve_roll` for heal abilities |
| `ability_fires` | Read `attacker.ability_fired` after `resolve_roll` |
| `resolve_fires` | Read `attacker.resolve_fired` after `resolve_roll` |
| `ability_attempts` | Increment on every roll action |
| `turns` | Increment on each turn transition |
| `hp_remaining` | Read at game end |

### Aggregated Output

Computed across all N rounds:

```odin
Aggregate_Stats :: struct {
    rounds:              int,
    player_wins:         int,
    enemy_wins:          int,
    draws:               int,
    avg_turns:           f64,
    // Per-character averages indexed by party position
    avg_damage_dealt:    [MAX_PARTY_SIZE]f64,
    avg_healing_done:    [MAX_PARTY_SIZE]f64,
    ability_fire_rate:   [MAX_PARTY_SIZE]f64,   // fires / attempts
    resolve_fire_rate:   [MAX_PARTY_SIZE]f64,   // fires / rounds
    avg_hp_remaining:    [MAX_PARTY_SIZE]f64,   // when alive at game end
    survival_rate:       [MAX_PARTY_SIZE]f64,   // % of games alive at end
}
```

---

## Output

### Stdout — Human-Readable Summary

```
Encounter: tutorial | Rounds: 1000 | Seed: 42

Results:
  Player wins: 612 (61.2%)
  Enemy wins:  371 (37.1%)
  Draws:        17 ( 1.7%)
  Avg turns:   24.3

Player Party:
  Warrior   | DMG: 48.2 | HEAL: 0.0 | Ability: 72.1% | Resolve: 1.4/game | Survival: 78.3% | Avg HP: 8.2
  Healer    | DMG: 12.1 | HEAL: 18.7 | Ability: 68.5% | Resolve: 1.1/game | Survival: 65.4% | Avg HP: 5.1

Enemy Party:
  Goblin    | DMG: 38.7 | HEAL: 0.0 | Ability: 69.2% | Resolve: 1.2/game | Survival: 41.2% | Avg HP: 3.8
  Shaman    | DMG: 22.4 | HEAL: 0.0 | Ability: 65.8% | Resolve: 0.9/game | Survival: 33.7% | Avg HP: 2.1
```

### CSV — Per-Game Detail

Written to `--csv` path. One row per game, columns for all stats. Enables further analysis in any tool.

```
round,seed,winner,turns,p0_name,p0_dmg,p0_heal,p0_ability_fires,p0_resolve_fires,p0_hp,...
1,42,player,22,Warrior,55,0,3,1,12,...
2,42,enemy,31,Warrior,38,0,2,2,0,...
```

The seed column records the per-game seed (derived from the base seed + round number) for reproducing individual games.

---

## Seeding

- Base seed passed via `--seed`. If omitted, generated randomly and printed.
- Each game derives its own seed: `game_seed = base_seed + round_number`.
- The game's RNG is seeded at the start of each round via Odin's `math/rand` context.
- Per-game seeds appear in the CSV so any individual game can be replayed.

---

## Integration with Config System

The simulator uses `config_load_encounter` from `src/config.odin` — the same loading path as the live game. No separate data format or parsing.

```odin
// sim/main.odin
player_party, enemy_party, ok := config_load_encounter(encounter_name)
if !ok {
    fmt.eprintln("Failed to load encounter:", encounter_name)
    os.exit(1)
}
```

Balance changes to `.cfg` files take effect on the next simulator run — no recompilation.

---

## Simulation Modes

### Default — Full Combat

Standard game with skulls, abilities, and resolve. Measures overall balance.

### `--no-skulls` — Ability-Only

Board generates with `SKULL_CHANCE = 0`. All damage comes from abilities. Isolates the [MATCHES]/[VALUE] mechanic and ability scaling without skull noise. Useful for:
- Comparing ability scaling types (Match vs Value vs Hybrid) head-to-head
- Testing whether a specific die type is strictly dominant for a given ability
- Tuning `min_matches` / `min_value` thresholds

Implementation: the simulator overrides the board's skull chance to 0 before `board_init`. No changes to core game logic.

---

## Dice Mechanics Analysis

The core balance question: how do different die types interact with [MATCHES] and [VALUE] across different ability scaling types?

### Per-Roll Stats

In addition to per-game stats, the simulator collects per-roll data for mechanics analysis:

```odin
Roll_Stats :: struct {
    die_type:        Die_Type,       // what type was rolled
    die_count:       int,            // how many dice in the roll
    matched_count:   int,            // [MATCHES] result
    matched_value:   int,            // [VALUE] result
    unmatched_count: int,            // resolve charge
    ability_damage:  int,            // damage dealt by ability (0 if didn't fire)
    ability_fired:   bool,
}
```

Collected into a `Roll_Collector` (fixed-size array of `Roll_Stats`, heap-allocated) and aggregated into two views:

### Dice Mechanics Table

Aggregated by die type across all rolls. Answers "which die type is best for each scaling axis?"

```
Dice Mechanics:
  Type | Rolls | Avg[M] | Avg[V] | Match% | DMG(match) | DMG(value) | DMG(hybrid) | Resolve/roll
  d4   | 6560  | 0.9    | 3.0    | 43.9%  | 5.4        | 1.5        | 4.2         | 1.6
  d12  | 4036  | 0.3    | 8.4    | 14.2%  | 4.3        | 2.8        | 7.5         | 2.0
```

### Dice Count Breakdown

Cross-tabulated by (die type × normal dice count). Answers "how does rolling 2 vs 3 dice of type X change match quality?"

```
Dice Count Breakdown:
  d4:
    2 dice: 2012 rolls, 25.5% match, avg[M] 0.5, avg[V] 3.1, fire 25.5%, avg dmg 3.0, 1.5 unmatched/roll
    3 dice: 3854 rolls, 61.4% match, avg[M] 1.3, avg[V] 3.0, fire 61.4%, avg dmg 3.5, 1.7 unmatched/roll
  d12:
    2 dice: 1513 rolls, 8.4% match, avg[M] 0.2, avg[V] 8.6, fire 8.4%, avg dmg 4.5, 1.8 unmatched/roll
    3 dice: 1908 rolls, 23.4% match, avg[M] 0.5, avg[V] 9.0, fire 23.4%, avg dmg 3.6, 2.5 unmatched/roll
```

This is the primary balance tool — it shows the match probability curve per die count per type, enabling direct comparison of strategies (roll early with few dice vs fill to capacity).

### Per-Character Detail

Below each character's summary line, expanded stats show:
- **Damage breakdown:** skull + ability damage per game
- **Ability info:** name, scaling, threshold, fire/miss rate, avg dice on miss
- **Match histogram:** distribution of 0x, 2x, 3x... matches, plus avg [M] and [V]
- **Resolve stats:** fires/game, avg rolls to fill, unmatched/roll

---

## Future Extensions

- **Strategy profiles** — swap `ai_take_turn` per side with different AI strategies (skull rush, match builder, value seeker, denier). See `docs/ideas/ai.md`.
- **Per-roll CSV** — write every roll to a separate CSV for external analysis (not yet implemented).
- **DPT (damage per turn)** — track turns spent picking per character to compute effective damage per turn, not just per roll.
- **Carry analysis** — win rate when character survives vs dies, showing which characters are load-bearing.
- **Batch encounters** — run multiple encounters in one invocation, output a comparison table.
- **Automated balance testing** — script that tweaks `.cfg` values and runs the simulator repeatedly, looking for win rate convergence.

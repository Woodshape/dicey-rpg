# Draft Pool — Board Replacement

**Status:** Design Draft
**Replaces:** Board grid (`src/board.odin`, `docs/codebase/board.md`)

---

## Motivation

The board's spatial mechanics (perimeter picks, ring exposure, rarity gradient) don't create enough meaningful decisions relative to their complexity. The core fun is in the *drafting* — what you pick, what you deny, and how you route dice to characters. The board grid adds spatial overhead without deepening those choices.

The draft pool strips the system down to pure drafting: a visible pool of dice, alternating picks, full denial. Simpler to understand, faster to play, and easier to balance.

---

## Core Flow

The game is structured as repeating **rounds**. Each round has two phases:

```
ROUND
  1. DRAFT PHASE   — both sides pick dice from a shared pool
  2. COMBAT PHASE   — both sides assign dice and roll characters
```

Rounds repeat until one side is eliminated (all characters dead).

### Draft Phase

1. A pool of **N dice** is generated (default: 6).
2. All dice in the pool are **fully visible** (type shown) to both sides.
3. Sides alternate picking one die at a time (**strict alternation**).
4. First pick alternates each round (player first in round 1, enemy first in round 2, etc.).
5. Picked dice go into the side's **hand** (same hand system as current).
6. **Free actions during draft:** Assignment (hand ↔ characters) and discard are available during each pick turn. This prevents hand-full deadlocks — if the hand is full when it's your pick, you can assign or discard to make room.
7. The pool is **fully drafted** — no dice remain after the draft phase.

### Combat Phase

1. Both sides can **freely assign** dice from hand to characters at any time (no action cost, as current).
2. Sides **alternate turns**, same as the old system. On your turn you can assign freely and **roll** one character to end your turn, or **pass** to end the round.
3. Roll resolution is unchanged: skull damage (per-hit loop), ability triggers, resolve meter.
4. A roll ends your turn and passes to the other side (same as a pick did in the old system).
5. A **pass** ends the round immediately — no waiting for the other side to also pass. This keeps the pacing snappy: if you have nothing to roll, you end the round.
6. After the round ends, a new draft phase begins.

---

## Pool Composition

### Size

**Default: 6 dice per round** (3 picks per side with strict alternation).

Pool size is configurable — encounters or future mechanics can vary it. The pool size must be even to ensure equal picks for both sides.

### Rarity Distribution — Weight Groups

Each draft round draws from a **weight group** that biases the pool toward certain die types. Four weight groups exist:

| Group | Primary Types | Bias |
|-------|--------------|------|
| 1 | d4, d6 | Low risk, high consistency |
| 2 | d6, d8 | Balanced-low |
| 3 | d8, d10 | Balanced-high |
| 4 | d10, d12 | High risk, high reward |

The weight group sets the **bias, not a hard lock**. A "d8/d10 round" is mostly d8 and d10, but a d6 or d12 can still appear.

Exact weight curves TBD — start with something similar to the board's gradient weights, parameterised by group instead of ring depth.

### Weight Group Cycling

Weight groups cycle in a **shuffled non-repeating** order:

1. At the start of a fight, shuffle the 4 weight groups into a random order.
2. Each draft round uses the next group in the sequence.
3. After all 4 groups have been used, reshuffle and start a new cycle.
4. Repeat until the fight ends.

This ensures variety (you'll see every group) while keeping the order unpredictable. Both sides can anticipate that a high-value round is *coming* but not *when* — creating a tension around hand management and timing.

### Skull Dice

Skull dice appear at a **percentage chance per die** in the pool (same as current `SKULL_CHANCE`). A die is checked for skull before the weight group distribution is applied — if it's a skull, it's a skull regardless of the round's weight group.

Configurable per encounter. Default: `SKULL_CHANCE = 10%`.

---

## What Changes

### Removed

- **Board grid** — no more `Board`, `Board_Cell`, `cell_ring`, `cell_is_pickable`, perimeter logic.
- **Spatial exposure/denial** — picking a die no longer reveals hidden inner dice.
- **Ring-based rarity gradient** — replaced by weight group cycling.
- **Board rendering** — replaced by pool rendering (simpler).

### Preserved

- **Hand system** — unchanged. Dice go from pool to hand, hand to characters.
- **Pure type constraint** — characters still hold one normal die type + skulls.
- **Drag-and-drop** — picking from the pool is still a drag operation.
- **Skull mechanics** — skull dice behave identically once drafted.
- **Pick denial** — what you take, the opponent can't have. This is the core interaction.
- **AI drafting** — the AI still scores dice and picks optimally. Scoring logic adapts from board scanning to pool scanning.
- **Free assignment and discard** — available during both draft picks and combat turns, same as today.

### Simplified

- **No perimeter calculation** — all dice in the pool are always pickable.
- **No board refill timing** — a fresh pool appears every round automatically.
- **No ring depth math** — weight groups replace spatial gradient.
- **Combat phase is nearly identical to current** — just without the pick action. Alternating turns, free assignment, roll or pass.

---

## Assign + Roll Phase

### Current Design (v1)

After drafting, sides alternate combat turns. On each turn, the active side can assign freely and either roll one character or pass. This preserves the current turn-by-turn tactical feel — killing a target before their roll matters.

Assignment is free (no action cost). Rolling consumes the character's assigned dice. When both sides pass consecutively, the round ends.

### Design Space: Phase Structure Alternatives

The current design (v1) uses a **hybrid** approach: strict alternating picks during draft, then the combat phase works like the old turn system (pick-or-roll is replaced by roll-or-pass, with free assignment).

Other options explored:

- **Merged phases (Option 1).** On your turn, you can pick from the pool OR roll — same as the old board system, just with a pool instead of a board. Pool refills when empty, triggering a new round. Simplest to understand, but loses the "draft all then fight" structure and the strategic tension of committing to a full draft before fighting.

- **Strict split with strong UI (Option 2).** Keep draft and combat as completely separate phases, but invest heavily in visual clarity: big phase banners, dim the pool during combat, dim characters during draft, explicit "Pick a die!" / "Roll or Pass!" instructions. Preserves the batch design intent but requires more UI polish to feel intuitive.

These are worth revisiting if the hybrid approach doesn't feel right after playtesting.

### Design Space: Simultaneous Rolls with Targeting

A richer model worth exploring after v1:

1. **Targeting:** Before rolling, each side chooses which of their characters **faces** which enemy character. This is the strategic decision — a tank might face the enemy's damage dealer, or you might focus-fire a weak target.

2. **Simultaneous rolls:** Both sides roll at the same time. No alternation — all characters resolve in parallel.

3. **Initiative from roll results:** The roll result ([MATCHES], [VALUE], or a derived stat) determines which side in each matchup **acts first**. Higher initiative means your ability fires before the opponent's — potentially killing them before they can respond.

This transforms the combat phase from "take turns rolling" into a simultaneous commitment game where the *matchup decisions* are the strategic layer and the *roll results* determine execution order. It rewards:
- Reading the opponent's draft (what did they pick? which character are they building?)
- Counter-targeting (assigning your best roll against their weakest character)
- Risk assessment (a high-VALUE roll might win initiative but miss on matches)

**Not for v1.** Document here as the target design space for future iteration.

---

## Configuration

All pool parameters should be easily configurable for balance tuning:

| Parameter | Default | Scope |
|-----------|---------|-------|
| `pool_size` | 6 | Per encounter or global |
| `skull_chance` | 10% | Per encounter or global |
| Weight group curves | TBD | Global (tunable weights per group) |
| First-pick side | Alternating | Per round |

Encounter configs could override pool parameters:

```
# data/encounters/tutorial.cfg
pool_size = 6
skull_chance = 10

[player]
- warrior
- healer

[enemy]
- goblin
- shaman
```

---

## Open Questions

- **Variable pool size per round?** Could some rounds have 4 dice and others 8, adding resource pressure. Weight group could influence pool size (low-tier groups = more dice, high-tier = fewer).
- **Hand overflow between rounds.** If a character didn't roll last round, their assigned dice persist. Combined with new draft picks, the hand can fill up. Current discard mechanic handles this, but it may need tuning. Free assignment during draft picks mitigates this significantly.
- **Ability-driven draft manipulation.** Passive abilities or conditions that affect the draft phase: pick two dice, swap a picked die with one in the pool, see the next round's pool in advance, force the opponent to pick first. Rich design space, depends on ability system evolution.
- **Pool size scaling with party size.** 6 works for 2v2. A 3v3 or 4v4 might need a larger pool. Could derive from total alive characters.
- **Weight group visibility.** Should the current round's weight group be shown to both sides? Full information is consistent with the "all dice visible" principle. Or is the group implicit from seeing the dice?

---

## Implementation Impact

### Files Affected

| File | Change |
|------|--------|
| `src/board.odin` | **Replace** — becomes `src/pool.odin` (pool generation, weight groups, rendering) |
| `src/types.odin` | Replace `Board`, `Board_Cell` with `Draft_Pool` struct. Add weight group types. Remove ring/perimeter constants. |
| `src/combat.odin` | Rework turn state machine: draft phase with alternating picks, then combat phase with alternating roll turns. |
| `src/game.odin` | Update `Game_State` (pool replaces board), update drag-and-drop (pool as drag source), update draw pipeline. |
| `src/ai.odin` | Adapt scoring from board scanning to pool scanning. Simpler — no perimeter checks. |
| `src/config.odin` | Add pool parameters to encounter config. |
| `docs/codebase/board.md` | **Replace** with `docs/codebase/pool.md`. |
| `tests/board_test.odin` | **Replace** with `tests/pool_test.odin` (weight group distribution, pool generation, cycling). |

### State Machine Rework

Current:
```
Player_Turn → Player_Roll_Result → Enemy_Turn → Enemy_Roll_Result → ...
```

New:
```
Draft_Player_Pick → Draft_Enemy_Pick → ... (repeat until pool empty)
    → Combat_Player_Turn → Player_Roll_Result → Combat_Enemy_Turn → Enemy_Roll_Result → ...
    → Round_End → Draft_Player_Pick (new round)
```

The combat phase is structurally identical to the current system — alternating turns with free assignment — just without the pick action. The draft phase is a new sub-loop prepended to each round.

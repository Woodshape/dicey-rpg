# Board Ideas

## Board Size

- What square grid size feels right? Options: 5×5 (25 tiles), 7×7 (49 tiles), or something else.
- Should board size scale with the number of combatants? Larger parties = more tiles to prevent early depletion.
- Currently configurable via constant — needs playtesting to settle on a default.

## Refill Timing

- When does the board refill? Options:
  - After each pick (always full)
  - At the start of a new round
  - When depleted below a threshold
- Refill timing affects how often the exposure dilemma resets and how much denial matters late in a game.

## Refill Placement

- Do new dice always fill the outer ring, or can they appear anywhere on the board?
- Filling only the outer ring preserves the rarity gradient but may make the board feel predictable.
- Filling anywhere could create sudden inner-ring access and disrupt strategy.

## Partial Exposure

- If only some tiles in a ring are cleared, does that expose only those inner neighbours, or does the whole next ring become accessible?
- Current implementation: only neighbours of removed tiles are exposed.
- Full-ring unlock would be simpler but removes tactical positional play.

## Die Distribution

- Is die placement on the board purely random within each ring, or weighted/seeded per encounter for balance?
- Purely random means some boards could have extreme clustering (all d4s on one side).
- Encounter-seeded distribution could ensure fairer starting boards without feeling deterministic.

## Skull Dice Distribution

- Skull dice currently placed at a fixed SKULL_CHANCE% per cell across all rings.
- No design decision yet on whether skulls should cluster, avoid the centre, or remain uniform.
- A fixed count per board fill (e.g., always exactly 4 skulls) may be more predictable than per-cell RNG.

## Draft Pool (Alternative to Board)

Replace the central board grid with a simpler draft pool model:

- Each round, a fixed number of dice are presented to both sides (drawn from a distribution).
- Both parties pick from the shared pool in alternating turn order: player → enemy → player → enemy → etc., until all dice are picked.
- This removes the spatial exposure/denial mechanic (no perimeter, no rings) but preserves the core drafting tension: what you pick denies the other side.
- Simplifies the visual and interaction model — no grid, no adjacency, no ring unlocking.

### Open questions

- Do both sides assign and roll AFTER all dice are picked (batch phase), or can rolls happen in between picks (interleaved)?
- Batch: cleaner separation of draft and combat phases. Both sides see the full draft before committing rolls. Strategic: you can adjust assignment after seeing what the opponent drafted.
- Interleaved: more tactical, allows mid-draft rolls as tempo plays. Harder to balance — early rollers might get wiped before late drafters finish building.
- How many dice per round? Should scale with party size.
- Does the pool have the same rarity gradient (more d4/d6, fewer d10/d12), or a flatter distribution?
- How do skull dice fit — fixed count per pool, or percentage-based?

This is a design space exploration, not a committed direction. The board works mechanically but may be overengineered for the drafting decisions the game actually needs.

# Combat Issues

## Multiple Match Groups as Separate Activations

- Currently: all matched dice across groups are pooled into a single [MATCHES]/[VALUE] pair. A roll of `[4, 4, 2, 2, 5]` fires one ability with [MATCHES]=4, [VALUE]=4.
- Alternative: each distinct match group activates the ability independently. That roll would fire twice: ([MATCHES]=2, [VALUE]=4) and ([MATCHES]=2, [VALUE]=2).
- This rewards spreading matches and gives multi-group rolls a distinct identity from single large groups.
- Requires `Roll_Result` to hold a list of (matched_count, matched_value) pairs and the resolution loop to iterate over them.
- Deferred until the ability system has been tested in play. Meaningful structural change to both data model and resolution pipeline.

## Resolve Meter Charge Rate

- Currently: each unmatched die adds a flat charge.
- Options:
  - Flat per unmatched die (simple, current)
  - Scaled by die type (d12 charges more than d4 — rewards risk-taking)
  - Scaled by rolled value (higher rolls that still miss charge more)
- The design intent is that d12 builds charge resolve faster on misses (~3.5 avg unmatched vs ~1.6 for d4). A flat rate partially captures this. Scaling by type would make it more explicit.

## Party Death

- When a character dies, what happens to their assigned dice?
- Options:
  - Dice are discarded (lost)
  - Dice return to the owner's hand (if space allows)
  - Dice are placed back on the board
- Unresolved. Has implications for late-game hand pressure when party members are dying.

## Disruption Ability Interactions

- How do status effects like Paralyze interact with dice already loaded on a character?
- Does Paralyze prevent rolling? Block assignment? Both?
- Does Freeze (on a hand die) prevent it from being assigned or discarded?
- Rules for each status effect need to be specified before implementation. See `status-effects.md`.

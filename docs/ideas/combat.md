# Combat Ideas

## Multiple Match Groups as Separate Activations

- Currently: all matched dice across groups are pooled into a single [MATCHES]/[VALUE] pair. A roll of `[4, 4, 2, 2, 5]` fires one ability with [MATCHES]=4, [VALUE]=4.
- Alternative: each distinct match group activates the ability independently. That roll would fire twice: ([MATCHES]=2, [VALUE]=4) and ([MATCHES]=2, [VALUE]=2).
- This rewards spreading matches and gives multi-group rolls a distinct identity from single large groups.
- Requires `Roll_Result` to hold a list of (matched_count, matched_value) pairs and the resolution loop to iterate over them.
- Meaningful structural change to both data model and resolution pipeline. Best evaluated after playtesting the current system.

## Resolve Meter Charge Rate

- Currently: each unmatched die adds a flat charge.
- Options:
  - Flat per unmatched die (simple, current)
  - Scaled by die type (d12 charges more than d4 — rewards risk-taking more explicitly)
  - Scaled by rolled value (higher rolls that still miss charge more)
- The design intent is that d12 builds charge resolve faster on misses (~3.5 avg unmatched vs ~1.6 for d4). A flat rate partially captures this naturally. Scaling by type would make it more deliberate.

## Ability Trigger Conditions — min_value

- Currently: abilities trigger when `matched_count >= min_matches`. The `min_value` field is reserved in the config schema but not yet wired into the trigger check in `handle_abilities`.
- When activated, the trigger condition becomes: `matched_count >= min_matches AND matched_value >= min_value`.
- This enables abilities that only fire on high-face-value rolls (e.g. a d10/d12 build that requires [VALUE] >= 8), creating more specialised characters.
- Both conditions default to 0 in config (always trigger), so existing characters need no changes.
- Implementation: add `min_value` to the `Ability` struct, update `handle_abilities` trigger check, update `Ability_Scaling` descriptions.

## Party Death — Assigned Dice

- When a character dies, what happens to their assigned dice?
- Options:
  - Dice are discarded (lost — punishes overcommitting to a dying character)
  - Dice return to the owner's hand (if space allows — softens the loss)
  - Dice are placed back on the board (creates a windfall for either side)
- Has implications for late-game hand pressure when party members are dying.

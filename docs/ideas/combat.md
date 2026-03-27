# Combat Ideas

## Resolve Ability Scaling

- Currently: all resolve abilities use `scaling = none` (flat effects). This is correct because resolve fires from *unmatched* dice — the roll that fills the meter almost never has strong [MATCHES] or [VALUE] numbers.
- The only scenario where a roll has both a match AND fills resolve: e.g., 3 dice, 2 match, 1 unmatched pushes meter to max. The resolve ability would see `matched_count=2` — possible but the numbers are always small.
- If resolve abilities should ever scale, they'd want a different axis than [MATCHES]/[VALUE]:
  - **Overflow amount** — how far over `resolve_max` the meter went (rewards banking unmatched dice)
  - **Total resolve earned this game** — rewards characters that consistently miss matches
  - **Current HP deficit** — desperate comeback mechanic
  - **Number of alive allies/enemies** — situational power
- Any of these would require adding a new scaling axis to the ability system, not reusing the existing two.
- For now, flat resolve abilities are the right default. Revisit if playtesting reveals resolve feels too static.

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

## Simulator Balance Stats — Future Extensions

- **Damage per turn (DPT):** Characters spend multiple turns picking before rolling once. DPT = total damage / total turns (including pick turns) would show effective throughput, not just per-roll burst.
- **Carry analysis:** Win rate when a specific character survives vs dies. Shows which characters are load-bearing vs expendable. Requires per-game correlation between character survival and game outcome.
- **Roll timing analysis:** When does the AI choose to roll — with 1, 2, or 3 dice? The dice count breakdown already shows match rates by count, but tracking *why* the AI rolled (full, no picks, forced) would help evaluate strategy profiles.

## Party Death — Assigned Dice

- When a character dies, what happens to their assigned dice?
- Options:
  - Dice are discarded (lost — punishes overcommitting to a dying character)
  - Dice return to the owner's hand (if space allows — softens the loss)
  - Dice are placed back on the board (creates a windfall for either side)
- Has implications for late-game hand pressure when party members are dying.

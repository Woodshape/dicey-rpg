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

## Skull Design Concerns

Skulls are currently "guaranteed value" — they always deal ATK damage on roll, regardless of match quality. Ability dice are "uncertain value" — they need matches to fire, and bad rolls waste them. This creates a dominant strategy of picking skulls over ability dice whenever possible.

### Rejected: Skulls as direct board actions

Picking a skull immediately deals damage — no assignment, no slot, no roll. Rejected because there's no strategic decision: you'd always pick every skull (free damage, no opportunity cost, no denial tradeoff).

### Rejected: Remove skulls from character slots

Skulls tracked separately (per-character or per-party), don't occupy ability dice slots. Rejected because it removes the drafting tension between skull damage and ability dice entirely.

### Exploring: Skulls roll as d12, participate in matches

Instead of being blank fixed-damage dice, skulls roll as d12 and their value counts toward match detection like any normal die. This transforms skulls from "dead weight in the match system" into "high-risk match participants."

Rules:
- Skull dice roll 1-12 (same as d12) and participate in match detection normally.
- Skull dice still deal ATK damage per skull per roll (the per-hit loop).
- Skull damage becomes ATK + [VALUE] when the skull's rolled value is part of a match group. This rewards mixing skulls with normal dice — a skull that matches amplifies both the ability (via [MATCHES]) AND its own damage (via [VALUE]).
- Skulls remain exempt from the pure type constraint.

What this changes:
- **Skulls enhance matches instead of competing with them.** A Healer with 2 d8 + 1 skull has a *better* chance of matching (3 dice in the match pool instead of 2) AND deals skull damage.
- **Skull damage scales with roll quality.** A skull that matches at [V]=9 deals ATK+9 instead of just ATK. A skull that doesn't match deals ATK+0 = ATK (same as current). High-value matches are rewarded, misses are unchanged.
- **Mixed builds become viable.** Currently you either stack ability dice (for matches) or stack skulls (for fixed damage), never both. With matching skulls, a 2 normal + 1 skull build gets 3-die match odds plus skull damage — best of both worlds, at the cost of a lower [VALUE] ceiling from fewer normal dice setting the match group.
- **The d12 roll range creates a natural tension.** Skulls as d12 have the worst match probability (1/12 per face) but the highest [VALUE] ceiling. They're the ultimate gamble die — low chance of matching, devastating when they do.
- **Pure skull builds become interesting.** 3 skulls = 3 d12 rolls in the match pool. Match probability for 3 d12s is ~24%. When it hits, every skull deals ATK + [V]. When it misses, just ATK per skull (same as current). Risk/reward aligned with the d12 identity.

Open questions:
- Does skull [VALUE] contribute to the ability's [VALUE] calculation? (If a skull matches at 10 and a d6 matches at 4, is [VALUE] = 10?)
- Does this make skulls strictly better than d12? (Same roll range, plus ATK damage, plus type-agnostic.) Maybe skulls should roll as d8 or d10 instead to create a tier gap.
- How does this interact with enhanced mode? A skull matching at [V]>=8 would trigger piercing — is that intended?

### Other options discussed

- **Skull damage tied to match quality:** skull ATK = base ATK + (matched_count / 2). Simpler than full match participation but less interesting — skulls still don't *contribute* to matches, they just benefit from them passively.
- The per-hit loop design space (on-hit passives, damage shields, lifesteal) is valuable and works with any skull model.

The slot competition problem is also related to the "Last-Resort Roll Deadlock" issue in issues/ai.md — skulls crowding out ability dice is the root cause of that deadlock scenario.

## Party Death — Assigned Dice

- When a character dies, what happens to their assigned dice?
- Options:
  - Dice are discarded (lost — punishes overcommitting to a dying character)
  - Dice return to the owner's hand (if space allows — softens the loss)
  - Dice are placed back on the board (creates a windfall for either side)
- Has implications for late-game hand pressure when party members are dying.

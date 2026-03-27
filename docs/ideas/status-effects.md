# Status Effects Ideas

## Status Effect Architecture

- No status effect system currently exists. Paralyze (Milestone 8) will be the first.
- Needs a general representation: `Status_Effect` struct with type, remaining duration, and any associated value.
- Characters need a slot (or list) to hold active status effects.
- Resolution order: when do effects tick down? Start of turn, end of turn, or on roll?
- Stack behaviour: can multiple instances of the same effect accumulate, or is it binary?

## Paralyze

- First status effect — proof of concept to validate the architecture.
- Design questions before implementing:
  - Does Paralyze prevent rolling?
  - Does it prevent assignment of new dice?
  - Does it affect skull dice hits too, or only ability rolls?
  - Does it last N turns or until cleansed?

## Freeze (Hand Disruption)

- Freeze locks a die in the enemy's hand so it cannot be assigned for N turns.
- A frozen die also cannot be discarded — this is what makes it punishing (clogs hand slots with no escape).
- Freeze is the explicit blocker that makes the discard escape valve unavailable.
- Duration and application method (ability, board event, or both) TBD.

## Hand Disruption Abilities

Ability effects that target the enemy's hand. All resolve immediately on trigger — not persistent status effects. Already enabled by the full `Game_State` context passed to ability procedures.

- **Steal:** Take a die from the enemy's hand into yours. Denies their build and advances yours.
- **Destroy:** Remove a die from the enemy's hand entirely. Pure denial.
- **Downgrade:** Replace a die in the enemy's hand with the next smaller type (e.g., d12 → d8). Weakens their [VALUE] ceiling.
- **Upgrade:** Replace a die in your own hand with the next larger type (e.g., d6 → d10). Costs an action but boosts [VALUE].
- **Corrupt:** Turn a normal die into a skull die in the enemy's hand. Forces base damage when they wanted ability dice.

## On-Hit Status Application

- The per-hit skull damage loop creates a natural hook for status effects applied on hit.
- "Each hit has a X% chance to apply Poison/Stun/Burn" — more skulls = more chances to proc.
- This gives skull-heavy builds a distinct identity beyond raw damage output.
- Needs the status effect architecture to exist first.

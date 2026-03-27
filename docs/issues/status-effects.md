# Status Effects Issues

## Paralyze (Milestone 8 — Proof of Concept)

- Paralyze is the first status effect to implement as a proof of concept.
- Design not yet fully specified. Needs answers to:
  - Does Paralyze prevent the character from rolling?
  - Does it prevent assignment of new dice?
  - Does it last N turns, or until cleansed?
  - Does it affect skull dice hits too, or only ability rolls?
- Should be simple enough to validate the status effect architecture without building a full system.

## Freeze (Hand Disruption)

- Freeze locks a die in the enemy's hand so it cannot be assigned for N turns.
- A frozen die also **cannot be discarded** — this is what makes it punishing (it clogs hand slots with no escape).
- Interaction with discard is the key design point: Freeze is the blocker that makes discard not always available.
- Duration and application (ability, board event, or both) TBD.

## Status Effect Architecture

- No status effect system currently exists. Paralyze is the first to require one.
- Needs a general representation: `Status_Effect` struct with type, remaining duration, and any associated value.
- Characters need a slot (or list) to hold active status effects.
- Resolution order: when do effects tick down? Start of turn, end of turn, or on roll?
- Stack behaviour: can multiple Paralyze stacks accumulate, or is it binary (either paralyzed or not)?

## Other Planned Disruption Effects

Design space from `core-mechanics.md` — not yet scheduled, but the architecture should accommodate them:

- **Steal:** Take a die from the enemy's hand into yours.
- **Destroy:** Remove a die from the enemy's hand entirely.
- **Downgrade:** Replace a die in the enemy's hand with the next smaller type.
- **Upgrade:** Replace a die in your own hand with the next larger type.
- **Corrupt:** Turn a normal die into a skull die in the enemy's hand.

These are ability effects, not persistent status effects — they resolve immediately on trigger. The hand needs to be a writable target from ability procedures (already enabled by full `Game_State` context passing).

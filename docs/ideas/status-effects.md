# Status Effects Ideas

## Status Effect Architecture

The condition system is implemented (`src/condition.odin`). `Condition` struct with kind, value, expiry model (Turns/On_Hit_Taken), interval/timer for periodic effects. Characters hold up to `MAX_CONDITIONS` (4) active conditions. Shield and Hex are live; periodic effects (Poison, Regen) have the hook point (`condition_fire_periodic`) but no implementations yet. See `docs/codebase/condition.md` for full details.

### Condition Design Rule

Conditions are **shared, reusable game mechanics** — effects that multiple abilities and passives can apply, and that other systems can interact with (Curse Weaver counts conditions, Shield absorbs from any damage source, Hex stacks from multiple casters).

**Do NOT create per-ability Condition_Kinds.** If a passive or ability needs a temporary stat buff that only it uses, the effect should be applied directly (heal HP, deal damage) or use a stat modifier field on Character — not a new Condition_Kind. The test: "would a second ability ever apply this same condition?" If not, it shouldn't be a condition.

Good conditions: Shield, Hex, Poison, Burn, Freeze, Stun — shared effects with clear mechanics.
Bad conditions: Iron_Skin_Buff, Battle_Rage_Buff, Scavenger_Mark — per-ability state that nothing else interacts with.

See also `docs/ideas/passives.md` for the passives-vs-conditions design rule.

### Remaining design questions for future conditions:

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

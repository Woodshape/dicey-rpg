# TODOs — Ability System

## Passive ability system

**Files:** `src/types.odin:214`, `src/character.odin:495`

The `Character` struct has a commented-out `passive: Ability` field and the draw proc has a placeholder comment. The passive ability slot is reserved in the inspect overlay UI but has no runtime wiring.

**What needs doing:**
- Uncomment `passive: Ability` in the `Character` struct (`types.odin`)
- Define `Ability_Passive` proc type (or reuse `Ability_Effect`) — passives fire on a trigger, not a roll
- Decide trigger model: per-turn, on-hit, on-assign, on-death, etc.
- Wire passive into `resolve_roll` or a new `apply_passives` call
- Add passive templates to character creation procs in `ability.odin`
- Update inspect overlay to show passive description dynamically

**Blocked by:** passive trigger design — see `docs/ideas/status-effects.md` for related design space.
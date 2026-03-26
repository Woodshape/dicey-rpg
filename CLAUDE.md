# Dicey RPG

A turn-based dice-drafting RPG built with Odin and Raylib.

## Project Structure

```
src/                    -- all game source (single package: "game")
  main.odin             -- entry point, window, game loop
  game.odin             -- game state struct, update/draw, drag-and-drop logic
  types.odin            -- shared types, enums, constants
  board.odin            -- board grid, rarity gradient, perimeter logic
  dice.odin             -- dice rolling, match detection (pure logic)
  hand.odin             -- hand management (max 5 dice)
  character.odin        -- character structs, assignment, roll state, UI
  combat.odin           -- turn state machine, action resolution (planned)
  ai.odin               -- enemy drafting heuristics (planned)
tests/                  -- test package (separate from game)
  board_test.odin       -- board ring, perimeter, removal, gradient tests
  hand_test.odin        -- hand capacity, removal, vacated slot tests
  character_test.odin   -- assignment, type constraint, rarity, state tests
  dice_test.odin        -- match detection for all patterns, edge cases, invariants
assets/                 -- placeholder assets
docs/
  design/core-mechanics.md   -- game design document (source of truth for mechanics)
  implementation-plan.md     -- milestone-based implementation plan
```

All `src/` files share `package game`. Tests live in `tests/` as a separate package.

## Build & Run

```bash
# Build and run
odin run src/ -out:build/dicey-rpg

# Build only
odin build src/ -out:build/dicey-rpg

# Run tests
odin test tests/

# Debug build
odin run src/ -out:build/dicey-rpg -debug
```

## Architecture

- **Single game state struct** passed by pointer — no globals.
- **Structs + procedures** as the primary pattern.
- **State machine** (enum + switch) for turn flow in `combat.odin`.
- **Abilities** as procedure pointers in structs — modular, easy to extend.
- **Match detection** as a pure function: input = rolled values, output = best pattern + matched value + matched/unmatched counts.
- **Drag-and-drop** for all dice movement. No click-to-select. Drag source is ghosted, die follows cursor, valid targets glow green.
- **Raylib** imported as `rl`: `import rl "vendor:raylib"`.

## Odin Conventions

Follow these strictly across all source files:

### Naming

- **snake_case** for variables, procedure names, and parameters: `roll_dice`, `match_result`, `board_size`
- **Pascal_Case** for types and structs: `Game_State`, `Die_Type`, `Board_Cell`
- **SCREAMING_CASE** for constants: `MAX_HAND_SIZE`, `BOARD_WIDTH`
- Enum values use Pascal_Case: `Die_Type.D4`, `Character_Rarity.Epic`
- Keep names descriptive but concise. Avoid abbreviations except widely understood ones (HP, AI, UI).

### Procedures

- All parameters are immutable by default. Shadow with `x := x` if mutation is needed.
- Use named return values for clarity when returning multiple values.
- Use `or_return` for error propagation: `result := try_something() or_return`
- Prefer explicit `return` over bare returns except in very short procedures.

### Memory

- Use `defer` for cleanup: `defer delete(dynamic_array)`
- All dynamic arrays and maps must have a matching `delete()`.
- Use the context allocator system — do not call malloc/free directly.
- Prefer stack allocation (fixed arrays, structs by value) over heap where possible.

### Error Handling

- Return `(T, bool)` or `(T, Error)` tuples for operations that can fail.
- Use `or_return`, `or_continue`, `or_else` for concise error handling.
- No exceptions — handle errors explicitly at call sites.

### Raylib API

- Raylib uses **PascalCase** in Odin bindings (matches C API): `rl.InitWindow()`, `rl.BeginDrawing()`, `rl.DrawRectangle()`
- Colours are constants: `rl.RAYWHITE`, `rl.RED`, `rl.DARKGRAY`
- Always alias import: `import rl "vendor:raylib"`

### Code Style

- No forward declarations needed — Odin resolves within a package.
- Use `when` for compile-time conditionals (platform checks, debug features).
- Use `#partial switch` when intentionally not covering all enum cases.
- Switches do NOT fall through by default. Use `fallthrough` explicitly if needed.
- Visibility: everything is public by default. Use `@(private)` for package-private, `@(private="file")` for file-private.
- Keep procedures short. Extract logic into well-named helpers when a procedure exceeds ~50 lines.

## Testing Strategy

Validate core game logic with meaningful test cases. No test flooding — focus on the subsystems where correctness matters most.

### What to Test

- **Match detection** (`dice.odin`): the heart of the game. Test every pattern (Pair through Five of a Kind), edge cases (no match, all same, multiple groups), and "best pattern" selection from ambiguous rolls.
- **Board logic** (`board.odin`): rarity gradient correctness, perimeter calculation, tile removal exposing inner tiles.
- **Hand management** (`hand.odin`): capacity enforcement (max 5), pure die type constraint on character assignment.
- **Ability resolution** (`character.odin`): correct scaling (match-based, value-based, hybrid), super meter charging from unmatched dice.

### What NOT to Test

- Rendering / UI code (visual verification only).
- Raylib wrapper calls.
- Trivial getters or struct construction.

### Test Style

```odin
package tests

import "core:testing"

@(test)
match_pair :: proc(t: ^testing.T) {
    result := detect_match({3, 7, 3, 11, 5})
    testing.expect_value(t, result.matched_value, 3)
    testing.expect_value(t, result.matched_count, 2)
    testing.expect_value(t, result.unmatched_count, 3)
}
```

- One `@(test)` procedure per meaningful scenario.
- Use `testing.expect_value` for comparisons (auto-generates mismatch messages).
- Use `testing.expectf` when custom failure messages aid debugging.
- Name tests descriptively: `match_full_house`, `board_perimeter_after_removal`, `hand_rejects_mixed_types`.

### Data Integrity

Any operation that removes, shifts, or reorders elements in a fixed-size array **must** be tested for stale data in vacated slots. This is critical because:

- Odin zero-initializes memory, so stale values can hide behind zero-equivalent enum variants.
- Tests for removal/shift operations must use **non-zero enum values** so stale data is distinguishable from a properly zeroed slot.
- Always verify that slots beyond the active count are zeroed after removal.

This applies to any array with a separate count/length field: hand dice, character assigned dice, and any future collection using the same pattern.

### Structural Invariants

When a struct has fields that must maintain a fixed relationship (e.g., `matched_count + unmatched_count == count`), test that invariant explicitly. Use a helper procedure called from every relevant test so the check is never skipped. Be careful to assert against the logical count (`result.count`), not the fixed array length (`len(result.values)`) — these differ when the array is larger than the active data.

### Sentinel Zero Values in Enums

Every enum that can appear in a fixed-size array with a count, or where zero-initialization has semantic meaning, **must** have an explicit sentinel as its first (zero) value. This makes uninitialized, vacated, or invalid data immediately distinguishable from legitimate values.

Established sentinels:
- `Die_Type.None` — no die present. Asserted against at entry points (`hand_add`, `character_assign`). Renders as magenta `"??"` to be visually obvious if it leaks into rendering.
- `Character_State.Empty` — no character in this party slot. A zero-initialized `Character` struct is `.Empty` by default.

Rules:
- **Do not overload game-meaningful enum values as sentinels.** Slot state (empty/alive/dead) is separate from character properties (rarity). A dead Common character is still Common.
- New enums that appear in arrays or optional contexts should follow this pattern.
- Sentinel values in lookup tables (colours, names) should use obviously wrong values (magenta, `"??"`) so bugs are visible immediately.

## Design Reference

The game design document at `docs/design/core-mechanics.md` is the **source of truth** for all game mechanics. Key rules:

- **Dice types:** d4, d6, d8, d10, d12
- **Board:** Square grid, perimeter-only picks, rarity gradient (outer=d4/d6, middle=d8/d10, centre=d12)
- **Hand:** Max 5 dice. Free assignment to characters. Pure die type per character.
- **Character rarity:** Common=3 slots, Rare=4, Epic=5, Legendary=6
- **Two axes:** [MATCHES] (count of matched dice, breadth) and [VALUE] (face value of best group, depth). No named pattern tiers — abilities use these numbers directly.
- **No Two Pairs or Full House** as distinct patterns. Multiple match groups just add to [MATCHES]. [VALUE] takes the best group.
- **Unmatched dice** charge the character's super meter
- **Actions:** Pick (costs turn), Assign (free, drag-and-drop), Roll (costs turn)
- **Dice movement:** Drag board→hand, board→character, hand→character, character→hand. All via drag-and-drop.
- **Visibility:** Assigned die types visible to both sides (telegraphing)

Always consult the design doc before implementing a mechanic. If the code diverges from the doc, update the doc first.

## Design Philosophy

**Scoped but future-proof.** Implement only what's needed now (see Scope Discipline), but think about how systems will evolve when designing them. Data should live where it logically belongs (e.g. `board.size` on the `Board` struct, not passed as a loose parameter). Thread context through procedures rather than relying on global constants — this makes systems ready for variable configurations (different board sizes per encounter, different hand limits per character, etc.) without requiring a rewrite later.

When making a change, trace all consequences through the codebase before starting. Don't make partial changes that leave some call sites using the old pattern while others use the new one. A refactor is done when every affected reference is updated.

## Scope Discipline

**Only implement what is explicitly requested or listed in the current milestone.** Do not add features, systems, or game objects beyond the scope of the task at hand — even if they seem like a natural next step. If a milestone says "skull dice and character stats", do not also add an enemy character, wire up damage to a target, or build UI for systems that aren't asked for yet.

When in doubt, stop and ask. The cost of pausing is low; the cost of unwanted code is refactoring, confusion, and wasted time.

## Implementation Plan

See `docs/implementation-plan.md` for the milestone breakdown. Work through milestones sequentially — each is independently testable. Current milestone status is tracked in that file.

## Workflow

- Keep commits small and focused — one logical change per commit.
- Update milestone checkboxes in `docs/implementation-plan.md` as tasks are completed.
- Run `odin test tests/` after any logic change to match detection, board, hand, or ability systems.
- When adding a new mechanic, write the test first, then implement.

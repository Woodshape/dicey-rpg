# Prime — Dicey RPG

> Load the project context, understand the design, and report current status.

## Step 1: Read project instructions

Read `CLAUDE.md` for build commands, conventions, and workflow rules.

## Step 2: Read the design docs

Read ALL design documents to understand the architecture and design decisions:

- `docs/core-mechanics.md` — source of truth for game mechanics
- `docs/codebase/types.md` — shared types, enums, constants
- `docs/codebase/board.md` — grid, gradient, perimeter
- `docs/codebase/dice.md` — rolling, match detection
- `docs/codebase/hand.md` — hand management
- `docs/codebase/character.md` — assignment, pure type constraint
- `docs/codebase/combat.md` — turn state machine, resolution
- `docs/codebase/ai.md` — enemy decision-making
- `docs/codebase/ability.md` — effects, resolution, templates
- `docs/codebase/game.md` — Game_State, drag-and-drop, draw
- `docs/codebase/combat-log.md` — ring buffer, file output

## Step 3: Read open issues, TODOs, and ideas

- Read all files in `docs/issues/` — these are concrete problems with negative consequences that need fixing.
- Read all files in `docs/todo/` — these are in-code TODOs collected by category. Cross-check against `src/` with a grep for `TODO` to catch any that aren't documented yet.
- Read all files in `docs/ideas/` — these are design spaces and decisions to explore.

## Step 4: Check implementation status

Read `docs/implementation-plan.md` and identify:
- Which milestones are done
- Which milestone is currently in progress
- Which tasks within the current milestone are done vs remaining

## Step 5: Summary

Deliver:

1. **Project status** — current milestone, what's done, what's remaining
2. **Open issues** — list each issue from `docs/issues/` with a one-line summary
3. **Open TODOs** — list each TODO from `docs/todo/` with a one-line summary; flag any in-code TODOs not yet in `docs/todo/`
4. **Design ideas** — list the major ideas from `docs/ideas/` worth noting
5. **Architecture notes** — any observations about the codebase state (e.g., divergences between docs and code, patterns to be aware of)
6. **Ready** — confirm readiness to work on the project

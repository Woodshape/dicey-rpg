# Dicey RPG - Implementation Plan

**Status:** Draft
**Last Updated:** 2026-03-25
**Language:** Odin
**Renderer:** Raylib (vendor bundle)
**Target Resolution:** 1280x720

---

## Project Structure

```
src/
  main.odin          -- entry point, window, game loop
  game.odin          -- game state, top-level update/draw
  types.odin         -- shared types, enums, constants
  board.odin         -- board data + logic
  dice.odin          -- dice types, rolling, matching
  hand.odin          -- hand management
  character.odin     -- character structs, abilities, slots
  combat.odin        -- turn sequencing, action resolution
  ai.odin            -- enemy drafting heuristics
  ui.odin            -- drawing helpers, layout constants
assets/
  (placeholder assets later)
docs/
  design/
    core-mechanics.md
  implementation-plan.md
```

---

## Architecture Decisions

- **Game state** as a single top-level struct passed by pointer — no globals.
- **State machine** for turn flow, implemented as an enum + switch in `combat.odin`.
- **Abilities** as procedure pointers in a struct — modular from the start, easy to add new ones.
- **Match detection** as a pure function: takes rolled values, returns best pattern + matched value + unmatched list.
- **Structs + procedures** as the primary pattern, with state machines and modular abilities introduced as complexity demands.
- **Cross-platform** by default via Odin + Raylib. No platform-specific code unless necessary.

---

## Milestones

Each milestone is independently testable. Later milestones build on earlier ones.

### Milestone 0: Project Skeleton

**Goal:** Window opens, draws background, closes cleanly.

- [x] Init git repo, create folder structure
- [x] Raylib window at 1280x720
- [x] Basic game loop: init -> update -> draw -> cleanup
- [x] Background colour, window title "Dicey RPG"
- [x] Verify build on host platform

**Status:** Done

---

### Milestone 1: Board Generation & Rendering

**Goal:** Board is visible, perimeter tiles are clickable.

- [x] Square grid data structure with concentric rings
- [x] Rarity gradient: outer ring = d4/d6, middle ring = d8/d10, centre = d12
- [x] Render board with coloured placeholder shapes (one colour per die type)
- [x] Visually distinguish perimeter (pickable) tiles from locked inner tiles
- [x] Click a perimeter tile to remove it (no hand yet, just board interaction)
- [x] Board renders centred on screen

**Status:** Done

---

### Milestone 2: Hand & Assignment

**Goal:** Dice flow from board to hand to character slots.

- [ ] Hand data structure, max 5 dice
- [ ] Render hand at bottom of screen
- [ ] Pick from board -> die goes to hand
- [ ] Render one player character on the left (Common = 3 slots)
- [ ] Click/drag dice from hand to character slot
- [ ] Pure die type constraint enforced (reject mixed types on a character)
- [ ] Click dice on character -> returns to hand
- [ ] Visual feedback for valid/invalid assignment

**Status:** Not Started

---

### Milestone 3: Dice Rolling & Match Detection

**Goal:** Rolling works, matches are detected and displayed.

- [ ] Roll action: roll all assigned dice on a character
- [ ] Match detection algorithm (find best pattern: Pair through Five of a Kind)
- [ ] Display rolled values on dice
- [ ] Highlight matched dice vs unmatched dice
- [ ] Show match pattern name and potency value
- [ ] Unmatched dice flagged for super meter contribution

**Status:** Not Started

---

### Milestone 4: Turn Sequence & Basic AI

**Goal:** Player and enemy alternate actions with a basic AI opponent.

- [ ] Turn state machine: PLAYER_TURN -> ENEMY_TURN (each can pick or roll)
- [ ] Player can pick from board OR roll a character on their turn
- [ ] Enemy AI: prefers die types matching its character's needs
- [ ] Enemy AI: considers denying die types the player is building
- [ ] Turn indicator in UI
- [ ] Assigned dice visible to both sides (telegraphing)
- [ ] Action validation (can't roll empty character, can't pick with full hand)

**Status:** Not Started

---

### Milestone 5: Characters & Abilities

**Goal:** Characters have HP, abilities fire from match results.

- [ ] Character struct: name, rarity, HP, max HP, abilities, super meter
- [ ] 2 placeholder characters (1 player, 1 enemy) with 2-3 abilities each
- [ ] Ability struct with: required match pattern, scaling axis (match/value/hybrid), effect procedure
- [ ] Abilities trigger based on match pattern + potency after rolling
- [ ] Damage and healing resolution
- [ ] HP bars rendered for both sides
- [ ] Super meter fills from unmatched dice
- [ ] Super ability triggers when meter is full (one per character, placeholder effect)

**Status:** Not Started

---

### Milestone 6: Combat Loop & Win/Lose

**Goal:** A complete game can be played from start to finish.

- [ ] Full combat loop: board fills -> draft/roll alternation -> abilities resolve -> HP changes -> win/lose check
- [ ] Board refill (placeholder timing: refill when empty or below threshold)
- [ ] Victory screen
- [ ] Defeat screen
- [ ] "Play again" restart option

**Status:** Not Started

---

### Milestone 7: Polish to MVP

**Goal:** The game feels like a coherent experience.

- [ ] Second player character (1v1 with 2 characters per side, or 2v1)
- [ ] Dice type icons or distinct shapes instead of plain colours
- [ ] Ability names and effects shown on screen
- [ ] Turn log / action history
- [ ] At least one status effect (Paralyze as proof of concept)
- [ ] Balance pass on HP, ability damage, super meter charge rate
- [ ] Board size tuning based on playtesting

**Status:** Not Started

---

## MVP Definition

The MVP is complete when:
- A player can fight an AI opponent through a full combat encounter
- The board, hand, assignment, rolling, and matching systems all work
- At least 2 characters per side with distinct abilities
- Win/lose condition with restart
- Basic AI that makes intentional (if simple) decisions

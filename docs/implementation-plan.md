# Dicey RPG - Implementation Plan

**Status:** Draft
**Last Updated:** 2026-03-26
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

- [x] Hand data structure, max 5 dice
- [x] Render hand at bottom of screen
- [x] Pick from board -> die goes to hand
- [x] Render one player character on the left (Common = 3 slots)
- [x] Drag-and-drop dice from board to hand, board to character, hand to character, character to hand
- [x] Pure die type constraint enforced (reject mixed types on a character)
- [x] Visual feedback: source ghosted, die follows cursor, valid targets glow green

**Status:** Done

---

### Milestone 3: Dice Rolling & Match Detection

**Goal:** Rolling works, matches are detected and displayed.

- [x] Roll action: roll all assigned dice on a character
- [x] Match detection algorithm (find best pattern: Pair through Five of a Kind)
- [x] Display rolled values on dice
- [x] Highlight matched dice vs unmatched dice
- [x] Show match pattern name and potency value
- [x] Unmatched dice flagged for super meter contribution

**Status:** Done

---

### Milestone 4: Skull Dice & Character Stats

**Goal:** Skull dice appear on the board, can be assigned alongside normal dice, and deal damage using character stats.

- [x] Add Skull to Die_Type (exempt from pure type constraint)
- [x] Skull dice appear on the board (distributed across all rings, SKULL_CHANCE% per cell)
- [x] Skull dice visually distinct (pale bone white colour)
- [x] Skull dice can be assigned alongside any normal die type on a character
- [x] Roll resolution: skull dice trigger per-hit attacks at character's Attack stat, normal dice resolve for match patterns
- [x] Skull dice excluded from match detection and super meter
- [x] Character stats: HP, Attack, Defense (Character_Stats struct — HP is a flat value, no maximum)
- [x] Damage calculation: each skull die individually deals max(Attack - target Defense, 0)
- [x] Stats rendered as plain text on character panel (HP, ATK, DEF); damage applied and visible
- [x] Tests: skull dice exempt from pure type, mixed roll resolution, damage calculation
- [x] Per-hit skull damage loop (foundation for future on-hit triggers/passives)

**Status:** Done

---

### Milestone 5: Turn Sequence & Basic AI

**Goal:** Player and enemy alternate actions with a basic AI opponent.

- [x] Turn state machine: PLAYER_TURN -> ENEMY_TURN (each can pick or roll)
- [x] Player can pick from board OR roll a character on their turn
- [x] Enemy AI: prefers die types matching its character's needs, also grabs skull dice
- [x] Enemy AI: considers denying die types the player is building
- [x] Turn indicator in UI
- [x] Assigned dice visible to both sides (telegraphing)
- [x] Action validation (can't roll empty character, can't pick with full hand)

**Status:** Done

---

### Milestone 6: Characters & Abilities

**Goal:** Characters have abilities that fire from match results.

- [ ] 2 placeholder characters (1 player, 1 enemy) with 2-3 abilities each
- [ ] Ability struct with: required match pattern, scaling axis (match/value/hybrid), effect procedure
- [ ] Abilities trigger based on match pattern + potency after rolling
- [ ] Healing and damage abilities resolve alongside skull dice damage
- [ ] Super meter fills from unmatched dice
- [ ] Super ability triggers when meter is full (one per character, placeholder effect)

**Status:** Not Started

---

### Milestone 7: Combat Loop & Win/Lose

**Goal:** A complete game can be played from start to finish.

- [ ] Full combat loop: board fills -> draft/roll alternation -> abilities resolve -> HP changes -> win/lose check
- [ ] Board refill (placeholder timing: refill when empty or below threshold)
- [ ] Victory screen
- [ ] Defeat screen
- [ ] "Play again" restart option

**Status:** Not Started

---

### Milestone 8: Polish to MVP

**Goal:** The game feels like a coherent experience.

- [ ] Second player character (1v1 with 2 characters per side, or 2v1)
- [ ] Dice type icons or distinct shapes instead of plain colours
- [ ] Ability names and effects shown on screen
- [ ] Turn log / action history
- [ ] At least one status effect (Paralyze as proof of concept)
- [ ] Balance pass on HP, Attack, Defense, ability damage, super meter charge rate
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

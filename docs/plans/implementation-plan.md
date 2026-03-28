# Dicey RPG - Implementation Plan

**Status:** Draft
**Last Updated:** 2026-03-27
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
- [x] Unmatched dice flagged for resolve meter contribution

**Status:** Done

---

### Milestone 4: Skull Dice & Character Stats

**Goal:** Skull dice appear on the board, can be assigned alongside normal dice, and deal damage using character stats.

- [x] Add Skull to Die_Type (exempt from pure type constraint)
- [x] Skull dice appear on the board (distributed across all rings, SKULL_CHANCE% per cell)
- [x] Skull dice visually distinct (pale bone white colour)
- [x] Skull dice can be assigned alongside any normal die type on a character
- [x] Roll resolution: skull dice trigger per-hit attacks at character's Attack stat, normal dice resolve for match patterns
- [x] Skull dice excluded from match detection and resolve meter
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

- [x] 2 placeholder characters (1 player, 1 enemy) with 2-3 abilities each
- [x] Ability struct with: required match pattern, scaling axis (match/value/hybrid), effect procedure
- [x] Abilities trigger based on match pattern + potency after rolling
- [x] Healing and damage abilities resolve alongside skull dice damage
- [x] Resolve meter fills from unmatched dice
- [x] Resolve ability triggers when meter is full (one per character, placeholder effect)

**Status:** Done

---

### Milestone 7: Combat Loop & Win/Lose

**Goal:** A complete game can be played from start to finish.

- [x] Full combat loop: board fills -> draft/roll alternation -> abilities resolve -> HP changes -> win/lose check
- [x] Board refill (placeholder timing: refill when empty or below threshold)
- [x] Victory screen
- [x] Defeat screen
- [x] "Play again" restart option

**Status:** Done

---

### Milestone 8: Polish to MVP

**Goal:** The game feels like a coherent experience.

- [x] Second player character (2v2)
- [ ] Dice type icons or distinct shapes instead of plain colours
- [x] Ability names and effects shown on screen
- [x] Turn log / action history (combat log with file output)
- [x] **Condition system:** `Condition` struct with kind, value, expiry model (turns/on-hit), interval/timer for future periodic effects. Shield (absorbs [VALUE] damage) and Hex (DEF -1 for 3 turns) implemented. Conditions tick per-side at turn transitions.
- [x] **Balance pass (first iteration):** Flurry now [VALUE]×[MATCHES] (both axes matter), Shield absorbs [VALUE] damage (die size matters), Hex debuff on Shaman, offensive resolve abilities (Goblin Explosion AoE, Shadow Bolt nuke), resolve_max=10, SKULL_CHANCE=10%, enemy ATK buffed.
- [x] **AI heuristic improvements:** Ability-aware die scoring (scaling fit), strategic assignment routing, deadlock prevention (last-resort roll with skulls when stuck).
- [ ] Dice type icons or distinct shapes instead of plain colours
- [ ] Board size tuning based on playtesting
- [x] **Player deadlock prevention:** Discard action — right-click a hand die to destroy it (free action, no turn cost). AI also discards unusable dice when stuck. Blocked by future status effects (e.g. Frozen).
- [x] **Character inspect overlay:** Click any character panel header (player or enemy) to open a centred overlay showing abilities (main + resolve + passive placeholder) with static `[MATCHES]`/`[VALUE]` descriptions, and full stats. Click anywhere to dismiss.
- [x] **Ability description context:** `Ability_Describe` has the same full signature as `Ability_Effect` — full game state, attacker, target, and roll available. Descriptions are pre-computed into `Roll_Result` buffers at resolve time; both the combat log and draw layer read from the buffers (no `gs` threading into draw chain).
- [x] **Character liveness model:** `character_is_alive` checks `state == .Alive`. `resolve_roll` sets `state = .Dead` when HP hits 0. All liveness checks use this — no more scattered `hp > 0` tests.

**Status:** In Progress

---

### Milestone 9: Configuration System

**Goal:** Move character and encounter definitions from code into `.cfg` data files. New characters that reuse existing ability effects are pure data — no recompilation needed. Balance changes take effect on Play Again.

**Design doc:** `docs/codebase/config.md`

- [x] Custom `.cfg` parser (`src/config.odin`): sections, key-value pairs, section-level lists, inline comma-separated lists
- [x] Character loading: read `data/characters/{name}.cfg`, resolve effect/describe procs via lookup tables
- [x] Encounter loading: read `data/encounters/{name}.cfg`, load referenced characters
- [x] Three separate lookup tables: `ABILITY_EFFECTS/DESCRIBES`, `RESOLVE_EFFECTS/DESCRIBES`, `PASSIVE_EFFECTS` (reserved)
- [x] Convention-based describe resolution (effect key auto-maps to describe key)
- [x] Validation: fail hard with `log.errorf` on missing files, unknown keys/sections/effects, missing required fields
- [x] Migrate all 4 character templates (warrior, healer, goblin, shaman) to `.cfg` files
- [x] Remove `*_create` template procs from `ability.odin`
- [x] `game_init` takes encounter name parameter (default: `"tutorial"`), loads via config system
- [x] Hot reload on Play Again (re-read all data files)
- [x] Rename `static_describe` to `description` in `Ability` struct and all read sites
- [x] Update all description placeholder syntax from `[MATCHES]` to `{MATCHES}`
- [x] Tests: config parsing, character loading, encounter loading, validation error cases

**Status:** Done

---

### Milestone 10: Headless Refactor

**Goal:** Decouple game update logic from Raylib input calls so the combat loop can run headless.

**Design doc:** `docs/plans/headless-refactor.md`

- [x] Add `Input_State` struct to `types.odin` (mouse position, button state, delta time)
- [x] Collect Raylib input once per frame in `game_update`, pass `Input_State` down
- [x] Thread `Input_State` through `combat_update`, `player_turn_update`, `player_roll_result_update`, `enemy_roll_result_update`, `game_over_update`
- [x] Remove all direct `rl.` input calls from `combat.odin`
- [x] Remove unused `rl` import from `ai.odin` (already clean — no import existed)
- [x] Verify all existing tests still pass (115/115)
- [x] Verify game behaviour is identical

**Status:** Done

---

### Milestone 11: Combat Simulator

**Goal:** Run N headless battles with configurable encounters and collect balance statistics. AI vs AI mirror match.

**Design doc:** `docs/plans/simulator.md`

- [x] `sim/main.odin`: CLI argument parsing (`--encounter`, `--rounds`, `--seed`, `--csv`, `--no-skulls`)
- [x] Headless game loop: AI drives both sides via party-swap trick, roll results resolve instantly (no display timer), turn limit (`MAX_SIM_TURNS = 200`) catches infinite loops
- [x] Seeding: base seed via CLI (random if omitted, always printed), per-game seed = `base_seed + round_number`
- [x] `sim/stats.odin`: `Game_Stats` and `Char_Stats` structs, per-game collection via HP snapshots before/after `resolve_roll`
- [x] `Aggregate_Stats`: win rate, avg turns, per-character damage/healing/ability fire rate/resolve fire rate/survival rate/avg HP remaining
- [x] Stdout: human-readable summary table + dice mechanics table
- [x] CSV: per-game detail, one row per round, includes per-game seed for replay
- [x] Dice mechanics analysis: per-roll `Roll_Stats` collection, `Dice_Aggregate` by die type with avg [M]/[V]/match%/damage by scaling type
- [x] `board_init` accepts `skull_chance` parameter for `--no-skulls` mode
- [x] Fixed `ability_resolve_mass_heal` to use `attacker_party()` instead of hardcoded `gs.player_party` (side-agnostic)

**Status:** Done

---

### Milestone 12: Draft Pool (Board Replacement)

**Goal:** Replace the board grid with a draft pool system. Batch flow: draft all dice first, then assign and roll. Simpler, faster, focused on pure drafting decisions.

**Design doc:** `docs/ideas/draft-pool.md`
**Implementation plan:** `docs/plans/draft-pool.md`

- [x] New types: `Draft_Pool`, `Weight_Group`, `Round_State`, reworked `Turn_Phase` (9 phases)
- [x] `src/pool.odin`: pool generation, weight group cycling, rendering, hit-testing
- [x] Delete `src/board.odin` and `tests/board_test.odin`
- [x] Rewrite `src/combat.odin`: draft phase → combat phase → round end state machine. Each side rolls all characters before the other side goes (not alternating). "Done" button to skip remaining rolls.
- [x] Update `src/game.odin`: Game_State (pool + round), drag-and-drop (pool source), rendering (pool + HUD + done button + phase-aware roll buttons)
- [x] Update `src/ai.odin`: `ai_draft_pick` + `ai_combat_turn` replace `ai_take_turn`. Pool scanning via `ai_pick_best_pool_die`.
- [x] Update `src/config.odin`: pool_size/skull_chance ready for encounter config
- [x] Update `sim/main.odin`: headless loop for new phases with party-swap trick
- [x] `tests/pool_test.odin`: 17 tests — weight groups, pool mechanics, cycling, round state
- [x] Update `tests/combat_test.odin` (15 tests) and `tests/ai_test.odin` (16 tests)
- [x] Update all design docs
- [x] Enhanced combat log: rolled values, HP after damage/heal, shield absorption

**Status:** Done

---

## MVP Definition

The MVP is complete when:
- A player can fight an AI opponent through a full combat encounter
- The draft pool, hand, assignment, rolling, and matching systems all work
- At least 2 characters per side with distinct abilities
- Win/lose condition with restart
- Basic AI that makes intentional (if simple) decisions

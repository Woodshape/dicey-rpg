# Framework Migration Plan: Odin/Raylib to Code-Only Game Framework

**Status:** Draft
**Created:** 2026-03-28

---

## 1. Current Raylib Surface Area

Before evaluating alternatives, here's exactly what Raylib does in the codebase today. The surface area is deliberately small.

### Files with ZERO Raylib dependency (pure game logic)

| File | Imports | Notes |
|------|---------|-------|
| `dice.odin` | `core:math/rand` | Match detection, rolling |
| `ability.odin` | `core:fmt` | Effects, descriptions |
| `ai.odin` | (none) | All AI logic |
| `condition.odin` | (none) | Status effects |
| `config.odin` | `core:fmt`, `core:os`, `core:strconv`, `core:strings` | .cfg parser, character/encounter loading |

These files (~620 lines) are **100% portable** as pure logic. They need a language rewrite but no framework-specific changes.

### Files with Raylib dependency

| File | Raylib Usage | Portable Logic |
|------|-------------|----------------|
| `types.odin` | `rl.Color` in lookup tables + `Log_Entry`, `rl.Rectangle` for buttons | All type definitions, enums, constants |
| `main.odin` | Window init, game loop, FPS | None (entry point) |
| `game.odin` | Input collection, all drawing, drag visuals, overlays | `Game_State`, `game_init`, `try_start_drag`, `try_drop`, hit-testing |
| `board.odin` | `board_draw`, mouse in draw | `board_init`, `cell_ring`, `ring_die_type`, perimeter logic, `cell_position`, `mouse_to_cell` |
| `hand.odin` | `hand_draw`, `hand_draw_at`, mouse in draw | `hand_add/remove/discard`, position helpers, hit-testing |
| `character.odin` | All `*_draw*` procs, `rl.Rectangle`, `rl.GetMouse*` in draw | `character_create`, assignment, unassignment, skull damage, panel position helpers |
| `combat.odin` | `rl.Color` in log calls only | Entire state machine, resolution, targeting, win/lose, action validation |
| `combat_log.odin` | `rl.Color` in entries, `combat_log_draw` | Ring buffer logic, file output |

### Raylib API calls used (complete list)

**Window/System** (3 calls): `InitWindow`, `CloseWindow`, `SetTargetFPS`, `WindowShouldClose`, `TraceLog`

**Input** (5 calls): `GetMouseX`, `GetMouseY`, `IsMouseButtonPressed`, `IsMouseButtonReleased`, `GetFrameTime`

**Drawing** (7 calls): `BeginDrawing`, `EndDrawing`, `ClearBackground`, `DrawRectangle`, `DrawRectangleLines`, `DrawLine`, `DrawText`, `MeasureText`

**Types** (2): `rl.Color` (RGBA struct), `rl.Rectangle` (x/y/w/h)

**Constants**: `WHITE`, `RAYWHITE`, `GRAY`, `MAGENTA`, `YELLOW`, `RED`, `DARKGRAY`

**Not used at all**: Textures, sprites, shaders, audio, fonts, cameras, 3D, physics, networking.

### Key architectural strengths for migration

1. **Input already decoupled** -- `Input_State` struct collected once per frame; combat logic never calls Raylib directly
2. **Game logic is pure** -- dice, abilities, AI, conditions have zero framework dependencies
3. **Simulator proves headless works** -- `sim/` runs the full game loop without any rendering
4. **Single `Game_State` struct** -- no globals, clean data flow, easy to port
5. **Config system is file-based** -- `.cfg` files work with any framework
6. **Draw is read-only** -- `game_draw` never mutates state; clean update/draw separation

---

## 2. Framework Evaluation

### Evaluation criteria

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| Language fit | High | Must support structs + procedures, strong typing, value types |
| 2D rendering | High | Game uses only rectangles, lines, and text |
| Input model | Medium | Mouse-only input, already abstracted |
| Cross-platform | Medium | Desktop is primary; console/mobile is a future bonus |
| Ecosystem maturity | High | Stable API, good docs, active community |
| Content pipeline | Low | No assets yet; dice icons are the only pending visual task |
| Migration effort | High | How much architectural rework is needed beyond language translation |

### Framework comparison

#### MonoGame (C#)

| Aspect | Assessment |
|--------|------------|
| **Language** | C# structs map directly to Odin structs. Strong typing, value types via `struct`. Pattern matching via `switch`. Named returns via `out` parameters. |
| **Game loop** | XNA pattern (`Initialize`/`Update`/`Draw`) maps 1:1 to `game_init`/`game_update`/`game_draw` |
| **2D rendering** | `SpriteBatch` for rectangles and text. `SpriteFont` for text measurement. Covers 100% of current rendering. |
| **Input** | `Mouse.GetState()` returns position + button state -- maps directly to `Input_State` |
| **Platforms** | Windows, macOS, Linux, iOS, Android, Xbox, PlayStation, Switch |
| **Maturity** | v3.8.5, actively maintained by MonoGame Foundation. Used by Stardew Valley, Celeste, Carrion. |
| **Content pipeline** | MGCB for fonts, textures when needed. Can also load raw files for .cfg. |
| **Migration effort** | **Low-Medium.** Language translation + replace ~15 Raylib API calls with MonoGame equivalents. Architecture unchanged. |
| **Weakness** | No web export. IDE story on Linux (Rider costs money; VS Code works but rougher). |

#### FNA (C#)

| Aspect | Assessment |
|--------|------------|
| **Language** | Same as MonoGame (C#, XNA API) |
| **Game loop** | Identical to MonoGame |
| **2D rendering** | Same XNA API |
| **Platforms** | Desktop only (Windows/macOS/Linux). No mobile or console. |
| **Maturity** | Battle-tested for game ports (Celeste, Bastion). Smaller community. |
| **Migration effort** | Same as MonoGame |
| **Weakness** | Desktop-only. Smaller ecosystem. FNA is for porting existing XNA games, not starting new ones. |

**Verdict:** MonoGame is strictly better for a new project. FNA only wins if you already have an XNA codebase.

#### Love2D (Lua)

| Aspect | Assessment |
|--------|------------|
| **Language** | Lua is dynamically typed. Loses the type safety that Odin and the codebase rely on (enum sentinels, struct invariants, `assert`). Tables instead of structs. |
| **Game loop** | `love.load`/`love.update`/`love.draw` -- same pattern |
| **2D rendering** | `love.graphics.rectangle`, `love.graphics.print` -- covers current needs |
| **Platforms** | Windows, macOS, Linux, Android, iOS. Web via community port (love.js). |
| **Maturity** | v11.5, long history, active community |
| **Migration effort** | **High.** Every type definition, enum, fixed-size array, and assertion must be reimagined in Lua idioms. The type discipline that keeps this codebase correct would be lost. |
| **Weakness** | Dynamic typing is a fundamental mismatch. 133 tests relying on structural invariants would need a different approach. |

**Verdict:** Good framework, wrong language for this codebase. The game logic is complex enough that static typing pays for itself.

#### Bevy (Rust)

| Aspect | Assessment |
|--------|------------|
| **Language** | Rust has excellent type system. But the ownership model is very different from Odin's pointer-passing. `Game_State` with cross-references (attacker/target pointers) would need rethinking. |
| **Architecture** | ECS (Entity Component System) is fundamentally different from the current struct-of-arrays + state machine architecture. Migration would be a rewrite, not a port. |
| **Maturity** | v0.18 as of early 2026. **Still pre-1.0.** Breaking API changes every ~3 months. |
| **Migration effort** | **Very High.** Complete architectural rethink. Every system (combat state machine, ability procedures, AI) would need to be redesigned for ECS. |
| **Weakness** | Pre-1.0 instability. ECS paradigm mismatch. Steep learning curve. |

**Verdict:** Wrong architecture and too immature. Would require a ground-up rewrite, not a migration.

#### Stride (C#)

| Aspect | Assessment |
|--------|------------|
| **Language** | C# (same as MonoGame) |
| **Architecture** | Full 3D engine with editor. Code-only mode exists via Community Toolkit but is not first-class. |
| **Platforms** | Windows-only for code-only mode. |
| **Migration effort** | **Medium-High.** Engine is designed around scenes, entities, and a 3D pipeline. Using it for 2D rectangles and text is fighting the tool. |
| **Weakness** | Massive overkill. 3D engine for a game that draws colored rectangles. Windows-only for code-only. |

**Verdict:** Wrong tool for the job. Stride's value is 3D rendering and its editor.

#### libGDX (Java/Kotlin)

| Aspect | Assessment |
|--------|------------|
| **Language** | Java/Kotlin. Kotlin is pleasant but JVM is a bigger ecosystem shift than .NET. |
| **2D rendering** | `SpriteBatch`, `ShapeRenderer` -- covers current needs |
| **Platforms** | Windows, macOS, Linux, Android, iOS, **Web (GWT/TeaVM)** |
| **Maturity** | Very mature, large community |
| **Migration effort** | **Medium.** Language translation + framework API swap. Architecture maps well. |
| **Weakness** | JVM startup overhead. Java ecosystem is heavier than .NET for game dev. Kotlin helps but adds a layer. |

**Verdict:** Viable but C# is a closer language match to Odin than Java/Kotlin. Web export is the main advantage over MonoGame.

#### Pygame (Python)

| Aspect | Assessment |
|--------|------------|
| **Language** | Python. Dynamic typing, performance ceiling. |
| **Migration effort** | **Medium-High.** Type safety loss, performance concerns for simulator (1000+ games). |
| **Weakness** | Performance. Dynamic typing. Distribution is painful. |

**Verdict:** Would work for the game itself but the simulator (which runs 100K headless battles) would suffer. Not a good fit.

### Summary matrix

| Framework | Language Match | Architecture Match | Maturity | Platform Reach | Migration Effort | **Overall** |
|-----------|--------------|-------------------|----------|---------------|-----------------|-------------|
| **MonoGame** | Excellent | Excellent | Stable | Wide + consoles | Low-Medium | **Best** |
| FNA | Excellent | Excellent | Stable | Desktop only | Low-Medium | Good (limited) |
| Love2D | Poor | Good | Stable | Good | High | Poor fit |
| Bevy | Good (types) | Poor (ECS) | Unstable | Good | Very High | Poor fit |
| Stride | Excellent | Poor (3D) | Stable | Windows only | Medium-High | Poor fit |
| libGDX | Good | Good | Stable | Wide + web | Medium | Runner-up |
| Pygame | Poor | Good | Stable | Desktop | Medium-High | Poor fit |

---

## 3. Recommendation: MonoGame

MonoGame is the strongest fit because:

1. **C# maps closest to Odin's paradigm.** Structs are value types. Enums are first-class. Strong typing catches the same bugs. Pattern matching via `switch`. No GC pressure when using structs.

2. **The XNA game loop is architecturally identical** to the current `game_init`/`game_update`/`game_draw` pattern. Zero architectural rework.

3. **SpriteBatch covers 100% of current rendering.** Colored rectangles, outlined rectangles, text with measurement. Nothing else needed.

4. **Input model maps directly.** `Mouse.GetState()` populates the same data as `Input_State`.

5. **The .cfg config system ports as-is.** File I/O and string parsing work the same way.

6. **Console deployment** (Switch, Xbox, PlayStation) is available when ready -- something Raylib cannot offer.

7. **Content pipeline** for the pending dice icons milestone (Milestone 8 remaining task).

8. **The simulator ports cleanly** -- C# console app, no rendering, same headless architecture.

**Runner-up: libGDX** if web deployment becomes a priority. Otherwise MonoGame wins on every axis.

---

## 4. Migration Plan

### Phase 0: Project Setup

**Goal:** MonoGame project compiles, window opens, draws background.

- [ ] Create C# solution with MonoGame template (net10.0)
- [ ] Mirror project structure:
  ```
  src/
    DiceyRPG.csproj        -- MonoGame project
    Program.cs              -- entry point
    DiceyRPG.cs             -- Game subclass (init/update/draw)
    Types.cs                -- all types, enums, constants
    Board.cs                -- board logic + drawing
    Dice.cs                 -- rolling, match detection
    Hand.cs                 -- hand management + drawing
    Character.cs            -- character logic + drawing
    Combat.cs               -- turn state machine
    Ai.cs                   -- enemy AI
    Ability.cs              -- effects, descriptions, resolution
    Condition.cs            -- status effects
    Config.cs               -- .cfg parser, loading
    CombatLog.cs            -- ring buffer + drawing
  sim/
    DiceySim.csproj         -- console app, references game project
    Program.cs              -- CLI + headless loop
    Stats.cs                -- collection + aggregation
  tests/
    DiceyTests.csproj       -- xUnit or NUnit
    BoardTests.cs
    DiceTests.cs
    ...
  data/                     -- unchanged, copy as-is
    characters/
    encounters/
  ```
- [ ] Verify: window opens at 1280x720, dark background, closes cleanly

### Phase 1: Types and Pure Logic (no rendering)

**Goal:** All game types and pure logic compile. Tests pass.

This is the largest phase by line count but the most mechanical -- it's a language translation with no design changes.

#### Naming convention mapping

| Odin | C# |
|------|----|
| `snake_case` procs | `PascalCase` methods (C# convention) |
| `Pascal_Case` types | `PascalCase` types (drop underscore) |
| `SCREAMING_CASE` constants | `PascalCase` or `SCREAMING_CASE` const (team preference) |
| `Die_Type` enum | `DieType` enum |
| `Game_State` struct | `GameState` class or struct |
| `character_roll(ch)` | `ch.Roll()` or `Dice.Roll(ch)` (see design decision below) |

#### Design decision: structs + static methods vs. classes with methods

The Odin codebase uses free-standing procedures that take a pointer to a struct. Two C# approaches:

**Option A: Static methods (closest to Odin)**
```csharp
public static class BoardLogic {
    public static bool CellIsPickable(ref Board board, int row, int col) { ... }
}
```

**Option B: Methods on types (idiomatic C#)**
```csharp
public struct Board {
    public bool CellIsPickable(int row, int col) { ... }
}
```

**Recommendation: Option B (methods on types)** for public API, with static helper methods for pure functions like `DetectMatch`. This is idiomatic C# while preserving the same data flow. The `Game_State` equivalent becomes a class (reference type) since it's always passed by pointer.

#### Type mapping

| Odin | C# | Notes |
|------|----|-------|
| `enum u8` | `enum : byte` | Direct mapping |
| `[N]T` (fixed array) | `T[]` with const size, or use fixed-size buffer | See below |
| `cstring` | `string` | C# strings are managed |
| `rl.Color` | `Microsoft.Xna.Framework.Color` | Same RGBA struct |
| `rl.Rectangle` | `Microsoft.Xna.Framework.Rectangle` | Same x/y/w/h |
| `proc(...)` | `delegate` or `Action<...>` / `Func<...>` | Ability_Effect becomes a delegate |
| `#type proc(...)` | `delegate` type alias | Direct mapping |
| `i32` / `f32` | `int` / `float` | Direct mapping |

#### Fixed-size arrays

Odin uses `[MAX_HAND_SIZE]Die_Type` (stack-allocated, no heap). C# options:

1. **Plain arrays with capacity tracking** (recommended):
   ```csharp
   public struct Hand {
       public DieType[] Dice;  // initialized to MaxHandSize
       public int Count;
   }
   ```

2. **Span/stackalloc** for hot paths (optimization, later).

The count+array pattern used throughout the codebase translates directly. Initialize arrays to fixed capacity in constructors.

#### Migration order (pure logic first, no rendering)

1. **`Types.cs`** -- all enums, structs, constants. Replace `rl.Color` with `Color` from MonoGame. This is the foundation everything else imports.

2. **`Dice.cs`** -- `DetectMatch` (pure function), `RollDie`, `CharacterRoll`, `CharacterClearRoll`. Port all 27 dice tests.

3. **`Board.cs`** (logic only) -- `BoardInit`, `CellRing`, `RingDieType`, perimeter logic, removal. Port all 18 board tests. Skip `BoardDraw` for now.

4. **`Hand.cs`** (logic only) -- `HandAdd`, `HandRemove`, `HandDiscard`, capacity. Port all 9 hand tests. Skip drawing.

5. **`Character.cs`** (logic only) -- `CharacterCreate`, assignment, unassignment, skull damage, position helpers. Port all 10 character tests. Skip drawing.

6. **`Condition.cs`** -- `ConditionApply`, `ConditionRemove`, `ConditionTick`, absorption, effective defense. Port all 13 condition tests.

7. **`Ability.cs`** -- All effect procs, describe procs, `HandleAbilities`. Port all 12 ability tests.

8. **`Combat.cs`** (logic only) -- State machine, `ResolveRoll`, targeting, win/lose, action validation. Port all 14 combat tests. Skip timer-based display.

9. **`Ai.cs`** -- All AI logic (zero rendering). Port all 16 AI tests.

10. **`Config.cs`** -- .cfg parser, character/encounter loading. Port all config tests. Use `System.IO.File.ReadAllText` instead of `os.read_entire_file`.

**Milestone gate:** All 133 tests pass in C#. No rendering yet.

### Phase 2: Rendering Layer

**Goal:** The game renders and is playable.

#### MonoGame rendering equivalents

| Raylib | MonoGame | Notes |
|--------|----------|-------|
| `rl.InitWindow(w, h, title)` | `GraphicsDeviceManager` in constructor | Set `PreferredBackBufferWidth/Height` |
| `rl.BeginDrawing()` / `rl.EndDrawing()` | `SpriteBatch.Begin()` / `SpriteBatch.End()` | Called in `Draw()` |
| `rl.ClearBackground(color)` | `GraphicsDevice.Clear(color)` | In `Draw()` |
| `rl.DrawRectangle(x,y,w,h,color)` | `SpriteBatch.Draw(pixel, rect, color)` | Draw a 1x1 white texture scaled to rect |
| `rl.DrawRectangleLines(x,y,w,h,color)` | 4x `SpriteBatch.Draw` for edges | Or use a helper method |
| `rl.DrawLine(x1,y1,x2,y2,color)` | `SpriteBatch.Draw` rotated 1px texture | Or use a line helper |
| `rl.DrawText(text, x, y, size, color)` | `SpriteBatch.DrawString(font, text, pos, color)` | Needs a `SpriteFont` loaded via content pipeline |
| `rl.MeasureText(text, size)` | `font.MeasureString(text)` | Returns `Vector2` instead of `int` |
| `rl.GetMouseX/Y()` | `Mouse.GetState().X/Y` | Collected in `Update()` |
| `rl.IsMouseButtonPressed(.LEFT)` | Track previous + current `MouseState` | MonoGame doesn't have "just pressed" built-in |
| `rl.GetFrameTime()` | `gameTime.ElapsedGameTime.TotalSeconds` | Passed to `Update(GameTime)` |

#### Drawing helper

Create a small `DrawHelper` static class:

```csharp
public static class Draw {
    private static Texture2D _pixel;

    public static void Init(GraphicsDevice device) {
        _pixel = new Texture2D(device, 1, 1);
        _pixel.SetData(new[] { Color.White });
    }

    public static void Rect(SpriteBatch sb, int x, int y, int w, int h, Color color) {
        sb.Draw(_pixel, new Rectangle(x, y, w, h), color);
    }

    public static void RectLines(SpriteBatch sb, int x, int y, int w, int h, Color color) {
        Rect(sb, x, y, w, 1, color);         // top
        Rect(sb, x, y + h - 1, w, 1, color); // bottom
        Rect(sb, x, y, 1, h, color);         // left
        Rect(sb, x + w - 1, y, 1, h, color); // right
    }
}
```

#### Font handling

Raylib uses a built-in default font with integer sizes. MonoGame requires loading a `SpriteFont` via the content pipeline.

- Create 3-4 `SpriteFont` assets for the sizes used: 12, 14, 16, 18, 20, 24, 28, 48
- Or use a single font with scale factors
- Or use [SpriteFontPlus](https://github.com/rds1983/SpriteFontPlus) / [FontStashSharp](https://github.com/FontStashSharp/FontStashSharp) for runtime font loading (no content pipeline needed)

**Recommendation:** FontStashSharp for runtime font loading -- avoids content pipeline complexity and matches the current "no asset pipeline" simplicity.

#### Input state

```csharp
public struct InputState {
    public int MouseX, MouseY;
    public bool LeftPressed, LeftReleased, RightPressed;
    public float DeltaTime;
}

// In Update():
var mouse = Mouse.GetState();
var input = new InputState {
    MouseX = mouse.X,
    MouseY = mouse.Y,
    LeftPressed = mouse.LeftButton == ButtonState.Pressed && _prevMouse.LeftButton == ButtonState.Released,
    LeftReleased = mouse.LeftButton == ButtonState.Released && _prevMouse.LeftButton == ButtonState.Pressed,
    RightPressed = mouse.RightButton == ButtonState.Pressed && _prevMouse.RightButton == ButtonState.Released,
    DeltaTime = (float)gameTime.ElapsedGameTime.TotalSeconds,
};
_prevMouse = mouse;
```

#### Migration order (rendering)

1. **Draw helpers** -- `DrawHelper` class, font loading
2. **Board drawing** -- `BoardDraw` (rectangles + text labels)
3. **Hand drawing** -- `HandDraw`, `HandDrawAt`
4. **Character drawing** -- All panel drawing, die slots, roll results, roll button
5. **Game drawing** -- HUD, turn indicator, combat log, game over overlay, inspect overlay
6. **Drag-and-drop visuals** -- Ghosting, cursor-following die, drop target highlights
7. **Game loop** -- Wire `Update` -> `CombatUpdate` -> phase handlers, `Draw` -> `GameDraw`

**Milestone gate:** Game is fully playable. Visual parity with the Odin version.

### Phase 3: Simulator

**Goal:** Headless simulator runs as a separate console project.

- [ ] Create `DiceySim.csproj` as a console app referencing the game project
- [ ] Port `sim/main.odin` -- CLI parsing, headless game loop, party-swap trick
- [ ] Port `sim/stats.odin` -- per-game stats, aggregation, CSV output
- [ ] Verify: `dotnet run --project sim -- --encounter=tutorial --rounds=1000` produces same statistical distribution

The simulator has zero rendering dependencies. It's a straightforward port.

### Phase 4: Polish and Verification

- [ ] Run all 133 tests, verify pass
- [ ] Run simulator, compare win rates and stat distributions to Odin version (same seed should produce same results if RNG is seeded identically)
- [ ] Playtest: verify drag-and-drop feel, timing, visual feedback
- [ ] Verify .cfg hot reload on Play Again
- [ ] Verify combat log file output
- [ ] Port remaining Milestone 8 tasks (dice icons) using MonoGame content pipeline or runtime texture generation

---

## 5. What Stays Unchanged

These design decisions from `docs/` carry forward exactly:

| Decision | Location | Notes |
|----------|----------|-------|
| Two-axis resolution ([MATCHES]/[VALUE]) | `docs/core-mechanics.md` | Core mechanic, language-independent |
| Board rarity gradient | `docs/codebase/board.md` | Same algorithm, different language |
| Pure type constraint | `docs/codebase/character.md` | Same validation logic |
| Per-hit skull damage loop | `docs/codebase/character.md` | Same loop structure |
| Ability procedure pointer pattern | `docs/codebase/ability.md` | Becomes C# delegates |
| Condition system (Shield/Hex) | `docs/codebase/condition.md` | Same tick/absorb logic |
| AI scoring and decision tree | `docs/codebase/ai.md` | Same algorithms |
| State machine combat flow | `docs/codebase/combat.md` | Same enum + switch |
| .cfg config format | `docs/codebase/config.md` | Same parser, same data files |
| Input_State abstraction | `docs/codebase/combat.md` | Same pattern (already headless-ready) |
| Drag-and-drop (no click-to-select) | `docs/codebase/game.md` | Same interaction model |
| Sentinel zero values in enums | `CLAUDE.md` | C# enums default to 0 -- same pattern |
| Fixed-size arrays + count | `CLAUDE.md` | Array + Count fields, same pattern |
| Test invariants | `CLAUDE.md` | Same structural invariant checks |

---

## 6. What Changes

| Aspect | Odin/Raylib | MonoGame/C# |
|--------|-------------|-------------|
| Language | Odin (structs + procedures) | C# (structs/classes + methods) |
| Naming | `snake_case` procs, `Pascal_Case` types | `PascalCase` everywhere (C# convention) |
| Strings | `cstring`, `fmt.ctprintf` | `string`, `$"interpolation"` or `string.Format` |
| Memory | Stack by default, `defer delete` | GC for classes, stack for structs |
| Error handling | `(T, bool)` tuples, `or_return` | `bool TryX(out T)` pattern, or exceptions for truly exceptional cases |
| Procedure pointers | `#type proc(...)` | `delegate` types |
| Package structure | Single `package game` | Namespace + classes (can stay flat) |
| Build | `odin build src/` | `dotnet build` |
| Test framework | `@(test)` + `testing.expect_value` | xUnit `[Fact]` + `Assert.Equal` |
| Random | `core:math/rand` | `System.Random` (seed-compatible) |
| File I/O | `os.read_entire_file` | `File.ReadAllText` |
| Font rendering | Built-in default font | Must load SpriteFont (via content pipeline or FontStashSharp) |
| "Just pressed" input | `rl.IsMouseButtonPressed` (built-in) | Manual previous/current state tracking |

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| RNG divergence (different results for same seed) | High | Low | Accept different distributions; verify statistical equivalence, not exact replay |
| Font rendering differences | Medium | Low | Choose a clean pixel/monospace font; tune sizes to match |
| Drag-and-drop feel differs | Medium | Medium | MonoGame input polling is frame-accurate like Raylib; tune thresholds if needed |
| Content pipeline complexity | Low | Low | Use FontStashSharp for runtime fonts; avoid MGCB for initial port |
| .NET ecosystem overhead | Low | Low | MonoGame projects are lightweight; no heavy dependencies |
| Test count regression | Low | High | Port tests alongside logic (same phase); gate each phase on full test pass |

---

## 8. Estimated Scope

| Phase | Files | Approximate Lines | Dependencies |
|-------|-------|-------------------|-------------|
| Phase 0: Setup | 2-3 | ~50 | None |
| Phase 1: Types + Logic | 10 | ~1500 (translation of ~1300 Odin lines) | None (pure C#) |
| Phase 1: Tests | 9 | ~1200 (translation of ~1000 Odin test lines) | xUnit |
| Phase 2: Rendering | 6 | ~800 (translation of ~700 Odin draw lines) | MonoGame, FontStashSharp |
| Phase 3: Simulator | 2 | ~300 | Console app |
| Phase 4: Polish | — | ~100 | — |
| **Total** | ~30 | **~4000** | |

The Odin codebase is ~2800 lines of game code + ~1000 lines of tests + ~300 lines of simulator. C# will be slightly more verbose (~10-20% more lines due to braces, access modifiers, etc.).

---

## 9. Alternative Consideration: libGDX

If **web deployment** becomes a priority, libGDX is the runner-up:

- Same migration structure (phases 0-4 apply identically)
- Java/Kotlin instead of C#
- `ShapeRenderer` for rectangles, `BitmapFont` for text
- GWT or TeaVM for HTML5 export
- Slightly more ecosystem friction (Gradle, JVM)

The migration plan structure above applies to libGDX with language substitutions. The architecture mapping is equally clean.

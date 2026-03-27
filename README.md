# Dicey RPG

A turn-based dice-drafting RPG built with [Odin](https://odin-lang.org/) and [Raylib](https://www.raylib.com/).

Players and enemies take turns picking dice from a shared board, roll their drafted hand, and resolve abilities based on two axes: **[MATCHES]** (how many dice show the same value) and **[VALUE]** (how high that value is).

See [docs/design/core-mechanics.md](docs/design/core-mechanics.md) for the full game design document.

---

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

## Project Structure

```
src/        -- game source (package game)
tests/      -- test suite (separate package)
assets/     -- placeholder assets
docs/       -- design documents and implementation plan
```

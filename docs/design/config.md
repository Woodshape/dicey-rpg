# Configuration System

Data-driven character and encounter definitions using a custom config format. Effect procedures stay in Odin; characters that reuse existing effects are pure data — no recompilation needed.

## File Structure

```
data/
  characters/
    warrior.cfg
    healer.cfg
    goblin.cfg
    shaman.cfg
  encounters/
    tutorial.cfg
    boss.cfg
```

Future expansion: `data/abilities/` when ability definitions themselves become data-driven (separate from effect procs).

---

## Config Format

Custom line-oriented format. Simple to parse, readable, extendable.

### Grammar

```
file       = { line }
line       = blank | comment | section | list_item | key_value
blank      = { whitespace } newline
comment    = "#" { any } newline
section    = "[" identifier "]" newline
list_item  = "-" whitespace scalar newline
key_value  = identifier whitespace "=" whitespace value newline
identifier = letter { letter | digit | "_" }
value      = scalar | list_value
list_value = scalar { "," whitespace scalar }
scalar     = { any except newline | "," }
```

### Rules

- Lines are processed top-to-bottom. A `[section]` header scopes all subsequent `key = value` pairs until the next section or end of file.
- Keys before any section header belong to the root scope.
- Values are trimmed of leading/trailing whitespace.
- Values are interpreted as integers if they parse as such, otherwise strings.
- List items (`- value`) are collected in order under the current section.
- A section contains either key-value pairs or list items, not both. Mixing is an error.
- Unknown sections and keys are errors (fail hard).
- Duplicate keys within the same section are errors.
- Placeholders in string values use `{identifier}` syntax (e.g. `{MATCHES}`, `{VALUE}`, `{attack}`). Square brackets are reserved for section headers and must not appear in values.

### Examples

**Key-value pairs** (root scope and sections):

```
# data/characters/warrior.cfg
name = Warrior
rarity = Common

[stats]
hp = 20
attack = 3
```

**List under a section** — items collected in order, no keys:

```
# data/encounters/tutorial.cfg
[player]
- warrior
- healer

[enemy]
- goblin
- shaman
```

**Mixed root keys and sectioned lists** — root keys come first, sections follow:

```
name = Boss Fight
difficulty = 3

[player]
- warrior
- healer

[enemy]
- goblin
- goblin
- shaman
```

**Inline list value** — a key whose value contains commas is parsed as a string slice:

```
# data/characters/warrior.cfg
name = Warrior
rarities = Common, Rare, Epic
tags = fighter, melee, front-row
```

The parser detects the comma and splits on it, trimming whitespace from each element. The caller knows which keys to expect as lists vs scalars — the config layer returns a tagged union or the caller uses a typed accessor.

Lists and key-value sections can coexist in the same file as long as each individual section contains only one kind (section-level lists use `- item`, inline lists use comma-separated values).

---

## Character Config

```
# data/characters/warrior.cfg
name = Warrior
rarity = Common
resolve_max = 5

[stats]
hp = 20
attack = 3
defense = 1

[ability]
name = Flurry
effect = flurry
scaling = match
min_matches = 2
min_value = 0
description = {attack} dmg x {MATCHES} hits

[resolve_ability]
name = Heroic Strike
effect = resolve_warrior
scaling = match
min_matches = 0
min_value = 0
description = 10 dmg, ignores {defense}

[passive]
name = Iron Skin
effect = iron_skin
```

### Required Fields

| Scope | Field | Type | Notes |
|-------|-------|------|-------|
| root | `name` | string | Display name |
| root | `rarity` | string | `Common`, `Rare`, `Epic`, `Legendary` |
| root | `resolve_max` | int | Resolve meter capacity |
| `[stats]` | `hp` | int | Starting hit points |
| `[stats]` | `attack` | int | Base attack stat |
| `[stats]` | `defense` | int | Base defense stat |
| `[ability]` | `name` | string | Display name |
| `[ability]` | `effect` | string | Key into `ABILITY_EFFECTS` table |
| `[ability]` | `scaling` | string | `none`, `match`, `value`, `hybrid` |
| `[ability]` | `min_matches` | int | Minimum [MATCHES] to trigger (0 = always) |
| `[ability]` | `min_value` | int | Minimum [VALUE] to trigger (0 = always) |
| `[ability]` | `description` | string | Static description for inspect overlay |

### Required Sections

All three ability sections are required for every character. `[passive]` is parsed and validated but not yet wired into the runtime.

| Section | Fields | Notes |
|---------|--------|-------|
| `[ability]` | Same as above | Main ability, uses `ABILITY_EFFECTS` table |
| `[resolve_ability]` | Same as `[ability]` | Resolve ability, uses `RESOLVE_EFFECTS` table |
| `[passive]` | `name`, `effect`, `description` | Reserved — parser accepts it, runtime ignores until passive system is wired |

---

## Encounter Config

```
# data/encounters/tutorial.cfg
[player]
- warrior
- healer

[enemy]
- goblin
- shaman
```

### Rules

- List items are character config filenames (without `.cfg` extension).
- Characters are loaded from `data/characters/{name}.cfg`.
- Party order matches list order.
- Party size is validated against `MAX_PARTY_SIZE`.

---

## Effect Lookup Tables

Three separate tables, one per ability category. Each maps a string key to a proc pointer.

```odin
ABILITY_EFFECTS  : map[string]Ability_Effect
ABILITY_DESCRIPTIONS: map[string]Ability_Describe

RESOLVE_EFFECTS  : map[string]Ability_Effect
RESOLVE_DESCRIPTIONS: map[string]Ability_Describe

PASSIVE_EFFECTS  : map[string]Passive_Effect  // reserved
```

### Describe Resolution

Describe procs are convention-matched to effect procs. The effect key `"flurry"` auto-resolves to the describe proc registered under the same key `"flurry"` in the corresponding describes table. No separate `describe` field in config files.

### Registration

All tables are populated at startup. Adding a new effect requires:
1. Write the effect proc in `ability.odin`
2. Write the matching describe proc in `ability.odin`
3. Add one entry to the appropriate effects table
4. Add one entry to the matching describes table

Characters that reuse existing effects are pure data — edit or add a `.cfg` file, no code changes.

---

## Loading Pipeline

All loading logic lives in `src/config.odin`.

### Procedures

| Procedure | Signature | Purpose |
|-----------|-----------|---------|
| `config_load_encounter` | `(name: string) -> (Party, Party, bool)` | Load encounter by name, returns player and enemy parties |
| `config_load_character` | `(name: string) -> (Character, bool)` | Load single character from `data/characters/{name}.cfg` |
| `config_parse_file` | `(path: string) -> (Config_File, bool)` | Parse a `.cfg` file into sections and key-value pairs |

### Flow

1. `game_init` receives an encounter name (default: `"tutorial"`)
2. `config_load_encounter` reads `data/encounters/{name}.cfg`
3. For each character name in the encounter, `config_load_character` reads and parses the character file
4. Effect/describe strings are resolved via lookup tables
5. Fully constructed `Character` structs are returned
6. On failure at any step: log error, return `false`

### Hot Reload

On Play Again, `game_init` re-reads all data files. Character data is fixed during a game. This means balance changes take effect on restart without recompiling.

---

## Validation

Fail hard with logged errors. The game does not start (or restart) with invalid data.

### Checks

- File not found → error with path
- Unknown section → error with section name and file
- Unknown key → error with key, section, and file
- Missing required field → error listing the field and section
- Duplicate key in same section → error
- Unknown effect name → error listing valid effects: `"unknown effect 'flury' in [ability] — valid: flurry, smite, fireball, heal"`
- Unknown rarity → error listing valid values
- Unknown scaling → error listing valid values
- Party size exceeds `MAX_PARTY_SIZE` → error

### Error Format

```
config error: data/characters/warrior.cfg: [ability] unknown effect 'flury' — valid: flurry, smite, fireball, heal
```

All errors go through `log.errorf` and the procedure returns `false`.

---

## Integration with Game

### Before (current)

```odin
// game.odin — game_init
gs.player_party.characters[0] = warrior_create()
gs.player_party.characters[1] = healer_create()
gs.player_party.count = 2
gs.enemy_party.characters[0] = goblin_create()
gs.enemy_party.characters[1] = shaman_create()
gs.enemy_party.count = 2
```

### After

```odin
// game.odin — game_init
player_party, enemy_party, ok := config_load_encounter(encounter_name)
if !ok {
    // error already logged
    return
}
gs.player_party = player_party
gs.enemy_party = enemy_party
```

The `*_create` template procs in `ability.odin` are removed. The lookup tables and effect/describe procs remain.

---

## Integration with Simulator

The simulator uses the same `config_load_encounter` procedure. No separate loading path.

```
odin run sim/ -- --encounter=tutorial --rounds=1000
```

The simulator imports `config_load_encounter` from the game package (or a shared config package if the simulator is a separate binary). See `docs/design/simulator.md` for simulator architecture.

---

## Future Extensions

- **`data/abilities/`** — when ability definitions themselves need data-driven parameters (damage values, scaling formulas), ability configs move to their own files. Effect procs remain in Odin but read parameters from data.
- **`[board]` section in encounters** — per-encounter board configuration (size, skull chance) when needed.
- **`[passive]` activation** — when the passive ability system is wired, the parser already accepts the section. Just connect it to `PASSIVE_EFFECTS` and add the runtime logic.

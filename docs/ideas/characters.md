# Character Ideas

## Stat Design

### Attack Scaling
- Should Attack be a fixed stat per character, or scale with level/gear?
- Currently flat — no progression system exists yet.

### Defense Model
- Currently implemented as flat reduction: `max(Attack - Defense, 0)` per hit.
- Alternative: percentage-based reduction. Percentage would make Defense more valuable against high-attack enemies but weaker against multi-hit skull builds.
- Flat reduction interacts interestingly with per-hit skull damage — a Defense of 2 absorbs 2 damage per skull die, not per roll.

### Speed / Initiative
- Currently turn order is strict alternation. No Speed stat.
- A speed stat could determine who picks first after a board refill, or allow fast characters to take two actions before a slow enemy responds.
- Risk: adds complexity without clear payoff at current scope.

### Stats by Rarity
- Currently rarity only affects dice slot count.
- Giving higher-rarity characters better base stats (HP, Attack, Defense) would create a clearer power curve and make skull dice more valuable on Legendary characters.
- Risk: conflates two independent axes (slot count vs raw power). May make rarity feel mandatory rather than a build choice.

### Stat Modifiers from Abilities
- Abilities that temporarily raise or lower stats (e.g., an Attack buff lasting 2 turns).
- Would make skull dice dynamically stronger/weaker depending on active buffs — adds timing strategy around when to roll skull-heavy characters.

## Data-Driven Characters — Done

Implemented in Milestone 9 using `.cfg` files (not YAML). Character definitions in `data/characters/*.cfg`, encounter compositions in `data/encounters/*.cfg`. Effect procs stay in Odin; lookup tables map config strings to procs. Hot reload on Play Again. See `docs/codebase/config.md`.

## Class Design Extensions

The four planned classes (Rogue, Paladin, Wizard, Bard) cover the core axes. Extensions worth considering:

- **Necromancer:** Scales with party death — assigned dice from dead allies fuel abilities.
- **Artificer:** Uses Split/Empower aggressively. Builds temporary die-type advantages mid-draft.
- **Berserker:** Scales with unmatched dice (charges resolve quickly; abilities reward failed rolls).

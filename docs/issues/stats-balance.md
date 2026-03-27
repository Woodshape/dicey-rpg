# Stats & Balance Issues

## Stat Design

### Attack Scaling
- Should Attack be a fixed stat per character, or scale with level/gear?
- Currently flat — no progression system exists yet.

### Defense Model
- Is Defense flat reduction (`max(Attack - Defense, 0)` per hit) or percentage-based?
- Flat reduction is currently implemented. Percentage-based would make Defense more valuable against high-attack enemies but weaker against multi-hit skull builds.

### Speed / Initiative
- Do we need a Speed stat?
- Currently turn order is strict alternation. A speed stat could determine who picks first after a board refill, or allow fast characters to take two actions before a slow enemy responds.
- Risk: adds complexity without clear payoff at current scope.

### Stats by Rarity
- Should higher-rarity characters have better base stats (HP, Attack, Defense)?
- Currently rarity only affects dice slot count. Giving Legendary characters higher Attack would make skull dice more valuable on them and create a clearer power curve.

### Stat Modifiers from Abilities
- Should abilities be able to temporarily raise or lower stats (e.g. an Attack buff that lasts 2 turns)?
- This would make skull dice dynamically more/less dangerous depending on buffs active, adding a strategic layer to timing.

## Balance Pass (Milestone 8)

These need playtesting data before settling values:

- **HP:** Starting HP per character. Without a maximum, balance is determined entirely by starting HP and damage/healing flow rates. Current values are placeholders.
- **Attack/Defense:** Current values may make skull dice too strong or too weak relative to ability damage.
- **Ability damage:** Fireball ([MATCHES] x [VALUE]) can spike very high with Epic/Legendary characters. Needs a ceiling check.
- **Resolve meter charge rate:** How many unmatched dice does it take to fill the meter? Too fast = resolve ability trivialised. Too slow = feels irrelevant.
- **Board size:** Directly affects how long the draft phase lasts and how much denial is possible. Tune after other balance is stable.

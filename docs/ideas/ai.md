# AI Ideas

## Per-Enemy Drafting Personalities

- Currently all enemies share the same scoring logic. Per-enemy strategy profiles would make enemies feel distinct.
- Possible profiles:
  - **Skull Rush:** Aggressively prioritise skull dice over ability dice. Aims for multi-hit pressure.
  - **Match Builder:** Commits to small dice (d4/d6). Prioritises reliable [MATCHES] and consistent ability triggers.
  - **Value Seeker:** Commits to large dice (d10/d12). Accepts misses in exchange for high [VALUE] spikes.
  - **Denier:** Actively picks dice the player is building toward, even at cost to its own build.
- Scoring weights per profile would be data-driven — different multipliers for skull preference, die size, denial value.

## Proactive Discard

- The AI currently discards only on true deadlock (hand full, no alive character can use any die).
- A smarter AI would discard proactively when a die type is incompatible with all its characters' committed types, freeing hand slots before the situation becomes critical.
- Risk of premature discard: the AI discards a die that would have been useful after a character dies and slots open up.

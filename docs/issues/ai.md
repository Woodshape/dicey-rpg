# AI Issues

## Type Commitment

- The AI currently picks whatever scores highest this turn without planning ahead.
- This means it may give a character d4s one turn and d6s the next — only one type sticks due to the pure type rule, wasting picks.
- The AI should commit to a die type per character early and stick with it throughout the game.
- Approach: when a character already has dice assigned, strongly prefer picks that match that type. When no dice are assigned, pick the type that best fits the character's ability scaling axis.

## Ability Awareness

- The AI currently doesn't consider which die types are optimal for which abilities.
- A [VALUE]-scaling character (e.g. Smite) should prefer d10/d12 for high [VALUE].
- A [MATCHES]-scaling character (e.g. Flurry) should prefer d4/d6 for reliable [MATCHES].
- Scoring could factor in the character's ability scaling axis when evaluating candidate die types.
- Hybrid abilities (e.g. Fireball: [MATCHES] x [VALUE]) need their own heuristic — moderate die sizes (d6/d8) may outperform extremes.

## Drafting Sophistication

- Should different enemy types have visible, distinct drafting personalities?
- A skull-rush enemy should aggressively prioritise skull dice over ability dice.
- A match-builder enemy should commit to small dice and reliable patterns.
- A denial-focused enemy should actively pick dice the player needs, even at cost to itself.
- Currently all enemies share the same scoring logic. Per-enemy strategy profiles are a post-MVP improvement.

## Discard Threshold

- The AI discards only on true deadlock (hand full, no alive character can use any die in it).
- This is conservative and correct for now, but a smarter AI might discard proactively when a die type is incompatible with all its characters' committed types.

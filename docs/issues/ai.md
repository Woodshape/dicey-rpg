# AI Issues

## Type Commitment

The AI picks whatever scores highest this turn without tracking what type it has already committed to. Because only one die type sticks on a character (pure type rule), picks of a conflicting type are silently wasted — the new dice get rejected and the AI has lost an action for nothing.

**Consequence:** The AI regularly wastes pick actions, making it easier to beat than it should be.

**Fix:** When a character already has dice assigned, strongly weight picks of the same type. When no dice are assigned, pick the type that best fits the character's ability scaling axis and treat that as a commitment for future picks on that character.

## Ability Awareness

The AI scores die types by generic value (size, skull priority) without considering what scaling axis its characters' abilities use. A Smite character ([VALUE]-scaling) benefits most from d10/d12, but the AI might feed it d4s if they score slightly higher on a given turn. A Flurry character ([MATCHES]-scaling) needs d4/d6 for reliable matches, but the AI may reach for d10s.

**Consequence:** The AI builds suboptimally against its own characters' strengths, reducing its threat level.

**Fix:** Factor each character's ability scaling axis into die type scoring. [VALUE]-scaling characters should apply a multiplier favouring larger dice; [MATCHES]-scaling characters should favour smaller dice. Hybrid abilities (e.g., Fireball) should favour moderate sizes (d6/d8) that balance both axes.

## Hardcoded Enemy Party

`ai_take_turn` and all its helper procs (`ai_assign_from_hand`, `ai_should_roll`, `ai_pick_best_die`, etc.) are hardcoded to operate on `gs.enemy_party` and `gs.enemy_hand`. The function cannot drive the player side.

**Consequence:** The combat simulator must use a party-swap workaround (`swap_sides` in `sim/main.odin`) to make the AI play both sides. This works but is fragile — any ability that hardcodes `gs.player_party` or `gs.enemy_party` instead of using `attacker_party()` will break silently.

**Fix:** Parameterize `ai_take_turn` to accept which side to act on, or pass explicit party/hand/opponent pointers. This also unblocks future strategy profiles (different AI per side).

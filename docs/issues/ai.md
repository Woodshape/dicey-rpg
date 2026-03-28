# AI Issues

## Type Commitment (Partially Fixed)

The AI now uses `ai_scaling_fit()` to prefer die types matching the character's ability scaling axis when no dice are assigned yet. However, it still does not track committed type across turns — once a character has dice assigned, the AI does not strongly weight picks of the same type. Picks of a conflicting type are silently wasted due to the pure type rule.

**Consequence:** The AI wastes fewer pick actions than before (scaling-aware initial picks help), but cross-turn type conflicts still occur.

**Fix:** When a character already has dice assigned, strongly weight picks of the same type. The existing `ai_scaling_fit()` handles the cold-start case; the remaining gap is carrying that commitment forward on subsequent turns.

## Ability Awareness (Fixed)

~~The AI scores die types by generic value (size, skull priority) without considering what scaling axis its characters' abilities use.~~

Fixed: `ai_score_die_for_party` and `ai_assign_from_hand` now use `ai_scaling_fit()` to score dice by each character's ability scaling axis. Match-scaling characters prefer d4/d6 (reliable matches), value-scaling characters prefer d10/d12 (high face values), and hybrid abilities prefer d6/d8 (balanced).

## Hardcoded Enemy Party

`ai_take_turn` and all its helper procs (`ai_assign_from_hand`, `ai_should_roll`, `ai_pick_best_die`, etc.) are hardcoded to operate on `gs.enemy_party` and `gs.enemy_hand`. The function cannot drive the player side.

**Consequence:** The combat simulator must use a party-swap workaround (`swap_sides` in `sim/main.odin`) to make the AI play both sides. This works but is fragile — any ability that hardcodes `gs.player_party` or `gs.enemy_party` instead of using `attacker_party()` will break silently.

**Fix:** Parameterize `ai_take_turn` to accept which side to act on, or pass explicit party/hand/opponent pointers. This also unblocks future strategy profiles (different AI per side).

## Last-Resort Roll Deadlock

When a character is full with fewer than 2 normal (non-skull) dice and no useful picks are available on the board, the AI now rolls as a last resort. This prevents a deadlock where the AI would otherwise loop indefinitely with no valid action.

**Consequence:** The fix is correct — the AI no longer gets stuck. However, skull-heavy characters rolling with minimal ability dice means they roll without meaningful ability potential. The underlying problem is that skulls crowd out ability dice in character slots.

**Design concern:** This is less a bug and more a symptom of skulls competing for the same character slots as ability dice. If skulls occupied a separate resource (see ideas/combat.md "Skull Design Concerns"), this deadlock scenario would not arise.

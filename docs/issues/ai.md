# AI Issues

## Type Commitment (Partially Fixed)

The AI now uses `ai_scaling_fit()` to prefer die types matching the character's ability scaling axis when no dice are assigned yet. However, it still does not track committed type across turns — once a character has dice assigned, the AI does not strongly weight picks of the same type. Picks of a conflicting type are silently wasted due to the pure type rule.

**Consequence:** The AI wastes fewer pick actions than before (scaling-aware initial picks help), but cross-turn type conflicts still occur.

**Fix:** When a character already has dice assigned, strongly weight picks of the same type. The existing `ai_scaling_fit()` handles the cold-start case; the remaining gap is carrying that commitment forward on subsequent turns.

## Hardcoded Enemy Party

`ai_draft_pick`, `ai_combat_turn`, and all helper procs (`ai_assign_from_hand`, `ai_should_roll`, `ai_pick_best_pool_die`, etc.) are hardcoded to operate on `gs.enemy_party` and `gs.enemy_hand`. The functions cannot drive the player side.

**Consequence:** The combat simulator must use a party-swap workaround (`swap_sides` in `sim/main.odin`) to make the AI play both sides. This works but is fragile — any ability that hardcodes `gs.player_party` or `gs.enemy_party` instead of using `attacker_party()` will break silently.

**Fix:** Parameterize AI procs to accept which side to act on, or pass explicit party/hand/opponent pointers. This also unblocks future strategy profiles (different AI per side).

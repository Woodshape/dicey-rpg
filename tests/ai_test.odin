package tests

import "core:testing"
import game "../src"

// --- AI die scoring ---

@(test)
ai_prefers_matching_type :: proc(t: ^testing.T) {
	// Enemy already has D6 assigned — D6 should score higher than D8
	score_d6 := game.ai_score_die(.D6, .D6, true, .None, false)
	score_d8 := game.ai_score_die(.D8, .D6, true, .None, false)
	testing.expect(t, score_d6 > score_d8, "AI should prefer die matching its committed type")
}

@(test)
ai_scores_skull_dice_highly :: proc(t: ^testing.T) {
	// Skull dice should score well even when enemy has no committed type
	score_skull := game.ai_score_die(.Skull, .None, false, .None, false)
	score_d8 := game.ai_score_die(.D8, .None, false, .None, false)
	testing.expect(t, score_skull > score_d8, "AI should score skull dice higher than unneeded normal dice")
}

@(test)
ai_considers_denial :: proc(t: ^testing.T) {
	// Player has D4 assigned — picking a D4 should score higher due to denial
	score_with_denial := game.ai_score_die(.D4, .None, false, .D4, true)
	score_no_denial := game.ai_score_die(.D4, .None, false, .None, false)
	testing.expect(t, score_with_denial > score_no_denial, "AI should add denial bonus when player needs that type")
}

// --- AI scaling fit ---

@(test)
ai_scaling_fit_match_prefers_small :: proc(t: ^testing.T) {
	testing.expect(t, game.ai_scaling_fit(.Match, .D4) > game.ai_scaling_fit(.Match, .D12),
		"Match-scaling should prefer d4 over d12")
}

@(test)
ai_scaling_fit_value_prefers_big :: proc(t: ^testing.T) {
	testing.expect(t, game.ai_scaling_fit(.Value, .D12) > game.ai_scaling_fit(.Value, .D4),
		"Value-scaling should prefer d12 over d4")
}

@(test)
ai_scaling_fit_hybrid_prefers_mid :: proc(t: ^testing.T) {
	fit_d6 := game.ai_scaling_fit(.Hybrid, .D6)
	fit_d4 := game.ai_scaling_fit(.Hybrid, .D4)
	fit_d12 := game.ai_scaling_fit(.Hybrid, .D12)
	testing.expect(t, fit_d6 > fit_d4, "Hybrid-scaling should prefer d6 over d4")
	testing.expect(t, fit_d6 > fit_d12, "Hybrid-scaling should prefer d6 over d12")
}

// --- AI assignment ---

@(test)
ai_assigns_compatible_from_hand :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	game.hand_add(&gs.enemy_hand, .D6)

	game.ai_assign_from_hand(&gs)

	testing.expect_value(t, gs.enemy_party.characters[0].assigned_count, 1)
	testing.expect_value(t, gs.enemy_party.characters[0].assigned[0], game.Die_Type.D6)
	testing.expect_value(t, gs.enemy_hand.count, 0)
}

@(test)
ai_does_not_assign_incompatible :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	// Commit all enemy characters to D6
	for i in 0 ..< gs.enemy_party.count {
		game.character_assign_die(&gs.enemy_party.characters[i], .D6)
	}
	// Put a D8 in hand (incompatible with all enemies)
	game.hand_add(&gs.enemy_hand, .D8)

	game.ai_assign_from_hand(&gs)

	// D8 should stay in hand — no enemy can accept it
	testing.expect_value(t, gs.enemy_hand.count, 1)
}

// --- AI roll decision ---

@(test)
ai_rolls_when_character_full :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	// Fill all 3 slots (Common = 3 max) with normal dice
	for _ in 0 ..< 3 {
		game.character_assign_die(&gs.enemy_party.characters[0], .D6)
	}

	should, _ := game.ai_should_roll(&gs)
	testing.expect(t, should, "AI should roll when character is fully loaded with normal dice")
}

@(test)
ai_does_not_roll_full_with_only_skulls :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	// Fill all 3 slots with skulls — no ability can fire
	for _ in 0 ..< game.RARITY_MAX_DICE[game.Character_Rarity.Common] {
		game.character_assign_die(&gs.enemy_party.characters[0], .Skull)
	}

	should, _ := game.ai_should_roll(&gs)
	testing.expect(t, !should, "AI should not roll when full but all dice are skulls")
}

@(test)
ai_does_not_roll_empty_character :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	should, _ := game.ai_should_roll(&gs)
	testing.expect(t, !should, "AI should not roll with no assigned dice")
}

@(test)
ai_does_not_roll_with_only_skulls :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	// Assign 2 skull dice — no normal dice
	game.character_assign_die(&gs.enemy_party.characters[0], .Skull)
	game.character_assign_die(&gs.enemy_party.characters[0], .Skull)

	should, _ := game.ai_should_roll(&gs)
	testing.expect(t, !should, "AI should not roll with only skull dice (no ability can fire)")
}

@(test)
ai_rolls_with_normal_dice :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	// Assign 2 normal + 1 skull, character is full (Common = 3)
	game.character_assign_die(&gs.enemy_party.characters[0], .D6)
	game.character_assign_die(&gs.enemy_party.characters[0], .D6)
	game.character_assign_die(&gs.enemy_party.characters[0], .Skull)

	should, _ := game.ai_should_roll(&gs)
	testing.expect(t, should, "AI should roll when character is full with normal dice")
}

// --- AI pick ---

@(test)
ai_picks_from_board :: proc(t: ^testing.T) {
	gs, _ := game.game_init()

	row, col, found := game.ai_pick_best_die(&gs)
	testing.expect(t, found, "AI should find a pickable die on a fresh board")
	testing.expect(t, row >= 0 && row < game.BOARD_SIZE, "row should be in bounds")
	testing.expect(t, col >= 0 && col < game.BOARD_SIZE, "col should be in bounds")
}

@(test)
ai_cannot_pick_with_full_hand :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	for _ in 0 ..< game.MAX_HAND_SIZE {
		game.hand_add(&gs.enemy_hand, .D4)
	}

	_, _, found := game.ai_pick_best_die(&gs)
	testing.expect(t, !found, "AI should not pick when hand is full")
}
